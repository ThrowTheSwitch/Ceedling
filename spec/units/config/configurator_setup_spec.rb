# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config/configurator_setup'
require 'ceedling/reportinator'
require 'ceedling/config/configurator_validator'
require 'config_yaml_helper'

# Unit coverage for ConfiguratorSetup's validations and build steps through doubled
# collaborators. Configuration is written as YAML, as a project file states it. The real
# pipeline is proven in spec/integration/configurator_pipeline_spec.rb.
describe ConfiguratorSetup do
  include ConfigYamlHelper

  before(:each) do
    @configurator_builder   = double('ConfiguratorBuilder')
    @configurator_validator = double('ConfiguratorValidator')
    @loginator              = double('Loginator')
    @reportinator           = Reportinator.new
    @file_wrapper           = double('FileWrapper')
    @system_wrapper         = double('SystemWrapper')
    @tool_executor          = double('ToolExecutor')

    @setup = described_class.new(
      {
        configurator_builder:   @configurator_builder,
        configurator_validator: @configurator_validator,
        loginator:              @loginator,
        reportinator:           @reportinator,
        file_wrapper:           @file_wrapper,
        system_wrapper:         @system_wrapper,
        tool_executor:          @tool_executor
      }
    )
  end

  it "names only its class when inspected, rather than dumping its collaborators" do
    expect(@setup.inspect).to eq('ConfiguratorSetup')
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

    it "copies the gdb backtrace script and the Partials header when those features are in use" do
      allow(@file_wrapper).to receive(:mkdir)
      allow(@file_wrapper).to receive(:cp_r)
      config = flattened_config.merge(
        project_use_backtrace: :gdb, project_build_tests_root: '/build/test',
        project_use_partials: true, project_build_vendor_ceedling_path: '/build/vendor/ceedling'
      )

      @setup.vendor_frameworks_and_support_files('/gem/lib', config)

      expect(@file_wrapper).to have_received(:mkdir).with('/build/test')
      expect(@file_wrapper).to have_received(:cp_r).with(File.join('/gem/lib', BACKTRACE_GDB_SCRIPT_FILE), '/build/test')
      expect(@file_wrapper).to have_received(:cp_r).with('/gem/lib/ceedling.h', '/build/vendor/ceedling')
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

  # The validations below log each problem they find and report overall validity
  context "configuration validation" do
    before(:each) do
      allow(@loginator).to receive(:log)
      allow(@configurator_validator).to receive(:validate_matcher) { |matcher| ConfiguratorValidator.allocate.validate_matcher( matcher ) }
    end

    def logged(pattern)
      expect(@loginator).to have_received(:log).with(pattern, any_args).at_least(:once)
    end

    context "#validate_required_sections and #validate_required_section_values" do
      it "requires :project and :paths" do
        allow(@configurator_validator).to receive(:exists?).and_return(true)
        allow(@configurator_validator).to receive(:exists?).with(anything, :paths).and_return(false)

        expect(@setup.validate_required_sections( {} )).to be false
        expect(@configurator_validator).to have_received(:exists?).with({}, :project)
      end

      it "requires a build root and test and source paths" do
        allow(@configurator_validator).to receive(:exists?).and_return(true)

        expect(@setup.validate_required_section_values( {} )).to be true
        expect(@configurator_validator).to have_received(:exists?).with({}, :project, :build_root)
        expect(@configurator_validator).to have_received(:exists?).with({}, :paths, :test)
        expect(@configurator_validator).to have_received(:exists?).with({}, :paths, :source)
      end
    end

    context "#validate_paths" do
      let(:config) do
        config_from_yaml( <<~YAML )
          :cmock:
            :unity_helper_path: [helper.h]
          :plugins:
            :load_paths: [plugins]
          :paths:
            :test: [test]
            :source: [src]
          :files:
            :support: [support/x.c]
        YAML
      end

      it "checks helper paths, plugin load paths, and every :paths and :files entry" do
        allow(@configurator_validator).to receive_messages(
          validate_filepath_simple: true, validate_path_list: true, validate_paths_entries: true, validate_files_entries: true
        )

        expect(@setup.validate_paths( config )).to be true
        expect(@configurator_validator).to have_received(:validate_filepath_simple).with('helper.h', :cmock, :unity_helper_path)
        expect(@configurator_validator).to have_received(:validate_filepath_simple).with('plugins', :plugins, :load_paths)
        expect(@configurator_validator).to have_received(:validate_paths_entries).with(config, :source)
        expect(@configurator_validator).to have_received(:validate_files_entries).with(config, :support)
      end

      it "fails when any check fails" do
        allow(@configurator_validator).to receive_messages(
          validate_filepath_simple: true, validate_path_list: true, validate_paths_entries: true, validate_files_entries: false
        )

        expect(@setup.validate_paths( config )).to be false
      end
    end

    context "#validate_tools" do
      it "validates every tool" do
        config = { project: { use_backtrace: :none }, tools: { b: {}, a: {} } }
        allow(@configurator_validator).to receive(:validate_tool).and_return(true, false)

        expect(@setup.validate_tools( config )).to be false
        expect(@configurator_validator).to have_received(:validate_tool).with(config: config, key: :a).ordered
        expect(@configurator_validator).to have_received(:validate_tool).with(config: config, key: :b).ordered
      end
    end

    context "#validate_test_runner_generation" do
      it "allows test case filters when the runner takes command line arguments" do
        expect(@setup.validate_test_runner_generation( { test_runner: { cmdline_args: true } }, 'foo', '' )).to be true
      end

      it "rejects test case filters when the runner takes no command line arguments" do
        expect(@setup.validate_test_runner_generation( { test_runner: { cmdline_args: false } }, '', 'bar' )).to be false
        logged(/Test case filters cannot be used/)
      end

      it "allows no filters either way" do
        expect(@setup.validate_test_runner_generation( { test_runner: { cmdline_args: false } }, '', '' )).to be true
      end
    end

    context "#validate_defines" do
      def validate(yaml)
        @setup.validate_defines( config_from_yaml( yaml ) )
      end

      it "accepts no :defines at all" do
        expect(@setup.validate_defines( {} )).to be true
      end

      it "accepts lists of strings for any context and matchers for :test and :preprocess" do
        expect(validate( <<~YAML )).to be true
          :defines:
            :use_test_definition: true
            :release: [A, B=1]
            :test:
              :*: [ALL]
              /Test(Foo|Bar)/: [REGEX]
              Model: [SUBSTRING]
            :preprocess:
              :Model: [PRE]
        YAML
      end

      it "flattens a list nested by a YAML alias" do
        config = config_from_yaml( ":defines:\n  :common: &common [A]\n  :release: [*common, B]\n" )

        expect(@setup.validate_defines( config )).to be true
        expect(config[:defines][:release]).to eq( ['A', 'B'] )
      end

      it "rejects :defines that is not key / value pairs" do
        expect(validate( ":defines: [A]\n" )).to be false
        logged(/:defines must contain key \/ value pairs, not array/)
      end

      it "rejects a matcher hash outside :test and :preprocess" do
        expect(validate( ":defines:\n  :release:\n    :*: [A]\n" )).to be false
        logged(/matcher hashes are only available for :test & :preprocess \(/)
      end

      it "accepts a matcher hash for :gcov when the gcov plugin is enabled" do
        expect(validate( ":plugins:\n  :enabled: [gcov]\n:defines:\n  :gcov:\n    :*: [A]\n" )).to be true
      end

      it "validates the matchers of :gcov as it does those of :test" do
        expect(validate( ":plugins:\n  :enabled: [gcov]\n:defines:\n  :gcov:\n    :Model: [7]\n" )).to be false
        logged(/:defines ↳ :gcov ↳ :Model entry '7' is not a string/)
      end

      it "rejects a context that is neither a list nor a matcher" do
        expect(validate( ":defines:\n  :test: A\n" )).to be false
        logged(/must be a list or matcher hash, not string/)
        expect(validate( ":defines:\n  :release: A\n" )).to be false
        logged(/must be a list, not string/)
      end

      it "rejects a symbol that is not a string" do
        expect(validate( ":defines:\n  :release: [A, 7]\n" )).to be false
        logged(/list entry '7' must be a string, not integer/)
      end

      it "rejects a matcher whose symbols are not a list of strings" do
        expect(validate( ":defines:\n  :test:\n    :Model: A\n" )).to be false
        logged(/is not a list of compilation symbols but a string/)
        expect(validate( ":defines:\n  :test:\n    :Model: [7]\n" )).to be false
        logged(/entry '7' is not a string/)
      end

      it "rejects a matcher key that is not a string or symbol" do
        expect(validate( ":defines:\n  :test:\n    7: [A]\n" )).to be false
        logged(/:defines ↳ :test matcher '7' is not a string or symbol/)
      end

      it "rejects a malformed matcher" do
        expect(validate( ":defines:\n  :test:\n    /Test(/: [A]\n" )).to be false
        logged(/Matcher :defines ↳ :test ↳ :\/Test\(\/ contains invalid regular expression/)
      end
    end

    context "#validate_flags" do
      def validate(yaml)
        @setup.validate_flags( config_from_yaml( yaml ) )
      end

      it "accepts no :flags at all" do
        expect(@setup.validate_flags( {} )).to be true
      end

      it "accepts lists of strings for any operation and matchers for :test operations" do
        expect(validate( <<~YAML )).to be true
          :flags:
            :release:
              :compile: [-O2]
            :test:
              :compile:
                :*: [-g]
                /Test(Foo|Bar)/: [-Wall]
              :link: [-lm]
        YAML
      end

      it "rejects :flags that is not key / value pairs" do
        expect(validate( ":flags: [-g]\n" )).to be false
        logged(/:flags must contain key \/ value pairs, not array/)
      end

      it "rejects a context that is not operation key / value pairs, and still checks the others" do
        expect(validate( ":flags:\n  :test: [-g]\n  :release:\n    :compile: [7]\n" )).to be false
        logged(/:flags ↳ :test context must contain :<operation> key \/ value pairs, not array/)
        logged(/:flags ↳ :release ↳ :compile list entry '7' must be a string/)
      end

      it "rejects a context with nothing beneath it" do
        expect(validate( ":flags:\n  :test:\n  :release:\n    :compile: [-O2]\n" )).to be false
        logged(/:flags ↳ :test operations key \/ value pairs are missing/)
      end

      it "rejects an operation with nothing beneath it" do
        expect(validate( ":flags:\n  :test:\n    :compile:\n" )).to be false
        logged(/:flags ↳ :test ↳ :compile is missing a list or matcher hash/)
      end

      it "warns that release preprocessing flags are unsupported" do
        expect(validate( ":flags:\n  :release:\n    :preprocess: [-E]\n" )).to be true
        expect(@loginator).to have_received(:log).with(/only supported in the :test context/, Verbosity::ERRORS, LogLabels::WARNING)
      end

      it "rejects a matcher hash outside :test" do
        expect(validate( ":flags:\n  :release:\n    :compile:\n      :*: [-g]\n" )).to be false
        logged(/matcher hashes are only available for :test \(/)
      end

      it "accepts a matcher hash for :gcov when the gcov plugin is enabled" do
        expect(validate( ":plugins:\n  :enabled: [gcov]\n:flags:\n  :gcov:\n    :compile:\n      :*: [-g]\n" )).to be true
      end

      it "rejects an operation that is neither a list nor a matcher" do
        expect(validate( ":flags:\n  :test:\n    :compile: -g\n" )).to be false
        logged(/must be a list or matcher hash, not string/)
        expect(validate( ":flags:\n  :release:\n    :compile: -g\n" )).to be false
        logged(/must be a list, not string/)
      end

      it "rejects a flag that is not a string" do
        expect(validate( ":flags:\n  :release:\n    :compile: [-g, 7]\n" )).to be false
        logged(/:flags ↳ :release ↳ :compile list entry '7' must be a string/)
      end

      it "rejects a matcher whose flags are not a list of strings" do
        expect(validate( ":flags:\n  :test:\n    :compile:\n      :Model: -g\n" )).to be false
        logged(/is not a list of command line flags but a string/)
        expect(validate( ":flags:\n  :test:\n    :compile:\n      :Model: [7]\n" )).to be false
        logged(/entry '7' is not a string/)
      end

      it "rejects a matcher key that is not a string or symbol" do
        expect(validate( ":flags:\n  :test:\n    :compile:\n      7: [-g]\n" )).to be false
        logged(/:flags ↳ :test ↳ :compile matcher '7' is not a string or symbol/)
      end

      it "rejects a malformed matcher" do
        expect(validate( ":flags:\n  :test:\n    :compile:\n      Foo$: [-g]\n" )).to be false
        logged(/contains invalid substring or wildcard characters/)
      end
    end

    context "#validate_test_preprocessor and #validate_backtrace" do
      it "accepts each preprocessing option" do
        [:none, :all, :tests, :mocks].each do |option|
          expect(@setup.validate_test_preprocessor( { project: { use_test_preprocessor: option } } )).to be true
        end
      end

      it "names the preprocessing options when rejecting another value" do
        expect(@setup.validate_test_preprocessor( { project: { use_test_preprocessor: :some } } )).to be false
        logged(/:project ↳ :use_test_preprocessor is ':some' but must be one of \{:none, :all, :tests, :mocks\}/)
      end

      it "accepts each backtrace option" do
        [:none, :simple, :gdb].each do |option|
          expect(@setup.validate_backtrace( { project: { use_backtrace: option } } )).to be true
        end
      end

      it "names the backtrace options when rejecting another value" do
        expect(@setup.validate_backtrace( { project: { use_backtrace: true } } )).to be false
        logged(/:project ↳ :use_backtrace is ':true' but must be one of \{:none, :simple, :gdb\}/)
      end
    end

    context "#validate_environment_vars" do
      def validate(yaml)
        @setup.validate_environment_vars( config_from_yaml( yaml ) )
      end

      it "accepts no :environment at all" do
        expect(@setup.validate_environment_vars( {} )).to be true
      end

      it "accepts single-pair entries of strings or lists of strings" do
        expect(validate( ":environment:\n  - :path: [a, b]\n  - :cc: gcc\n  - CFLAGS: -O2\n" )).to be true
      end

      it "rejects :environment that is not a list" do
        expect(validate( ":environment:\n  :cc: gcc\n" )).to be false
        logged(/:environment must contain a list of key \/ value pairs, not hash/)
      end

      it "rejects an entry that is not a key / value pair" do
        expect(validate( ":environment:\n  - gcc\n" )).to be false
        logged(/list entry gcc is not a key \/ value pair/)
      end

      it "rejects an entry with more than one key" do
        expect(validate( ":environment:\n  - :cc: gcc\n    :ld: ld\n" )).to be false
        logged(/does not specify exactly one key/)
      end

      it "rejects a key that is not a symbol or string" do
        expect(validate( ":environment:\n  - 7: gcc\n" )).to be false
        logged(/entry '7' must be a symbol or string/)
      end

      it "rejects a value that is not a string or list of strings" do
        expect(validate( ":environment:\n  - :cc: 7\n" )).to be false
        logged(/associated with integer, not a string or list/)
        expect(validate( ":environment:\n  - :path: [a, 7]\n" )).to be false
        logged(/contains a list element '7' \(integer\) that is not a string/)
      end

      it "rejects a variable named twice, regardless of case" do
        expect(validate( ":environment:\n  - :cc: gcc\n  - CC: clang\n" )).to be false
        logged(/Duplicate :environment entry :cc found/)
      end
    end

    context "#validate_threads" do
      def validate(compile, test)
        @setup.validate_threads( { project: { compile_threads: compile, test_threads: test } } )
      end

      it "accepts a positive count or :auto" do
        expect(validate( 1, :auto )).to be true
      end

      it "rejects a count below one" do
        expect(validate( 0, 1 )).to be false
        logged(/:project ↳ :compile_threads must be greater than 0/)
        expect(validate( 1, -2 )).to be false
        logged(/:project ↳ :test_threads must be greater than 0/)
      end

      it "rejects any other value" do
        expect(validate( :many, 'auto' )).to be false
        expect(validate( 'auto', :many )).to be false
        logged(/:project ↳ :compile_threads is neither an integer nor :auto/)
        logged(/:project ↳ :test_threads is neither an integer nor :auto/)
      end
    end

    # A plugin is found when discovery found its directory, whatever kind of plugin it is
    context "#validate_plugins" do
      it "accepts enabled plugins whose directories were found" do
        config = { plugins: { enabled: ['beep', 'rk', 'zap'], beep_path: 'p/beep', rk_path: 'p/rk', zap_path: 'p/zap' } }

        expect(@setup.validate_plugins( config )).to be true
      end

      it "names each enabled plugin that was not found" do
        config = { plugins: { enabled: ['beep', 'rk'], rk_path: 'p/rk' } }

        expect(@setup.validate_plugins( config )).to be false
        logged(/Plugin 'beep' not found/)
      end
    end
  end

  context "#build_project_config" do
    it "merges build paths, Rakefiles, release target, thread counts, and preprocessing accessors" do
      allow(@configurator_builder).to receive(:set_build_paths).with(anything, 'logs').and_return( { a: 1 } )
      allow(@configurator_builder).to receive(:set_rakefile_components).with('lib', anything).and_return( { b: 2 } )
      allow(@configurator_builder).to receive_messages( set_release_target: { c: 3 }, set_build_thread_counts: { d: 4 }, set_test_preprocessor_accessors: { e: 5 } )

      expect(@setup.build_project_config( 'lib', 'logs', { z: 0 } )).to eq( { z: 0, a: 1, b: 2, c: 3, d: 4, e: 5 } )
    end
  end

  context "#build_directory_structure" do
    before(:each) { allow(@loginator).to receive(:log_list) }

    it "creates every build path" do
      allow(@file_wrapper).to receive(:mkdir)

      @setup.build_directory_structure( { project_build_paths: ['build/a', 'build/b'] } )

      expect(@file_wrapper).to have_received(:mkdir).with('build/a')
      expect(@file_wrapper).to have_received(:mkdir).with('build/b')
    end

    it "refuses a blank build path" do
      allow(@file_wrapper).to receive(:mkdir)

      expect { @setup.build_directory_structure( { project_build_paths: ['build/a', ''] } ) }.to raise_error(CeedlingException, /unexpectedly blank/)
    end
  end

  context "#build_project_collections" do
    it "merges every path and file collection" do
      collections = [
        :expand_all_path_globs, :collect_vendor_paths, :collect_source_and_include_paths, :collect_source_include_vendor_paths,
        :collect_test_support_source_include_paths, :collect_test_support_source_include_vendor_paths, :collect_assembly,
        :collect_headers, :collect_release_build_input, :collect_existing_test_build_input,
        :collect_release_artifact_extra_link_objects, :collect_test_fixture_extra_link_objects, :collect_vendor_framework_sources
      ]
      collections.each { |name| allow(@configurator_builder).to receive(name).and_return( { name => true } ) }
      allow(@configurator_builder).to receive(:collect_tests).and_return( [ { collect_tests: true }, ['test/test_a.c'] ] )
      allow(@configurator_builder).to receive(:collect_source).with(anything, ['test/test_a.c']).and_return( { collect_source: true } )

      result = @setup.build_project_collections( {} )

      expect(result.keys).to match_array( collections + [:collect_tests, :collect_source] )
    end
  end

  context "#build_constants_and_accessors" do
    it "builds constants and accessors from the same configuration" do
      allow(@configurator_builder).to receive_messages( build_global_constants: nil, build_accessor_methods: nil )

      @setup.build_constants_and_accessors( { a: 1 }, :context )

      expect(@configurator_builder).to have_received(:build_global_constants).with( { a: 1 } )
      expect(@configurator_builder).to have_received(:build_accessor_methods).with( { a: 1 }, :context )
    end
  end
end
