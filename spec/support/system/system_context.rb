# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'bundler'
require 'ceedling/encodinator'
require 'ceedling/file_wrapper'
require 'ceedling/verbosinator'
require 'ceedling/yaml_wrapper'
require_relative 'gem_dir_layout'

class SystemContext
  class VerificationFailed < RuntimeError; end

  attr_reader :dir, :gem, :console_summary, :raw_output, :last_exit_status, :last_cmd

  SYSTEM_TEST_KEEP_ENV = 'CEEDLING_SYSTEM_TEST_KEEP'

  # Dynamic analysis of Ceedling's own generated C -- runners, mocks, Partials.
  #
  # Names a sanitizer flavor, which is a file in SANITIZERS_DIR, so adding a
  # flavor needs no change here. Follows CEEDLING_TEST_COVERAGE's convention of a
  # named value rather than a boolean, so a second kind of instrumentation (leak
  # detection) is another value rather than another variable.
  SANITIZERS_ENV = 'CEEDLING_TEST_SANITIZERS'

  # Slot 9, not 1: spec/system/mixin_ordering_spec.rb sets CEEDLING_MIXIN_1
  # itself and asserts the resulting merge, so sharing that slot would collide
  # with a spec. Higher also means merging last among env mixins.
  SANITIZERS_MIXIN_ENV = 'CEEDLING_MIXIN_9'

  REPO_ROOT = File.expand_path( File.join( File.dirname(__FILE__), '..', '..', '..' ) )

  SANITIZERS_DIR = File.join( REPO_ROOT, 'spec', 'support', 'system', 'sanitizers' )

  # Set per example by the "cannot be sanitized" shared context (see
  # spec_system_helper.rb). Class-level rather than instance state because specs
  # build their own SystemContext in before(:all) while this toggles in
  # before/after(:each) -- a class-level flag makes the two order-independent.
  @@sanitizers_disabled = false

  # Flavor file path => its :sanitizer_runtime hash. See #sanitizer_runtime.
  @@sanitizer_runtime = {}

  def self.sanitizers_disabled=(disabled)
    @@sanitizers_disabled = disabled
  end

  def self.sanitizers_disabled?
    @@sanitizers_disabled
  end

  # Root for retained system test artifacts, relative to the working directory.
  # Named once here because the log writer in spec_system_helper.rb, the gemspec,
  # .rubocop.yml, .gitignore, and CI all reach this path by name.
  ARTIFACTS_DIR = 'specout'

  # Shared gem installation — built once by setup_shared_gem!, reused by every deploy_gem call.
  # Eliminates redundant `bundle install` runs (one per describe group → one per suite).
  @@shared_gem_dir = nil
  @@shared_gem     = nil
  @@git_repo       = nil

  def self.setup_shared_gem!
    return if @@shared_gem_dir

    shared_dir = Dir.mktmpdir('ceedling_test_gem_')
    shared_gem = GemDirLayout.new(shared_dir)

    git_repo = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
    gemfile_lines = [
      %Q{source "http://rubygems.org/"},
      %Q{gem "rake"},
      %Q{gem "constructor"},
      %Q{gem "diy"},
      %Q{gem "thor"},
      %Q{gem "deep_merge"},
      %Q{gem "unicode-display_width"},
      %Q{gem "ceedling", :path => '#{git_repo}'}
    ]
    # This machine-generated Gemfile is never committed -- adding simplecov here only
    # when coverage mode is on keeps every other run's deployed environment identical
    # to what a real installed gem's own dependencies actually are. Pinned to the same
    # constraint as the main Gemfile's Ruby->=3.2 branch so both processes run the
    # identical SimpleCov version -- an unpinned resolve here could otherwise drift to
    # whatever's newest on rubygems.org independent of the main Gemfile.lock. No
    # RUBY_VERSION branch needed here (unlike the main Gemfile): this line only ever
    # runs at all when CEEDLING_TEST_COVERAGE == 'system', itself only ever set on the
    # Ruby 3.3 CI leg.
    gemfile_lines << %Q{gem "simplecov", "~> 1.1"} if ENV['CEEDLING_TEST_COVERAGE'] == 'system'
    File.write( File.join(shared_dir, 'Gemfile'), gemfile_lines.join("\n") )

    Dir.chdir(shared_dir) do
      begin
        # Bundler.with_unbundled_env restores the pre-`bundle exec` environment for
        # this block -- clearing not just BUNDLE_GEMFILE/BUNDLE_BIN_PATH/RUBYOPT but
        # also GEM_HOME/GEM_PATH/RUBYLIB and every other var Bundler sets when this
        # spec suite itself runs under `bundle exec` against a non-default GEM_HOME
        # (e.g. `bundle install --path vendor/bundle`). Without it, this nested
        # install inherits the outer Bundler's env and fails to find its own
        # dependencies under a completely different Gemfile.
        deploy_output = Bundler.with_unbundled_env do
          output  = `bundle config set --local path '#{shared_gem.install_dir}' 2>&1`
          # --prefer-local: Without it, Bundler resolves gems (e.g. `benchmark`) fresh from
          # rubygems repository even when Ruby's default-gem copy satisfies the Gemfile constraint.
          output += `bundle install --prefer-local 2>&1`
          output
        end
        raise VerificationFailed, "bundle install failed:\n#{deploy_output}" unless $?.success?

        verify = Bundler.with_unbundled_env { `bundle exec ruby -S ceedling version 2>&1` }
        unless $?.success?
          raise VerificationFailed,
            "Ceedling does not appear to be installed or ready for use.\n" \
            "Output:\n#{verify}"
        end
      rescue
        FileUtils.rm_rf(shared_dir)
        raise
      end
    end

    @@shared_gem_dir = shared_dir
    @@shared_gem     = shared_gem
    @@git_repo       = git_repo
  end

  def self.cleanup_shared_gem!
    FileUtils.rm_rf(@@shared_gem_dir) if @@shared_gem_dir
    @@shared_gem_dir = nil
    @@shared_gem     = nil
    @@git_repo       = nil
  end

  def initialize
    if ENV[SYSTEM_TEST_KEEP_ENV]
      # In either debug mode ('failures' or 'all'), root the temp dir inside the
      # artifacts directory's proj/ so that done! can rename it to pass/ or fail/ on
      # the same filesystem without a cross-device copy. The specific subdir (pass/
      # or fail/) is determined by done!.
      base = File.join(Dir.pwd, ARTIFACTS_DIR, 'proj')
      FileUtils.mkdir_p(base)
      @dir = Dir.mktmpdir(nil, base)
    else
      @dir = Dir.mktmpdir
    end
    @gem = GemDirLayout.new(@dir)
  end

  def done!
    if keep_all? || (keep_failures_only? && @failed)
      # 'all' mode: preserve pass and fail artifacts for post-run inspection.
      # 'failures' mode: preserve only failing artifacts; passing dirs are discarded
      # immediately to avoid accumulating thousands of files during a full CI run
      # (each --local project copies the entire Ceedling source tree).
      subdir = @failed ? 'fail' : 'pass'
      dest   = File.join(File.dirname(@dir), subdir, File.basename(@dir))
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.mv(@dir, dest)
      $stderr.puts "Test artifacts saved: #{dest}"
    else
      FileUtils.rm_rf(@dir)
    end
  end

  # Called by the RSpec after(:each) hook on failure so done! routes this context to fail/.
  def mark_failed!
    @failed = true
  end

  def deploy_gem
    raise VerificationFailed,
      "Shared gem not initialized — ensure SystemContext.setup_shared_gem! " \
      "is called before running system specs (see spec_system_helper.rb before(:suite))" \
      unless @@shared_gem
    @gem = @@shared_gem
  end

  # Does a few things:
  #   - Configures the environment.
  #   - Runs the command from the temporary context directory.
  #   - Restores everything to where it was when finished.
  def context_exec(cmd, *args)
    with_context do
      `#{args.unshift(cmd).join(" ")}`
    end
  end

  def with_context
    # Resolved out here, before with_constrained_env: Bundler.with_unbundled_env
    # restores ENV from the snapshot it took when Bundler was first loaded, so
    # CEEDLING_TEST_SANITIZERS is not readable inside that block unless it
    # happened to be set before this process started. Resolving first makes this
    # work whoever sets the variable, and whenever.
    sanitizers = sanitizer_environment

    Dir.chdir @dir do |_current_dir|
      with_constrained_env do
        # Point bundle exec to the shared Gemfile so it works from any project directory.
        # with_constrained_env's unbundled environment has no BUNDLE_GEMFILE of its
        # own; set it here so the yielded commands resolve against the shared gem.
        ENV['BUNDLE_GEMFILE'] = File.join(@@shared_gem_dir, 'Gemfile') if @@shared_gem_dir
        ENV['RUBYLIB'] = @gem.lib
        ENV['RUBYPATH'] = @gem.bin

        # RUBYOPT survives Bundler's env-stripping above only because it's set here,
        # inside this block, rather than by whatever called into this method -- forces
        # spec/support/system/simplecov_boot.rb to load before the child process's own
        # requires run, the same way a coverage tool would hook any externally invoked
        # CLI. CEEDLING_TEST_COVERAGE_ROOT tells that boot script where this repo (and
        # its shared .simplecov config) actually live, since the child's own CWD is
        # this ephemeral deployed project directory, not the repo.
        if ENV['CEEDLING_TEST_COVERAGE'] == 'system'
          ENV['RUBYOPT'] = "-r#{File.join(File.dirname(__FILE__), 'simplecov_boot.rb')}"
          ENV['CEEDLING_TEST_COVERAGE_ROOT'] = @@git_repo
        end

        ENV['LANG'] = 'en_US.UTF-8'
        ENV['LANGUAGE'] = 'en_US.UTF-8'
        ENV['LC_ALL'] = 'en_US.UTF-8'

        sanitizers.each { |name, value| ENV[name] = value }

        yield
      end
    end
  end

  ############################################################
  # Functions for manipulating environment settings during tests:

  # Translates CEEDLING_TEST_SANITIZERS into the environment variables Ceedling
  # and the sanitizer runtime actually consume, as a hash for with_context to
  # export. Empty when no flavor is selected or the current spec has opted out,
  # which is what leaves every other matrix leg untouched.
  #
  # Nothing is needed downstream to make a finding fail a build:
  # GeneratorHelper#test_crash? already reads both shapes a sanitizer produces --
  # SIGABRT, and "zero failures reported but a nonzero unsignaled exit" -- as a
  # crashed test executable.
  def sanitizer_environment
    return {} if self.class.sanitizers_disabled?

    flavor = ENV[SANITIZERS_ENV].to_s.strip
    return {} if flavor.empty?

    path = File.join( SANITIZERS_DIR, "#{flavor}.yml" )
    unless File.exist?( path )
      available = Dir[File.join( SANITIZERS_DIR, '*.yml' )].map { |f| File.basename( f, '.yml' ) }.sort
      raise VerificationFailed,
        "#{SANITIZERS_ENV} names no sanitizer flavor: '#{flavor}'. " \
        "Available flavors: #{available.join(', ')}. " \
        "Failing here rather than running uninstrumented -- a silent fallback would report " \
        "success while testing none of what it claims to."
    end

    # The mixin path is absolute because each spec chdir's into its own ephemeral
    # project directory and Ceedling resolves a mixin path against that CWD.
    #
    # Each flavor owns its runtime options -- they are the only difference
    # between asan_ubsan and asan_ubsan_leaks -- and they reach the test
    # executable because it inherits this environment through Ceedling.
    environment = { SANITIZERS_MIXIN_ENV => path }
    sanitizer_runtime( path ).each { |name, value| environment[name.to_s] = value.to_s }
    environment
  end

  # Memoized per flavor file: with_context runs on every build in the suite, and
  # re-reading the same YAML thousands of times buys nothing.
  def sanitizer_runtime(path)
    @@sanitizer_runtime[path] ||= begin
      file_wrapper = FileWrapper.new({
        :loginator    => NullLoginator.new,
        :verbosinator => Verbosinator.new
      })
      hash = YamlWrapper.new({ file_wrapper: file_wrapper }).load( path )
      hash[:sanitizer_runtime] || {}
    end
  end

  # Runs the block against the pre-`bundle exec` environment (see the matching
  # comment on Bundler.with_unbundled_env in setup_shared_gem! above) so a
  # subprocess spawned inside -- e.g. `bundle exec ruby -S ceedling ...` against
  # the shared gem's own Gemfile in with_context below -- resolves against that
  # Gemfile rather than whatever Bundler context this spec suite itself is
  # already running under.
  def with_constrained_env
    Bundler.with_unbundled_env { yield }
  end

  ############################################################
  # Functions for manipulating project.yml files during tests:

  # `self` here is a plain SystemContext instance, not an RSpec example, so
  # RSpec::Mocks' `double` isn't reachable -- a trivial no-op stands in for it.
  class NullLoginator
    def log(*); end
  end

  def merge_project_yml_for_test(settings, show_final=false)
    file_wrapper = FileWrapper.new({
      :loginator    => NullLoginator.new,
      :verbosinator => Verbosinator.new
    })
    yaml_wrapper = YamlWrapper.new({ file_wrapper: file_wrapper })
    project_hash = yaml_wrapper.load('project.yml')
    project_hash.deep_merge!(settings)
    puts "\n\n#{project_hash.to_yaml}\n\n" if show_final
    yaml_wrapper.dump('project.yml', project_hash)
  end

  def append_project_yml_for_test(new_args)
    fake_prj_yml= "#{read_spec_file('project.yml')}\n#{new_args}"
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  def uncomment_project_yml_option_for_test(option)
    fake_prj_yml= read_spec_file('project.yml').gsub(/\##{option}/,option)
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  def comment_project_yml_option_for_test(option)
    fake_prj_yml= read_spec_file('project.yml').gsub(/#{option}/,"##{option}")
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  ############################################################
  # Ceedling command execution with structured failure reporting:

  # For build/test (Rake tasks): Routes through the Ceedling CLI application command `build`
  # This is the only command that accepts --verbosity.
  def ceedling_build_exec(*args)
    cmd = "bundle exec ruby -S ceedling build --verbosity=debug #{args.join(' ')}".strip
    stdout, stderr, status = Open3.capture3(cmd)

    @last_cmd         = cmd
    @last_exit_status = status.exitstatus
    # Captured subprocess output carries whatever raw bytes the child process wrote; under
    # a non-UTF-8 default external encoding those bytes are read back tagged with that
    # encoding regardless of their actual content, so any project source content the
    # subprocess echoes (verbose logging, compiler output, etc.) can make later regex
    # matching against this string raise. Sanitize once here, the same way Ceedling itself
    # sanitizes file content it scans -- reused for both the raw output and the failure
    # report below, since a real compiler's own diagnostic text (e.g. clang's curly-quoted
    # identifiers) is exactly the kind of non-ASCII content this needs to survive too.
    stdout, stderr    = stdout.clean_encoding, stderr.clean_encoding
    @raw_output       = stdout + stderr
    @console_summary  = compose_failure_report(stdout, stderr)

    SystemTestOutput.new(@raw_output)
  end

  # All other Ceedling CLI application commands other than `build`
  # (new, upgrade, version, help, examples, example, etc.)
  def ceedling_appcmd_exec(*args)
    cmd = "bundle exec ruby -S ceedling #{args.join(' ')}".strip
    stdout, stderr, status = Open3.capture3(cmd)

    @last_cmd         = cmd
    @last_exit_status = status.exitstatus
    stdout, stderr    = stdout.clean_encoding, stderr.clean_encoding
    @raw_output       = stdout + stderr
    @console_summary  = compose_failure_report(stdout, stderr)

    SystemTestOutput.new(@raw_output)
  end

  private

  # True when running the full suite in CI batch debug mode: keep only failing artifacts.
  # Set by `specs:system:debug` rake task via CEEDLING_SYSTEM_TEST_KEEP='failures'.
  def keep_failures_only?
    ENV[SYSTEM_TEST_KEEP_ENV] == 'failures'
  end

  # True when running an individual spec in developer debug mode: keep all artifacts.
  # Set by `spec:system:debug:<name>` rake tasks via CEEDLING_SYSTEM_TEST_KEEP='all'.
  # Also used by the CI locale test job (spec:system:debug:preprocessing_locale).
  def keep_all?
    ENV[SYSTEM_TEST_KEEP_ENV] == 'all'
  end

  def compose_failure_report(stdout, stderr)
    sections = []

    error_lines     = stdout.lines.select { |l| l.include?('ERROR') }
    exception_lines = stdout.lines.select { |l| l.include?('EXCEPTION') }

    unless error_lines.empty? && exception_lines.empty?
      sections << ">> ERRORS & EXCEPTIONS"
      sections.concat(error_lines)
      sections.concat(exception_lines)
    end

    unless stderr.strip.empty?
      sections << ">> STDERR"
      sections << stderr.strip
    end

    # Loginator routes `Verbosity::DEBUG` messages (including the backtrace
    # `log_debug_backtrace` emits for a caught exception) to stdout rather than
    # stderr, and this method's stdout scan above only pulls lines containing
    # the literal substrings 'ERROR'/'EXCEPTION' -- a bare backtrace line
    # (file:line:in `method') contains neither, so without surfacing it here
    # explicitly, the one piece of stdout most useful for diagnosing *why* a
    # command failed would otherwise only ever reach the full raw-output log
    # file, not this console-visible summary (what CI output actually shows).
    label = 'Debug Backtrace ==>'
    backtrace_block = extract_section(stdout, label)
    unless backtrace_block.empty?
      sections << ">> DEBUG BACKTRACE"
      sections.concat(backtrace_block)
    end

    label = 'FAILED TEST SUMMARY'
    failed_block = extract_section(stdout, label)
    unless failed_block.empty?
      sections << ">> #{label}"
      sections.concat(failed_block)
    end

    label = 'OVERALL TEST SUMMARY'
    overall_block = extract_section(stdout, label)
    unless overall_block.empty?
      sections << ">> #{label}"
      sections.concat(overall_block)
    end

    sections.join("\n")
  end

  def extract_section(output, banner)
    lines = output.lines
    idx   = lines.index { |l| l.include?(banner) }
    return [] unless idx

    # Skip the banner line and any following pure-separator lines
    start = idx + 1
    start += 1 while start < lines.length && lines[start].strip.match?(/\A[-=]+\z/)

    # Collect contiguous non-blank lines
    lines[start..].take_while { |l| !l.strip.empty? }
  end
  ############################################################
end
