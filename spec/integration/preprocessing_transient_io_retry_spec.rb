# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for Fix 3 (Stage 2 of the concurrency/file-presence work):
# does FileWrapper#open_with_retry actually let Preprocessinator ride out a
# transient failure to open the gcc output it just produced, end to end against
# real gcc -- and does a fault that never clears still surface as a clear,
# file-naming CeedlingException rather than a raw Errno?
#
# This is the committed version of the fact-finding phase's Experiment C: a real
# Preprocessinator + real PreprocessinatorCommentStripper/Reconstructor + real gcc,
# with a FileWrapper subclass that controls exactly one underlying #open call (matched
# by exact path) so the fault is deterministic rather than a flaky, timing-dependent
# reproduction. Faulting at #open rather than #open_with_retry itself matters here --
# open_with_retry's own internal retry loop (already proven exhaustively in
# file_wrapper_spec.rb) is exactly the mechanism this spec needs to actually run.

require 'spec_helper'
require 'spec_integration_helper'
require 'ceedling/preprocess/preprocessinator_comment_stripper'
require 'ceedling/preprocess/preprocessinator_reconstructor'
require 'ceedling/preprocess/c_comment_scanner'
require 'ceedling/parsing_parcels'

describe 'Preprocessing transient I/O retry (integration)' do
  include_context 'requires gcc'

  include IntegrationSpecHelpers

  # A real FileWrapper whose #open raises for `fault_path` the first `raises_left`
  # times it's called, then behaves normally -- every other path is untouched. Real
  # FileWrapper#open_with_retry (inherited, not overridden) is what actually retries.
  class FaultingFileWrapper < FileWrapper
    def initialize(fault_path:, raises_left: 1, error: Errno::EACCES, **kwargs)
      super(**kwargs)
      @fault_path = fault_path
      @raises_left = raises_left
      @error = error
    end

    def open(filepath, flags)
      if filepath == @fault_path && @raises_left > 0
        @raises_left -= 1
        raise @error, "simulated transient sharing violation on #{filepath}"
      end
      super
    end
  end

  # Builds a real Preprocessinator wired to `file_wrapper`, real gcc, and a real
  # comment stripper/reconstructor -- everything generate_directives_only_output
  # actually touches, per Preprocessinator#generate_directives_only_output.
  def build_preprocessinator(dir, file_wrapper)
    cfg = IntegrationSpecHelpers::StubConfigurator.new
    tool_exec = IntegrationSpecHelpers::ShellingToolExecutor.new
    fpu = IntegrationSpecHelpers::ScratchFilePathUtils.new(dir)

    comment_stripper = PreprocessinatorCommentStripper.new(
      c_comment_scanner: CCommentScanner.new, file_wrapper: file_wrapper
    )
    reconstructor = PreprocessinatorReconstructor.new(
      parsing_parcels: ParsingParcels.new, file_wrapper: file_wrapper
    )

    preprocessinator = Preprocessinator.new(
      preprocessinator_includes_handler: IntegrationSpecHelpers::NULL,
      preprocessinator_comment_stripper: comment_stripper,
      preprocessinator_file_assembler:   IntegrationSpecHelpers::NULL,
      preprocessinator_reconstructor:    reconstructor,
      file_path_utils: fpu,
      tool_executor:   tool_exec,
      plugin_manager:  IntegrationSpecHelpers::NULL,
      configurator:    cfg,
      loginator:       IntegrationSpecHelpers::NULL,
      reportinator:    IntegrationSpecHelpers::NULL
    )
    preprocessinator.setup
    [preprocessinator, fpu]
  end

  it 'recovers from a transient open failure on its own output instead of crashing the build' do
    with_source_tree('widget.c' => "int w(void) { return 1; }\n") do |dir|
      src = File.join(dir, 'widget.c')
      # Determine the real output path first (same formula the faulted run below
      # will compute), so the fault can be targeted at the exact right file.
      fpu = IntegrationSpecHelpers::ScratchFilePathUtils.new(dir)
      raw_path = fpu.form_preprocessed_file_raw_directives_only_filepath(src, 'it')

      # Exactly one raw failure, well within open_with_retry's own retry budget --
      # the file is otherwise 100% fine, gcc writes it for real either way.
      faulting_fw = FaultingFileWrapper.new(
        fault_path: raw_path, raises_left: 1,
        loginator: IntegrationSpecHelpers::NULL, verbosinator: IntegrationSpecHelpers::NULL
      )
      preprocessinator, = build_preprocessinator(dir, faulting_fw)

      result = nil
      expect {
        result = preprocessinator.generate_directives_only_output(
          filepath: src, test: 'it', flags: [], include_paths: [dir], vendor_paths: [], defines: []
        )
      }.not_to raise_error

      expect(result).to eq(raw_path)
      expect(File.exist?(raw_path)).to be true
    end
  end

  it 'still raises a clear, file-naming CeedlingException when the fault never clears' do
    with_source_tree('widget.c' => "int w(void) { return 1; }\n") do |dir|
      src = File.join(dir, 'widget.c')
      fpu = IntegrationSpecHelpers::ScratchFilePathUtils.new(dir)
      raw_path = fpu.form_preprocessed_file_raw_directives_only_filepath(src, 'it')

      # More raises than open_with_retry's own retry budget (initial attempt + 4
      # retries) -- every attempt fails, so the fault genuinely never clears.
      permanently_faulting_fw = FaultingFileWrapper.new(
        fault_path: raw_path, raises_left: 999,
        loginator: IntegrationSpecHelpers::NULL, verbosinator: IntegrationSpecHelpers::NULL
      )
      preprocessinator, = build_preprocessinator(dir, permanently_faulting_fw)

      expect {
        preprocessinator.generate_directives_only_output(
          filepath: src, test: 'it', flags: [], include_paths: [dir], vendor_paths: [], defines: []
        )
      }.to raise_error(CeedlingException, /#{Regexp.escape(raw_path)}/)
    end
  end
end
