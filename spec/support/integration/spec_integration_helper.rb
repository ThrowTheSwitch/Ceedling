# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Shared rigging for the integration spec tier.
#
# Integration specs compose the real `lib/ceedling/preprocess/` object graph and run
# the real GCC preprocessor, but exercise one subsystem -- includes extraction --
# rather than a whole `ceedling` build. `gcc` is the only external dependency.
#
# The graph is real except for two thin stand-ins that keep the heavyweight framework
# objects out: a Configurator stub that just returns the `DEFAULT_*_PREPROCESSOR_TOOL`
# definitions and the mock prefix, and a ToolExecutor stub whose `exec` actually shells
# the command it was handed through Open3. GCC genuinely runs; nothing else is faked.

require 'open3'
require 'tmpdir'
require 'fileutils'

require 'ceedling/constants'
require 'ceedling/defaults'
require 'ceedling/file_wrapper'
require 'ceedling/yaml_wrapper'
require 'ceedling/parsing_parcels'
require 'ceedling/includes/includes'
require 'ceedling/includes/include_factory'
require 'ceedling/preprocess/preprocessinator'
require 'ceedling/preprocess/preprocessinator_includes_handler'
require 'ceedling/preprocess/preprocessinator_bare_includes_extractor'
require 'ceedling/preprocess/preprocessinator_line_marker_includes_extractor'

