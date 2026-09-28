# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config/configurator_setup'
require 'ceedling/reportinator'

# Only #validate_partials is covered here. The rest of ConfiguratorSetup has no unit spec
# at all today (its closest sibling, #validate_threads, is untested too) -- this file scopes
# itself to the new method rather than backfilling that existing gap.
describe ConfiguratorSetup do
  before(:each) do
    @configurator_builder   = double('ConfiguratorBuilder')
    @configurator_validator = double('ConfiguratorValidator')
    @configurator_plugins   = double('ConfiguratorPlugins')
    @loginator              = double('Loginator')
    @reportinator           = Reportinator.new
    @file_wrapper           = double('FileWrapper')
    @system_wrapper         = double('SystemWrapper')
    @tool_executor          = double('ToolExecutor')

    @setup = described_class.new(
      {
        configurator_builder:   @configurator_builder,
        configurator_validator: @configurator_validator,
        configurator_plugins:   @configurator_plugins,
        loginator:              @loginator,
        reportinator:           @reportinator,
        file_wrapper:           @file_wrapper,
        system_wrapper:         @system_wrapper,
        tool_executor:          @tool_executor
      }
    )
  end

  context "#validate_partials" do
    it "accepts an integer at the minimum" do
      config = { partials: { max_extraction_length: 10 } }
      expect(@setup.validate_partials(config)).to be true
    end

    it "accepts an integer above the minimum" do
      config = { partials: { max_extraction_length: 5000 } }
      expect(@setup.validate_partials(config)).to be true
    end

    it "rejects a non-integer value" do
      config = { partials: { max_extraction_length: '5000' } }
      expect(@loginator).to receive(:log)
        .with(/:partials ↳ :max_extraction_length is not an integer/, Verbosity::ERRORS)
      expect(@setup.validate_partials(config)).to be false
    end

    it "rejects an integer below the minimum" do
      config = { partials: { max_extraction_length: 9 } }
      expect(@loginator).to receive(:log)
        .with(/:partials ↳ :max_extraction_length must be at least 10/, Verbosity::ERRORS)
      expect(@setup.validate_partials(config)).to be false
    end
  end

  # `gdb --version` answers on a machine where gdb cannot actually attach to a process --
  # macOS revokes a Homebrew gdb's debugger entitlement often enough (a Homebrew upgrade,
  # a macOS system update, a Gatekeeper/taskgated cache reset) that trusting `--version`
  # alone leaves `:use_backtrace: :gdb` silently producing unhelpful crash reports build
  # after build. `validate_tools` probes a real attach and falls back to `:simple`
  # automatically when gdb cannot do the job, rather than failing validation outright.
  context "#validate_tools gdb attach capability" do
    def config(use_backtrace: :gdb)
      { tools: {}, project: { use_backtrace: use_backtrace } }
    end

    before do
      allow(@configurator_validator).to receive(:validate_tool).and_return(true)
    end

    it "does not probe when :use_backtrace is not :gdb" do
      allow(@system_wrapper).to receive(:macos?).and_return(true)
      expect(@tool_executor).to_not receive(:exec)

      expect(@setup.validate_tools(config(use_backtrace: :simple))).to be true
    end

    it "does not probe on a non-macOS platform" do
      allow(@system_wrapper).to receive(:macos?).and_return(false)
      expect(@tool_executor).to_not receive(:exec)

      cfg = config
      expect(@setup.validate_tools(cfg)).to be true
      expect(cfg[:project][:use_backtrace]).to eq(:gdb)
    end

    it "leaves :use_backtrace as :gdb when the attach probe succeeds" do
      allow(@system_wrapper).to receive(:macos?).and_return(true)
      allow(@tool_executor).to receive(:exec).and_return(
        status: double('Process::Status', success?: true), output: ''
      )
      expect(@loginator).to_not receive(:log)

      cfg = config
      expect(@setup.validate_tools(cfg)).to be true
      expect(cfg[:project][:use_backtrace]).to eq(:gdb)
    end

    it "downgrades to :simple and logs a codesigning-specific WARNING when the probe shows the Mach task port failure" do
      allow(@system_wrapper).to receive(:macos?).and_return(true)
      allow(@tool_executor).to receive(:exec).and_return(
        status: double('Process::Status', success?: false),
        output: "Unable to find Mach task port for process-id 123: (os/kern) failure (0x5).\n" \
                " (please check gdb is codesigned - see taskgated(8))"
      )
      expect(@loginator).to receive(:log)
        .with(a_string_including('codesigning'), Verbosity::ERRORS, LogLabels::WARNING)

      cfg = config
      expect(@setup.validate_tools(cfg)).to be true
      expect(cfg[:project][:use_backtrace]).to eq(:simple)
    end

    it "downgrades to :simple and logs a generic WARNING when the probe fails for an unrecognized reason" do
      allow(@system_wrapper).to receive(:macos?).and_return(true)
      allow(@tool_executor).to receive(:exec).and_return(
        status: double('Process::Status', success?: false), output: 'gdb: some other failure'
      )
      expect(@loginator).to receive(:log)
        .with(a_string_including('could not attach to a probe process'), Verbosity::ERRORS, LogLabels::WARNING)

      cfg = config
      expect(@setup.validate_tools(cfg)).to be true
      expect(cfg[:project][:use_backtrace]).to eq(:simple)
    end
  end

  # Issue #1292: a vendor destination (build/vendor/unity/src, etc.) occasionally turns
  # up as the wrong file/directory type, crashing the copy that populates it. These
  # examples cover the two fixes: unconditional copying (never skipped just because the
  # destination looks already populated -- an errant edit there must be overwritten, not
  # left standing) and self-healing a wrong-typed destination before that copy runs.
  context "#heal_vendor_path" do
    it "does nothing when neither the destination nor the marker file exist yet" do
      allow(@file_wrapper).to receive(:exist?).and_return(false)

      @setup.heal_vendor_path('/build/vendor/unity/src', 'unity.c')

      expect(@file_wrapper).to_not receive(:rm_rf)
    end

    it "does nothing when the destination is a directory and the marker is a plain file inside it" do
      allow(@file_wrapper).to receive(:exist?).with('/build/vendor/unity/src').and_return(true)
      allow(@file_wrapper).to receive(:directory?).with('/build/vendor/unity/src').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('/build/vendor/unity/src/unity.c').and_return(true)
      allow(@file_wrapper).to receive(:directory?).with('/build/vendor/unity/src/unity.c').and_return(false)

      @setup.heal_vendor_path('/build/vendor/unity/src', 'unity.c')

      expect(@file_wrapper).to_not receive(:rm_rf)
    end

    it "removes and logs a NOTICE when the destination itself is the wrong type (a file, not a directory)" do
      allow(@file_wrapper).to receive(:exist?).with('/build/vendor/unity/src').and_return(true)
      allow(@file_wrapper).to receive(:directory?).with('/build/vendor/unity/src').and_return(false)
      expect(@file_wrapper).to receive(:rm_rf).with('/build/vendor/unity/src')
      expect(@loginator).to receive(:log)
        .with(a_string_including('/build/vendor/unity/src'), Verbosity::COMPLAIN, LogLabels::NOTICE)

      @setup.heal_vendor_path('/build/vendor/unity/src', 'unity.c')
    end

    it "removes and logs a NOTICE when the marker file inside an otherwise-fine destination is the wrong type (Issue #1292's own reported shape: unity.c itself became a directory)" do
      allow(@file_wrapper).to receive(:exist?).with('/build/vendor/unity/src').and_return(true)
      allow(@file_wrapper).to receive(:directory?).with('/build/vendor/unity/src').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('/build/vendor/unity/src/unity.c').and_return(true)
      allow(@file_wrapper).to receive(:directory?).with('/build/vendor/unity/src/unity.c').and_return(true)
      expect(@file_wrapper).to receive(:rm_rf).with('/build/vendor/unity/src')
      expect(@loginator).to receive(:log)
        .with(a_string_including('/build/vendor/unity/src'), Verbosity::COMPLAIN, LogLabels::NOTICE)

      @setup.heal_vendor_path('/build/vendor/unity/src', 'unity.c')
    end
  end

  context "#vendor_frameworks_and_support_files" do
    def flattened_config
      {
        unity_vendor_path:                  '/gem/vendor/unity',
        project_build_vendor_unity_path:    '/build/vendor/unity/src',
        cmock_vendor_path:                  '/gem/vendor/cmock',
        project_build_vendor_cmock_path:    '/build/vendor/cmock/src',
        cexception_vendor_path:             '/gem/vendor/c_exception',
        project_build_vendor_cexception_path: '/build/vendor/c_exception/lib',
        project_use_mocks:                  true,
        project_use_exceptions:             true,
        project_use_backtrace:              false,
        project_use_partials:               false,
      }
    end

    before(:each) do
      allow(@file_wrapper).to receive(:exist?).and_return(false)
      allow(@file_wrapper).to receive(:rm_rf)
      allow(@file_wrapper).to receive(:cp_r_with_retry)
    end

    it "always copies Unity, CMock, and CException, regardless of whether the destination looks already populated" do
      # A prior run's destination "looking populated and uncorrupted" is exactly the
      # state a skip-check would trust -- simulate it directly (dest is a real
      # directory, its marker file is a real file, nothing corrupted) to prove there
      # is no such skip.
      allow(@file_wrapper).to receive(:exist?).and_return(true)
      allow(@file_wrapper).to receive(:directory?) do |path|
        !path.end_with?('.c') # marker files (unity.c, cmock.c, CException.c) are plain files; their parent dirs are directories
      end

      @setup.vendor_frameworks_and_support_files('/gem/lib', flattened_config)

      expect(@file_wrapper).to have_received(:cp_r_with_retry)
        .with(a_string_including('/gem/vendor/unity'), '/build/vendor/unity/src')
      expect(@file_wrapper).to have_received(:cp_r_with_retry)
        .with(a_string_including('/gem/vendor/cmock'), '/build/vendor/cmock/src')
      expect(@file_wrapper).to have_received(:cp_r_with_retry)
        .with(a_string_including('/gem/vendor/c_exception'), '/build/vendor/c_exception/lib')
    end

    it "skips CMock and CException copying when the project doesn't use them" do
      config = flattened_config.merge(project_use_mocks: false, project_use_exceptions: false)

      @setup.vendor_frameworks_and_support_files('/gem/lib', config)

      expect(@file_wrapper).to have_received(:cp_r_with_retry)
        .with(a_string_including('/gem/vendor/unity'), '/build/vendor/unity/src')
      expect(@file_wrapper).to_not have_received(:cp_r_with_retry)
        .with(a_string_including('/gem/vendor/cmock'), anything)
      expect(@file_wrapper).to_not have_received(:cp_r_with_retry)
        .with(a_string_including('/gem/vendor/c_exception'), anything)
    end

    it "heals a corrupted (wrong-typed) vendor destination before copying" do
      allow(@file_wrapper).to receive(:exist?).with('/build/vendor/unity/src').and_return(true)
      allow(@file_wrapper).to receive(:directory?).with('/build/vendor/unity/src').and_return(false)
      allow(@loginator).to receive(:log)

      @setup.vendor_frameworks_and_support_files('/gem/lib', flattened_config)

      expect(@file_wrapper).to have_received(:rm_rf).with('/build/vendor/unity/src')
    end
  end
end
