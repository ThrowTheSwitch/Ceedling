# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'

# Ceedling runtime path constants that valgrind_constants.rb needs at require time.
PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)
PROJECT_TEST_RESULTS_PATH    = 'build/test/results' unless defined?(PROJECT_TEST_RESULTS_PATH)

TOOLS_VALGRIND = {
  :executable => 'valgrind',
  :name       => 'default_valgrind',
  :optional   => true,
  :arguments  => []
}.freeze unless defined?(TOOLS_VALGRIND)

$: << File.expand_path('../../../../plugins/valgrind/lib', __FILE__)

require 'valgrind_constants'
require 'valgrind'

# Bypasses Plugin#initialize (which would run the real setup(), pulling in far more
# than any single method under test needs) via .allocate, setting only the instance
# variables the method(s) under test actually touch. This mirrors
# spec/units/plugins/bullseye_spec.rb, the sibling external-tool plugin's spec.
#
# No test here invokes a real Valgrind binary or touches the filesystem. All file
# access goes through a stubbed file_wrapper. Real-tool behavior is covered by
# spec/integration/valgrind_log_parsing_spec.rb and the system tier.
describe Valgrind do
  let(:loginator)           { double('loginator', log: nil) }
  let(:reportinator_obj)    { double('reportinator', generate_progress: 'PROGRESS') }
  let(:tool_validator)      { double('tool_validator', validate: nil) }
  let(:plugin_manager)      { double('plugin_manager', register_build_failure: nil) }
  let(:plugin_reportinator) { double('plugin_reportinator') }
  let(:dependinator)        { double('dependinator', register: nil) }
  let(:file_wrapper)        { double('file_wrapper', exist?: true, read: '', mkdir: nil) }
  let(:system_wrapper)      { double('system_wrapper', windows?: false) }
  let(:ceedling) do
    {
      :tool_validator      => tool_validator,
      :plugin_manager      => plugin_manager,
      :plugin_reportinator => plugin_reportinator
    }
  end

  # project_config is the flattened project config hash the plugin reads options from.
  def build_valgrind(project_config = {}, ivars = {})
    instance = Valgrind.allocate
    defaults = {
      configurator:        double('configurator', project_config_hash: project_config),
      ceedling:            ceedling,
      loginator:           loginator,
      reportinator:        reportinator_obj,
      plugin_manager:      plugin_manager,
      plugin_reportinator: plugin_reportinator,
      dependinator:        dependinator,
      file_wrapper:        file_wrapper,
      system_wrapper:      system_wrapper,
      mutex:               Mutex.new,
      result_list:         [],
      memory_errors:       0,
      tests_processed:     0,
      reports_read:        0,
      environment_validated: false
    }
    defaults.merge(ivars).each { |key, value| instance.instance_variable_set(:"@#{key}", value) }
    instance
  end

  ##
  ## Plugin setup
  ##

  describe '#setup' do
    # setup() is exercised against a real instance rather than a bare .allocate,
    # because wiring collaborators is its whole job.
    def run_setup
      services = {
        :configurator            => double('configurator'),
        :loginator               => loginator,
        :reportinator            => reportinator_obj,
        :rake_invocation_tracker => double('rake_invocation_tracker'),
        :plugin_manager          => plugin_manager,
        :plugin_reportinator     => plugin_reportinator,
        :dependinator            => dependinator,
        :file_wrapper            => file_wrapper,
        :system_wrapper          => system_wrapper,
        :tool_validator          => tool_validator,
        :setupinator             => double('setupinator', config_hash: { valgrind: { fail_build: true } })
      }

      instance = Valgrind.allocate
      instance.instance_variable_set(:@ceedling, services)
      instance.setup()
      instance
    end

    it 'starts every counter at zero' do
      instance = run_setup

      expect(instance.instance_variable_get(:@memory_errors)).to eq(0)
      expect(instance.instance_variable_get(:@tests_processed)).to eq(0)
      expect(instance.instance_variable_get(:@reports_read)).to eq(0)
      expect(instance.instance_variable_get(:@result_list)).to eq([])
    end

    # Validating here would make Valgrind a hard dependency of every build this
    # plugin is merely enabled for, including plain `test:all`.
    it 'validates no tool and creates no directory' do
      expect(tool_validator).to_not receive(:validate)
      expect(file_wrapper).to_not receive(:mkdir)

      run_setup
    end

    it 'clones the plugin configuration for dependency tracking' do
      instance = run_setup

      expect(instance.instance_variable_get(:@valgrind_config)).to eq({ fail_build: true })
    end
  end

  ##
  ## Environment validation
  ##

  describe '#validate_environment!' do
    it 'validates the Valgrind tool on a supported platform' do
      valgrind = build_valgrind

      expect(tool_validator).to receive(:validate).with(hash_including(tool: TOOLS_VALGRIND, boom: true))

      valgrind.validate_environment!
    end

    it 'creates the artifacts directory' do
      valgrind = build_valgrind

      expect(file_wrapper).to receive(:mkdir).with(VALGRIND_ARTIFACTS_PATH)

      valgrind.validate_environment!
    end

    it 'raises naming Windows before ever consulting the tool validator' do
      valgrind = build_valgrind({}, system_wrapper: double('system_wrapper', windows?: true))

      expect(tool_validator).to_not receive(:validate)

      expect { valgrind.validate_environment! }.to raise_error(CeedlingException, /does not run on Windows/)
    end

    it 'adds a platform note when the executable is missing' do
      valgrind = build_valgrind
      allow(tool_validator).to receive(:validate).and_raise(CeedlingException.new('valgrind does not exist'))

      expect { valgrind.validate_environment! }.to raise_error(
        CeedlingException, /valgrind does not exist.*Linux and other Unix-like systems/m
      )
    end

    it 'validates at most once across repeated calls' do
      valgrind = build_valgrind

      expect(tool_validator).to receive(:validate).once

      3.times { valgrind.validate_environment! }
    end
  end

  ##
  ## Fixture tool substitution
  ##

  describe '#pre_test_fixture_register' do
    def register(project_config, context: VALGRIND_SYM)
      valgrind = build_valgrind(project_config)
      arg_hash = { context: context, test_name: 'test_thing', target: 'build/out/test_thing.out', tool: { name: 'original' } }
      valgrind.pre_test_fixture_register(arg_hash)
      [valgrind, arg_hash]
    end

    it 'leaves a non-valgrind context untouched' do
      original = { name: 'original' }
      valgrind = build_valgrind({})
      arg_hash = { context: :test, test_name: 'test_thing', tool: original }

      valgrind.pre_test_fixture_register(arg_hash)

      expect(arg_hash[:tool]).to be(original)
      expect(valgrind.instance_variable_get(:@tests_processed)).to eq(0)
    end

    it 'counts the test and writes the log file argument' do
      valgrind, arg_hash = register({ valgrind_arguments: ['--leak-check=full'] })

      expect(valgrind.instance_variable_get(:@tests_processed)).to eq(1)
      expect(arg_hash[:tool][:arguments]).to include('--log-file="artifacts/valgrind/test_thing.log"')
    end

    it 'appends the executable substitution token last' do
      _valgrind, arg_hash = register({ valgrind_arguments: ['--leak-check=full'] })

      expect(arg_hash[:tool][:arguments].last).to eq('${1}')
    end

    it 'places user arguments after the plugin-managed ones' do
      _valgrind, arg_hash = register({ valgrind_arguments: ['--leak-check=full'] })
      args = arg_hash[:tool][:arguments]

      expect(args.index('--leak-check=full')).to be > args.index { |a| a.start_with?('--log-file=') }
    end

    it 'adds one --suppressions argument per configured file' do
      _valgrind, arg_hash = register({ valgrind_suppressions: ['a.supp', 'b.supp'] })

      expect(arg_hash[:tool][:arguments]).to include('--suppressions="a.supp"', '--suppressions="b.supp"')
    end

    it 'omits XML arguments when :xml_report is disabled' do
      _valgrind, arg_hash = register({ valgrind_xml_report: false })

      expect(arg_hash[:tool][:arguments]).to_not include('--xml=yes')
    end

    it 'adds XML arguments when :xml_report is enabled' do
      _valgrind, arg_hash = register({ valgrind_xml_report: true })

      expect(arg_hash[:tool][:arguments]).to include('--xml=yes')
      expect(arg_hash[:tool][:arguments]).to include('--xml-file="artifacts/valgrind/test_thing.xml"')
    end

    # Rebuilding the tool hash from scratch silently dropped every other key a user
    # set under :tools ↳ :valgrind.
    it 'preserves other keys configured on the Valgrind tool' do
      _valgrind, arg_hash = register({})

      expect(arg_hash[:tool][:executable]).to eq(TOOLS_VALGRIND[:executable])
      expect(arg_hash[:tool][:name]).to eq(TOOLS_VALGRIND[:name])
      expect(arg_hash[:tool][:optional]).to eq(TOOLS_VALGRIND[:optional])
    end

    it 'registers the plugin configuration as dependency meta' do
      valgrind = build_valgrind({}, valgrind_config: { fail_build: true })
      arg_hash = { context: VALGRIND_SYM, test_name: 'test_thing', target: 'build/out/test_thing.out', tool: {} }

      expect(dependinator).to receive(:register).with('build/out/test_thing.out', meta: { valgrind: { fail_build: true } })

      valgrind.pre_test_fixture_register(arg_hash)
    end
  end

  describe '#pre_test_fixture_execute' do
    it 'sets a Valgrind-specific progress message' do
      valgrind = build_valgrind
      arg_hash = { context: VALGRIND_SYM, executable: 'build/out/test_thing.out' }

      valgrind.pre_test_fixture_execute(arg_hash)

      expect(arg_hash[:msg]).to eq('PROGRESS')
    end

    it 'sets no message for a non-valgrind context' do
      valgrind = build_valgrind
      arg_hash = { context: :test, executable: 'build/out/test_thing.out' }

      valgrind.pre_test_fixture_execute(arg_hash)

      expect(arg_hash[:msg]).to be_nil
    end
  end

  ##
  ## Error counting
  ##

  describe '#post_test_fixture_execute' do
    def execute(project_config, log_contents, exists: true, result_file: File.join(PROJECT_TEST_RESULTS_PATH, 'test_thing.pass'))
      wrapper  = double('file_wrapper', exist?: exists, read: log_contents)
      valgrind = build_valgrind(project_config, file_wrapper: wrapper)
      valgrind.post_test_fixture_execute(
        { context: VALGRIND_SYM, test_name: 'test_thing', result_file: result_file }
      )
      valgrind
    end

    it 'ignores a non-valgrind context' do
      valgrind = build_valgrind
      valgrind.post_test_fixture_execute({ context: :test, test_name: 'test_thing', result_file: 'x.pass' })

      expect(valgrind.instance_variable_get(:@reports_read)).to eq(0)
    end

    it 'accumulates a result file inside the results path' do
      valgrind = execute({}, 'ERROR SUMMARY: 0 errors from 0 contexts')

      expect(valgrind.instance_variable_get(:@result_list).length).to eq(1)
    end

    it 'ignores a result file outside the results path' do
      valgrind = execute({}, 'ERROR SUMMARY: 0 errors', result_file: 'build/other/test_thing.pass')

      expect(valgrind.instance_variable_get(:@result_list)).to eq([])
    end

    it 'records zero errors for a clean log' do
      valgrind = execute({}, '==1== ERROR SUMMARY: 0 errors from 0 contexts (suppressed: 0 from 0)')

      expect(valgrind.instance_variable_get(:@memory_errors)).to eq(0)
      expect(valgrind.instance_variable_get(:@reports_read)).to eq(1)
    end

    it 'records the error count from a single summary' do
      valgrind = execute({}, '==1== ERROR SUMMARY: 6 errors from 6 contexts (suppressed: 0 from 0)')

      expect(valgrind.instance_variable_get(:@memory_errors)).to eq(6)
    end

    # Valgrind writes one summary per traced process. A forking test produces several.
    # Reading only the first undercounts, which real Valgrind output confirms.
    it 'sums every summary when a test forks' do
      log = "==70== ERROR SUMMARY: 2 errors from 2 contexts (suppressed: 0 from 0)\n" \
            "==69== ERROR SUMMARY: 1 errors from 1 contexts (suppressed: 0 from 0)\n"
      valgrind = execute({}, log)

      expect(valgrind.instance_variable_get(:@memory_errors)).to eq(3)
    end

    it 'counts <error> elements when :xml_report is enabled' do
      xml = '<valgrindoutput><error><kind>Leak_DefinitelyLost</kind></error>' \
            '<error><kind>UninitValue</kind></error></valgrindoutput>'
      valgrind = execute({ valgrind_xml_report: true }, xml)

      expect(valgrind.instance_variable_get(:@memory_errors)).to eq(2)
    end

    # A silent skip reads exactly like a clean result. It is not one.
    it 'warns and records nothing when no report was written' do
      expect(loginator).to receive(:log).with(/wrote no report for test_thing/, anything, anything)

      valgrind = execute({}, '', exists: false)

      expect(valgrind.instance_variable_get(:@reports_read)).to eq(0)
      expect(valgrind.instance_variable_get(:@memory_errors)).to eq(0)
    end

    it 'logs an error naming the test when errors are found' do
      expect(loginator).to receive(:log).with(/Valgrind detected 6 memory errors in test_thing/, anything, anything)

      execute({}, 'ERROR SUMMARY: 6 errors from 6 contexts')
    end
  end

  ##
  ## Build completion
  ##

  describe '#post_build' do
    let(:configurator) { double('configurator', plugins_display_raw_test_results: true, valgrind_fail_build: true) }

    def build_post_build(ivars = {})
      tracker = double('rake_invocation_tracker', invoked?: true)
      build_valgrind(
        {},
        {
          configurator: configurator,
          rake_invocation_tracker: tracker,
          result_list: []
        }.merge(ivars)
      )
    end

    it 'does nothing when no valgrind task was invoked' do
      valgrind = build_post_build(rake_invocation_tracker: double('tracker', invoked?: false))

      expect(loginator).to_not receive(:log)

      valgrind.post_build(0)
    end

    # Emitting this per erroring test repeated the same summary several times, each
    # with a different partial count.
    it 'logs the report summary exactly once' do
      valgrind = build_post_build(reports_read: 3, memory_errors: 0)

      expect(loginator).to receive(:log).with(/Wrote 3 Valgrind reports/, anything, anything).once

      valgrind.post_build(0)
    end

    it 'reports the number of reports actually read, not tests attempted' do
      valgrind = build_post_build(reports_read: 1, tests_processed: 4, memory_errors: 0)

      expect(loginator).to receive(:log).with(/Wrote 1 Valgrind report to/, anything, anything)

      valgrind.post_build(0)
    end

    it 'logs no summary when no report was read' do
      valgrind = build_post_build(reports_read: 0)

      expect(loginator).to_not receive(:log).with(/Wrote/, anything, anything)

      valgrind.post_build(0)
    end

    it 'registers a build failure naming errors and tests when :fail_build is enabled' do
      valgrind = build_post_build(memory_errors: 5, tests_processed: 2, reports_read: 2)

      expect(plugin_manager).to receive(:register_build_failure).with(
        VALGRIND_SYM, 'Valgrind detected 5 memory errors across 2 tests'
      )

      valgrind.post_build(0)
    end

    it 'registers no build failure when :fail_build is disabled' do
      quiet = double('configurator', plugins_display_raw_test_results: true, valgrind_fail_build: false)
      valgrind = build_post_build(memory_errors: 5, reports_read: 1, configurator: quiet)

      expect(plugin_manager).to_not receive(:register_build_failure)

      valgrind.post_build(0)
    end

    it 'registers no build failure when no errors were found' do
      valgrind = build_post_build(memory_errors: 0, reports_read: 2)

      expect(plugin_manager).to_not receive(:register_build_failure)

      valgrind.post_build(0)
    end

    it 'runs the plugin test-results report when no other plugin displays raw results' do
      quiet = double('configurator', plugins_display_raw_test_results: false, valgrind_fail_build: false)
      valgrind = build_post_build(configurator: quiet, reports_read: 0)

      allow(plugin_reportinator).to receive(:test_results_floor_verbosity).and_return(Verbosity::ERRORS)
      expect(plugin_reportinator).to receive(:assemble_test_results).with([]).and_return({})
      expect(plugin_reportinator).to receive(:run_test_results_report)

      valgrind.post_build(0)
    end
  end
end