module IntegrationSpecHelpers
  # Absorbs any message (and any block) and returns itself. Stands in for the graph's
  # logging/assembly collaborators that the includes path either never reaches or only
  # calls for their side effects.
  class NullObject
    # Named params (not anonymous `&`) so this loads on Ruby 3.0, still in the CI matrix.
    def method_missing(*_args, **_kwargs, &_block) = self
    def respond_to_missing?(*) = true
  end
  NULL = NullObject.new

  # --- Toolchain probes -----------------------------------------------------

  # True when a `gcc` invocation of any kind succeeds. Mirrors the system tier's
  # `tool_available?` rather than sharing it, so an integration spec need not load the
  # whole system helper.
  def gcc_available?
    Open3.capture2e('gcc --version')[1].success?
  rescue StandardError
    false
  end

  # True when `gcc` honours `-fdirectives-only` without complaint. Apple Clang (the
  # `gcc` alias on macOS) silently ignores the flag and warns, naming it -- exactly the
  # condition under which Ceedling itself falls back to text scanning
  # (Configurator#resolve_directives_only_preprocessing). Integration specs branch on
  # this the same way.
  def directives_only_supported?
    out, status = Open3.capture2e('gcc -E -fdirectives-only -x c -', stdin_data: "\n")
    status.success? && !out.match?(/warning[^\n]+-fdirectives-only/)
  rescue StandardError
    false
  end

  # --- Fixture trees ------------------------------------------------------

  # Writes `files` (project-relative path => contents) into a fresh temp directory and
  # yields its absolute path. Parent directories are created as needed. The tree is
  # removed when the block returns.
  def with_source_tree(files)
    Dir.mktmpdir('ceedling-includes-integration-') do |dir|
      files.each do |rel, contents|
        path = File.join(dir, rel)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, contents)
      end
      yield dir
    end
  end

  # --- Includes-extraction harness --------------------------------------------

  # Builds the real Preprocessinator graph wired to run GCC for real, and returns a
  # small facade over it. See IncludesExtractionHarness#reconcile.
  def build_includes_harness(work_dir)
    IncludesExtractionHarness.new(work_dir)
  end

  # A Configurator with only what the includes path touches: the three preprocessor
  # tool definitions and the CMock mock naming. Everything else would be a bug to reach.
  class StubConfigurator
    def tools_test_bare_includes_preprocessor = DEFAULT_TEST_BARE_INCLUDES_PREPROCESSOR_TOOL
    def tools_test_file_directives_only_preprocessor = DEFAULT_TEST_FILE_DIRECTIVES_ONLY_PREPROCESSOR_TOOL
    def tools_test_file_full_preprocessor = DEFAULT_TEST_FILE_FULL_PREPROCESSOR_TOOL
    def cmock_mock_prefix = 'mock_'
    def cmock_mock_path = 'mocks'
  end

  # A ToolExecutor that assembles the command from the tool definition exactly as the
  # real one's `${n}` slot substitution does (an Array slot fans its argument out into
  # one repeated flag per element), then runs it for real. Return shape matches what
  # PreprocessinatorIncludesHandler and Preprocessinator read: `:output`, `:exit_code`.
  class ShellingToolExecutor
    def build_command_line(tool, extra_params, *args)
      slots = args.each_with_index.to_h { |v, i| [(i + 1).to_s, v] }
      argv  = [tool[:executable], *Array(extra_params)]
      tool[:arguments].each do |arg|
        slot = arg[/\$\{(\d+)\}/, 1]
        if slot
          Array(slots[slot]).each { |v| argv << arg.gsub("${#{slot}}", v.to_s) }
        else
          argv << arg
        end
      end
      { line: argv.join(' '), options: { boom: true } }
    end

    def exec(command, _args = [])
      stdout, stderr, status = Open3.capture3(command[:line])
      { output: stdout + stderr, exit_code: status.exitstatus }
    end
  end

  # Minimal FilePathUtils: the includes path only asks it for two scratch locations.
  class ScratchFilePathUtils
    def initialize(root) = @root = root
    def form_test_preprocess_files_path(test) = _ensure(File.join(@root, 'preprocess', test.to_s))
    def form_preprocessed_includes_list_filepath(filepath, test)
      File.join(_ensure(File.join(@root, 'includes', test.to_s)), File.basename(filepath) + '.yml')
    end
    def form_preprocessed_file_raw_directives_only_filepath(filepath, test)
      File.join(_ensure(File.join(@root, 'donly', 'raw', test.to_s)), File.basename(filepath))
    end
    def form_preprocessed_file_compacted_directives_only_filepath(filepath, test)
      File.join(_ensure(File.join(@root, 'donly', test.to_s)), File.basename(filepath))
    end
    private
    def _ensure(dir) = (FileUtils.mkdir_p(dir); dir)
  end

  # Facade: `reconcile` lays out the same call sequence a real build's
  # `stage_preprocess_*` does for one file -- optionally generate the directives-only
  # output, then hand it to `Preprocessinator#preprocess_file_includes_common` -- and
  # returns the reconciled, sanitized Include list (Strings via `#to_s` for assertions
  # come from the spec).
  class IncludesExtractionHarness
    def initialize(work_dir)
      @root         = Dir.mktmpdir('ceedling-includes-harness-')
      @cfg          = StubConfigurator.new
      @tool_exec    = ShellingToolExecutor.new
      @fpu          = ScratchFilePathUtils.new(@root)
      @file_wrapper = FileWrapper.new(loginator: _null, verbosinator: _null)
      factory       = IncludeFactory.new(configurator: @cfg)
      line_marker   = PreprocessinatorLineMarkerIncludesExtractor.new(
                        include_factory: factory, file_wrapper: @file_wrapper)

      @handler = PreprocessinatorIncludesHandler.new(
        configurator:                                    @cfg,
        preprocessinator_line_marker_includes_extractor: line_marker,
        include_factory:                                 factory,
        tool_executor:                                   @tool_exec,
        file_wrapper:                                    @file_wrapper,
        file_path_utils:                                 @fpu,
        yaml_wrapper:                                    _null,
        parsing_parcels:                                 ParsingParcels.new,
        loginator:                                       _null,
        reportinator:                                    _null
      )
      @handler.setup

      @preprocessinator = Preprocessinator.new(
        preprocessinator_includes_handler: @handler,
        preprocessinator_comment_stripper: _null,
        preprocessinator_file_assembler:   _null,
        preprocessinator_reconstructor:    _null,
        file_path_utils:                   @fpu,
        tool_executor:                     @tool_exec,
        plugin_manager:                    _null,
        configurator:                      @cfg,
        loginator:                         _null,
        reportinator:                      _null
      )
      @preprocessinator.setup
    end

    # kind: :header (mockable header / partial header) or :source (partial source) --
    #   only affects logging in production; the includes result is identical.
    # fallback: force the text-scan path (skip directives-only generation).
    def reconcile(file:, test: 'itest', defines: [], search_paths:, fallback: false)
      donly = nil
      unless fallback
        donly = @preprocessinator.generate_directives_only_output(
          filepath: file, test: test, flags: [],
          include_paths: search_paths, vendor_paths: [], defines: defines
        )
      end

      @preprocessinator.preprocess_file_includes_common(
        test: test,
        filepath: file,
        directives_only_filepath: donly,
        fallback: (fallback || donly.nil?),
        flags: [],
        include_paths: search_paths,
        vendor_paths: [],
        defines: defines
      )
    end

    def _null = IntegrationSpecHelpers::NULL
  end
end

RSpec.configure do |config|
  config.include IntegrationSpecHelpers
end

# `include_context "requires gcc"` skips a spec (or describe block) when no usable gcc
# is on PATH -- the same shape the system tier uses for gdb/valgrind.
RSpec.shared_context "requires gcc" do
  before(:all) { @gcc_available = gcc_available? }
  before { skip 'gcc is not installed or not in PATH' unless @gcc_available }
end
