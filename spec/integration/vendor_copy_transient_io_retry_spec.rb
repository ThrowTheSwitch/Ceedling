# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for Issue #1292: a vendor destination (build/vendor/unity/src,
# etc.) occasionally turns up as the wrong file/directory type mid-copy, crashing with
# Errno::ENOTDIR/EISDIR. Does FileWrapper#cp_r_with_retry actually let
# ConfiguratorSetup#vendor_frameworks_and_support_files ride out a transient fault of
# that shape, end to end against a real filesystem -- and does a fault that never
# clears still surface as a clear, path-naming CeedlingException rather than a raw Errno?
#
# Modeled directly on spec/integration/preprocessing_transient_io_retry_spec.rb: a real
# ConfiguratorSetup + real FileWrapper subclass that controls exactly one #cp_r call
# (matched by destination path) so the fault is deterministic. Faulting at #cp_r rather
# than #cp_r_with_retry itself matters here -- cp_r_with_retry's own retry loop (already
# proven exhaustively in file_wrapper_spec.rb) is exactly the mechanism this spec needs
# to actually run.

require 'spec_helper'
require 'spec_integration_helper'
require 'ceedling/config/configurator_setup'
require 'ceedling/constants'

describe 'Vendor-copy transient I/O retry (integration)' do
  include IntegrationSpecHelpers

  # A real FileWrapper whose #cp_r raises for `fault_dest` the first `raises_left`
  # times it's called, then behaves normally -- every other destination is untouched.
  # Real FileWrapper#cp_r_with_retry (inherited, not overridden) is what actually retries.
  # Named distinctly from preprocessing_transient_io_retry_spec.rb's own FaultingFileWrapper
  # -- both are top-level classes loaded into the same RSpec process, and Ruby's open
  # classes would otherwise let the second file's definition silently clobber the first's.
  class CpRFaultingFileWrapper < FileWrapper
    def initialize(fault_dest:, raises_left: 1, error: Errno::EISDIR, **kwargs)
      super(**kwargs)
      @fault_dest = fault_dest
      @raises_left = raises_left
      @error = error
    end

    def cp_r(source, destination, options={})
      if destination == @fault_dest && @raises_left > 0
        @raises_left -= 1
        raise @error, "simulated transient type-mismatch on #{destination}"
      end
      super
    end
  end

  # Real ConfiguratorSetup wired to `file_wrapper`; every other collaborator is
  # untouched by #vendor_frameworks_and_support_files, so NULL stands in for them.
  def build_configurator_setup(file_wrapper)
    ConfiguratorSetup.new(
      configurator_builder:   IntegrationSpecHelpers::NULL,
      configurator_validator: IntegrationSpecHelpers::NULL,
      configurator_plugins:   IntegrationSpecHelpers::NULL,
      loginator:               IntegrationSpecHelpers::NULL,
      reportinator:            IntegrationSpecHelpers::NULL,
      file_wrapper:            file_wrapper
    )
  end

  # A minimal but real fixture standing in for the gem's own vendor/unity/src -- one
  # real file, so a real FileUtils.cp_r has real directory-tree content to walk.
  def flattened_config(dir)
    unity_src = File.join(dir, 'gem_vendor', 'unity', 'src')
    FileUtils.mkdir_p(unity_src)
    File.write(File.join(unity_src, 'unity.c'), "// stand-in for the real unity.c\n")

    {
      # UNITY_LIB_PATH ('unity/src') is joined onto this root -- it must be the
      # vendor root, not 'unity' itself, matching CEEDLING_VENDOR's real shape.
      unity_vendor_path:                     File.join(dir, 'gem_vendor'),
      project_build_vendor_unity_path:       File.join(dir, 'build', 'vendor', 'unity', 'src'),
      project_use_mocks:                     false,
      project_use_exceptions:                false,
      project_use_backtrace:                 false,
      project_use_partials:                  false,
    }
  end

  it "recovers from a transient copy failure on its own vendor destination instead of crashing the build" do
    with_source_tree({}) do |dir|
      config = flattened_config(dir)
      dest = config[:project_build_vendor_unity_path]
      # Real usage always runs build_directory_structure (which mkdir_p's every
      # vendor destination) before this copy -- match that precondition here so the
      # only fault in play is the one this spec injects, not a missing parent dir.
      FileUtils.mkdir_p(dest)

      # Exactly one raise, well within cp_r_with_retry's own retry budget -- the
      # source is otherwise 100% fine, the real copy proceeds either way.
      faulting_fw = CpRFaultingFileWrapper.new(
        fault_dest: dest, raises_left: 1,
        loginator: IntegrationSpecHelpers::NULL, verbosinator: IntegrationSpecHelpers::NULL
      )
      setup = build_configurator_setup(faulting_fw)

      expect {
        setup.vendor_frameworks_and_support_files(dir, config)
      }.not_to raise_error

      expect(File.exist?(File.join(dest, 'unity.c'))).to be true
    end
  end

  it "still raises a clear, path-naming CeedlingException when the fault never clears" do
    with_source_tree({}) do |dir|
      config = flattened_config(dir)
      dest = config[:project_build_vendor_unity_path]
      FileUtils.mkdir_p(dest)

      # More raises than cp_r_with_retry's own retry budget (initial attempt + 4
      # retries) -- every attempt fails, so the fault genuinely never clears.
      permanently_faulting_fw = CpRFaultingFileWrapper.new(
        fault_dest: dest, raises_left: 999,
        loginator: IntegrationSpecHelpers::NULL, verbosinator: IntegrationSpecHelpers::NULL
      )
      setup = build_configurator_setup(permanently_faulting_fw)

      expect {
        setup.vendor_frameworks_and_support_files(dir, config)
      }.to raise_error(CeedlingException, /#{Regexp.escape(dest)}/)
    end
  end
end
