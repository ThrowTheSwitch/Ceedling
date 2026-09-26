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
require 'ceedling/filename_extension'

PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

# bullseye_constants.rb assembles TOOL_COLLECTION_BULLSEYE_TASKS from these at load time
TOOLS_BULLSEYE_COMPILER  = { name: 'bullseye_compiler' }.freeze  unless defined?(TOOLS_BULLSEYE_COMPILER)
TOOLS_BULLSEYE_LINKER    = { name: 'bullseye_linker' }.freeze    unless defined?(TOOLS_BULLSEYE_LINKER)
TOOLS_BULLSEYE_FIXTURE   = { name: 'bullseye_fixture' }.freeze   unless defined?(TOOLS_BULLSEYE_FIXTURE)
TOOLS_TEST_ASSEMBLER     = { name: 'test_assembler' }.freeze     unless defined?(TOOLS_TEST_ASSEMBLER)

TOOLS_BULLSEYE_REPORT_COVSRC  = { name: 'covsrc' }.freeze   unless defined?(TOOLS_BULLSEYE_REPORT_COVSRC)
TOOLS_BULLSEYE_REPORT_COVFN   = { name: 'covfn' }.freeze    unless defined?(TOOLS_BULLSEYE_REPORT_COVFN)
TOOLS_BULLSEYE_REPORT_COVBR   = { name: 'covbr' }.freeze    unless defined?(TOOLS_BULLSEYE_REPORT_COVBR)
TOOLS_BULLSEYE_REPORT_COVXML  = { name: 'covxml' }.freeze   unless defined?(TOOLS_BULLSEYE_REPORT_COVXML)
TOOLS_BULLSEYE_REPORT_COVHTML = { name: 'covhtml' }.freeze  unless defined?(TOOLS_BULLSEYE_REPORT_COVHTML)
TOOLS_BULLSEYE_COVSELECT      = { name: 'covselect' }.freeze unless defined?(TOOLS_BULLSEYE_COVSELECT)
TOOLS_BULLSEYE_LICENSE_STATUS = { name: 'covlmgr' }.freeze  unless defined?(TOOLS_BULLSEYE_LICENSE_STATUS)

EXTENSION_ASSEMBLY  = FilenameExtension.new('.s') unless defined?(EXTENSION_ASSEMBLY)
EXTENSION_SOURCE    = FilenameExtension.new('.c') unless defined?(EXTENSION_SOURCE)
ENVIRONMENT_COVFILE = 'test.cov'                  unless defined?(ENVIRONMENT_COVFILE)
COLLECTION_ALL_TESTS = ['test/test_a.c'].freeze   unless defined?(COLLECTION_ALL_TESTS)

$: << File.expand_path('../../../../plugins/bullseye/lib', __FILE__)

require 'bullseye_constants'
require 'bullseye'

# Bypasses Plugin#initialize (which would run the real setup(), pulling in far more
# than any single method under test needs) via .allocate, setting only the instance
# variables the method(s) under test actually touch. This mirrors
# spec/units/plugins/gcov_spec.rb, the sibling coverage plugin's spec.
#
# No test here invokes a real Bullseye binary. Real-tool behavior is covered by
# spec/system/bullseye_deployment_spec.rb.
describe Bullseye do
  let(:loginator)           { double('loginator', log: nil, lazy: nil, log_list: nil) }
  let(:reportinator_obj)    { double('reportinator', generate_module_progress: 'PROGRESS', generate_skip_summary: nil) }
  let(:tool_executor)       { double('tool_executor') }
  let(:tool_validator)      { double('tool_validator', validate: nil) }
  let(:plugin_manager)      { double('plugin_manager', register_build_failure: nil) }
  let(:plugin_reportinator) { double('plugin_reportinator', generate_banner: 'BANNER', run_report: nil) }
  let(:file_wrapper)        { double('file_wrapper', exist?: true, mkdir: nil) }
  let(:ceedling) do
    {
      :tool_validator      => tool_validator,
      :plugin_manager      => plugin_manager,
      :tool_executor       => tool_executor,
      :plugin_reportinator => plugin_reportinator
    }
  end

  # ivars: hash of instance-variable-name (without @) => value, letting each test set
  # only the collaborators its own method under test needs on top of these defaults.
  def build_bullseye(project_config, ivars = {})
    instance = Bullseye.allocate
    defaults = {
      project_config:      project_config,
      ceedling:            ceedling,
      loginator:           loginator,
      reportinator:        reportinator_obj,
      tool_executor:       tool_executor,
      plugin_reportinator: plugin_reportinator,
      file_wrapper:        file_wrapper
    }
    defaults.merge(ivars).each { |key, value| instance.instance_variable_set(:"@#{key}", value) }
    instance
  end

  ##
  ## Plugin setup
  ##

  describe '#setup' do
    # setup() is the one method exercised against a real instance rather than a
    # bare .allocate, because assembling @environment is its whole job.
    def run_setup(project_config)
      configurator = double('configurator', project_config_hash: project_config)
      services = ceedling.merge(
        :configurator => configurator,
        :loginator    => loginator,
        :reportinator => reportinator_obj,
        :test_invoker => double('test_invoker'),
        :file_wrapper => double('file_wrapper', read: 'TEMPLATE')
      )

      instance = Bullseye.allocate
      instance.instance_variable_set(:@ceedling, services)
      instance.instance_variable_set(:@plugin_root_path, '/plugins/bullseye')
      instance.setup()
      instance
    end

    let(:valid_config) do
      {
        bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_LIST,
        bullseye_branch_detail:    BULLSEYE_BRANCH_DETAIL_NONE,
        bullseye_xml_report:       BULLSEYE_XML_REPORT_NONE
      }
    end

    it 'always places COVFILE in the plugin environment' do
      instance = run_setup(valid_config)

      expect(instance.instance_variable_get(:@environment)).to eq([{ covfile: BULLSEYE_COVFILE_PATH }])
    end

    it 'adds COVLM to the environment only when a license manager file is configured' do
      instance = run_setup(valid_config.merge(bullseye_license_manager_file: '/shared/bullseye.lmgr'))

      expect(instance.instance_variable_get(:@environment)).to eq([
        { covfile: BULLSEYE_COVFILE_PATH },
        { covlm: '/shared/bullseye.lmgr' }
      ])
    end

    it 'validates the compiler and linker tools up front' do
      expect(tool_validator).to receive(:validate).with(hash_including(tool: TOOLS_BULLSEYE_COMPILER, boom: true))
      expect(tool_validator).to receive(:validate).with(hash_including(tool: TOOLS_BULLSEYE_LINKER, boom: true))

      run_setup(valid_config)
    end

    it 'fails fast on an unrecognized enumerated option' do
      expect {
        run_setup(valid_config.merge(bullseye_xml_report: :bogus))
      }.to raise_error(CeedlingException, /:xml_report/)
    end
  end

  ##
  ## Configuration validation
  ##

  describe '#validate_untested_sources' do
    it 'passes for every recognized :untested_sources mode' do
      bullseye = build_bullseye({})
      BULLSEYE_UNTESTED_SOURCES_OPTIONS.each do |mode|
        expect {
          bullseye.send(:validate_untested_sources, { bullseye_untested_sources: mode })
        }.to_not raise_error
      end
    end

    it 'raises CeedlingException naming the bad value and listing valid options' do
      bullseye = build_bullseye({})
      expect {
        bullseye.send(:validate_untested_sources, { bullseye_untested_sources: :bogus })
      }.to raise_error(CeedlingException, /:untested_sources.*bogus.*:ignore.*:list.*:compile/)
    end
  end

  describe '#validate_branch_detail' do
    it 'passes for every recognized :branch_detail mode' do
      bullseye = build_bullseye({})
      BULLSEYE_BRANCH_DETAIL_OPTIONS.each do |mode|
        expect {
          bullseye.send(:validate_branch_detail, { bullseye_branch_detail: mode })
        }.to_not raise_error
      end
    end

    it 'raises CeedlingException naming the bad value and listing valid options' do
      bullseye = build_bullseye({})
      expect {
        bullseye.send(:validate_branch_detail, { bullseye_branch_detail: :bogus })
      }.to raise_error(CeedlingException, /:branch_detail.*bogus.*:none.*:uncovered.*:all/)
    end
  end

  describe '#validate_xml_report' do
    it 'passes for every recognized :xml_report format' do
      bullseye = build_bullseye({})
      BULLSEYE_XML_REPORT_OPTIONS.each do |format|
        expect {
          bullseye.send(:validate_xml_report, { bullseye_xml_report: format })
        }.to_not raise_error
      end
    end

    it 'raises CeedlingException naming the bad value and listing valid options' do
      bullseye = build_bullseye({})
      expect {
        bullseye.send(:validate_xml_report, { bullseye_xml_report: :bogus })
      }.to raise_error(CeedlingException, /:xml_report.*bogus.*:none.*:native.*:cobertura/)
    end
  end

  ##
  ## Configuration predicates
  ##

  describe 'configuration predicates' do
    it 'reports automatic reporting enabled only when :report_task is false' do
      expect(build_bullseye({ bullseye_report_task: false }).automatic_reporting_enabled?).to be true
      expect(build_bullseye({ bullseye_report_task: true }).automatic_reporting_enabled?).to be false
    end

    it 'reports summaries enabled unless :summaries is explicitly false' do
      expect(build_bullseye({ bullseye_summaries: true }).summaries_enabled?).to be true
      expect(build_bullseye({}).summaries_enabled?).to be true
      expect(build_bullseye({ bullseye_summaries: false }).summaries_enabled?).to be false
    end

    it 'reports untested-source compilation enabled only for :compile' do
      expect(build_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_COMPILE }).untested_sources_compile_enabled?).to be true
      expect(build_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_LIST }).untested_sources_compile_enabled?).to be false
    end

    it 'reports thresholds configured only when a minimum is above zero' do
      expect(build_bullseye({}).send(:thresholds_configured?)).to be false
      expect(build_bullseye({ bullseye_fail_under: { functions: 0, branches: 0 } }).send(:thresholds_configured?)).to be false
      expect(build_bullseye({ bullseye_fail_under: { functions: 90, branches: 0 } }).send(:thresholds_configured?)).to be true
      expect(build_bullseye({ bullseye_fail_under: { functions: 0, branches: 75 } }).send(:thresholds_configured?)).to be true
    end
  end

  ##
  ## Build pipeline hooks
  ##

  describe '#pre_test_compile_register' do
    it 'swaps in the Bullseye compiler and adds the coverage define for the bullseye context' do
      bullseye = build_bullseye({})
      arg_hash = { context: BULLSEYE_SYM, source: 'src/a.c', tool: { name: 'original' }, defines: [] }

      bullseye.pre_test_compile_register(arg_hash)

      expect(arg_hash[:tool]).to eq(TOOLS_BULLSEYE_COMPILER)
      expect(arg_hash[:defines]).to eq(['CODE_COVERAGE'])
    end

    it 'leaves a non-bullseye context untouched' do
      bullseye = build_bullseye({})
      original = { name: 'original' }
      arg_hash = { context: :test, source: 'src/a.c', tool: original, defines: [] }

      bullseye.pre_test_compile_register(arg_hash)

      expect(arg_hash[:tool]).to be(original)
      expect(arg_hash[:defines]).to eq([])
    end

    it 'leaves assembly sources uninstrumented' do
      bullseye = build_bullseye({})
      original = { name: 'original' }
      arg_hash = { context: BULLSEYE_SYM, source: 'src/a.s', tool: original, defines: [] }

      bullseye.pre_test_compile_register(arg_hash)

      expect(arg_hash[:tool]).to be(original)
      expect(arg_hash[:defines]).to eq([])
    end
  end

  describe '#pre_compile_execute' do
    it 'sets a coverage-specific progress message for the bullseye context' do
      bullseye = build_bullseye({})
      arg_hash = { context: BULLSEYE_SYM, source: 'src/a.c', module_name: 'a' }

      expect(reportinator_obj).to receive(:generate_module_progress)
        .with(hash_including(operation: 'Compiling with coverage')).and_return('PROGRESS')

      bullseye.pre_compile_execute(arg_hash)

      expect(arg_hash[:msg]).to eq('PROGRESS')
    end

    it 'sets no message for a non-bullseye context' do
      bullseye = build_bullseye({})
      arg_hash = { context: :test, source: 'src/a.c', module_name: 'a' }

      bullseye.pre_compile_execute(arg_hash)

      expect(arg_hash[:msg]).to be_nil
    end
  end

  describe '#pre_test_link_register' do
    it 'swaps in the Bullseye linker and flags that a bullseye task ran' do
      bullseye = build_bullseye({}, cli_bullseye_task: false)
      arg_hash = { context: BULLSEYE_SYM, tool: { name: 'original' } }

      bullseye.pre_test_link_register(arg_hash)

      expect(arg_hash[:tool]).to eq(TOOLS_BULLSEYE_LINKER)
      expect(bullseye.instance_variable_get(:@cli_bullseye_task)).to be true
    end

    it 'leaves a non-bullseye context untouched and unflagged' do
      bullseye = build_bullseye({}, cli_bullseye_task: false)
      original = { name: 'original' }
      arg_hash = { context: :test, tool: original }

      bullseye.pre_test_link_register(arg_hash)

      expect(arg_hash[:tool]).to be(original)
      expect(bullseye.instance_variable_get(:@cli_bullseye_task)).to be false
    end
  end

  describe '#post_test_fixture_execute' do
    it 'accumulates a result file whose path matches BULLSEYE_RESULTS_PATH' do
      bullseye = build_bullseye({}, mutex: Mutex.new, result_list: [])
      path = File.join(BULLSEYE_RESULTS_PATH, 'test_foo.pass')

      bullseye.post_test_fixture_execute({ result_file: path })

      expect(bullseye.instance_variable_get(:@result_list)).to eq([path])
    end

    it 'ignores a result file outside BULLSEYE_RESULTS_PATH' do
      bullseye = build_bullseye({}, mutex: Mutex.new, result_list: [])

      bullseye.post_test_fixture_execute({ result_file: 'build/other/test_foo.pass' })

      expect(bullseye.instance_variable_get(:@result_list)).to eq([])
    end

    it 'does not add the same result file twice' do
      bullseye = build_bullseye({}, mutex: Mutex.new, result_list: [])
      path = File.join(BULLSEYE_RESULTS_PATH, 'test_foo.pass')

      bullseye.post_test_fixture_execute({ result_file: path })
      bullseye.post_test_fixture_execute({ result_file: path })

      expect(bullseye.instance_variable_get(:@result_list)).to eq([path])
    end
  end

  ##
  ## Coverage totals parsing
  ##

  describe '#collect_coverage_totals' do
    # Real covsrc --csv output. The final row is the whole-project total.
    let(:csv_output) do
      <<~CSV
        "Source","Function Coverage","Function Total","Fn %","C/D Coverage","C/D Total","C/D %"
        "other.c",0,1,0%,0,2,0%
        "main.c",2,3,66%,1,10,10%
        "Total",2,4,50%,1,12,8%
      CSV
    end

    def build_totals_bullseye(output)
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: output })
      build_bullseye({})
    end

    it 'parses function and branch percentages from the Total row' do
      bullseye = build_totals_bullseye(csv_output)

      expect(bullseye.send(:collect_coverage_totals)).to eq({ functions: 50, branches: 8 })
    end

    it 'returns nil percentages when no Total row is present' do
      bullseye = build_totals_bullseye("\"Source\",\"Function Coverage\"\n")

      expect(bullseye.send(:collect_coverage_totals)).to eq({ functions: nil, branches: nil })
    end

    it 'returns nil percentages for an empty percentage field' do
      bullseye = build_totals_bullseye("\"Total\",0,0,,0,0,\n")

      expect(bullseye.send(:collect_coverage_totals)).to eq({ functions: nil, branches: nil })
    end

    it 'logs a complaint and returns nil percentages for malformed CSV' do
      bullseye = build_totals_bullseye("\"unterminated\n")

      expect(loginator).to receive(:log).with(/Could not parse Bullseye coverage totals/, Verbosity::COMPLAIN)
      expect(bullseye.send(:collect_coverage_totals)).to eq({ functions: nil, branches: nil })
    end
  end

  describe '#extract_coverage_percentage' do
    it 'extracts an integer percentage' do
      bullseye = build_bullseye({})
      expect(bullseye.send(:extract_coverage_percentage, '66%')).to eq(66)
      expect(bullseye.send(:extract_coverage_percentage, '0%')).to eq(0)
      expect(bullseye.send(:extract_coverage_percentage, '100%')).to eq(100)
    end

    it 'returns nil for a field carrying no percentage' do
      bullseye = build_bullseye({})
      expect(bullseye.send(:extract_coverage_percentage, '')).to be_nil
      expect(bullseye.send(:extract_coverage_percentage, nil)).to be_nil
    end
  end

  describe '#report_coverage_results_all' do
    it 'renders the summary template with the collected totals' do
      bullseye = build_bullseye({}, coverage_template_all: 'TEMPLATE')

      expect(plugin_reportinator).to receive(:run_report).with(
        'TEMPLATE',
        { context: BULLSEYE_SYM, coverage: { functions: 50, branches: 8 } }
      )

      bullseye.send(:report_coverage_results_all, { functions: 50, branches: 8 })
    end
  end

  ##
  ## Branch coverage detail
  ##

  describe '#report_branch_coverage_results' do
    it 'does nothing for :none' do
      bullseye = build_bullseye({ bullseye_branch_detail: BULLSEYE_BRANCH_DETAIL_NONE })

      expect(tool_executor).to_not receive(:build_command_line)

      bullseye.send(:report_branch_coverage_results)
    end

    it 'passes --uncover for :uncovered and logs the annotated listing' do
      bullseye = build_bullseye({ bullseye_branch_detail: BULLSEYE_BRANCH_DETAIL_UNCOVERED })

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVBR, [], '--uncover').and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "main.c:\n-->  3   if (x)\n" })

      expect(loginator).to receive(:log).with(/-->  3   if \(x\)/)

      bullseye.send(:report_branch_coverage_results)
    end

    it 'passes --all for :all' do
      bullseye = build_bullseye({ bullseye_branch_detail: BULLSEYE_BRANCH_DETAIL_ALL })

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVBR, [], '--all').and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: 'listing' })

      bullseye.send(:report_branch_coverage_results)
    end

    it 'reports no uncovered branches when covbr produces empty output' do
      bullseye = build_bullseye({ bullseye_branch_detail: BULLSEYE_BRANCH_DETAIL_UNCOVERED })

      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "   \n" })

      expect(loginator).to receive(:log).with(/No uncovered branches/)

      bullseye.send(:report_branch_coverage_results)
    end
  end

  ##
  ## Coverage threshold gate
  ##

  describe '#enforce_coverage_thresholds' do
    it 'does nothing when no thresholds are configured' do
      bullseye = build_bullseye({})

      expect(plugin_manager).to_not receive(:register_build_failure)

      bullseye.send(:enforce_coverage_thresholds, { functions: 10, branches: 10 })
    end

    it 'does nothing when coverage meets both thresholds' do
      bullseye = build_bullseye({ bullseye_fail_under: { functions: 50, branches: 40 } })

      expect(plugin_manager).to_not receive(:register_build_failure)

      bullseye.send(:enforce_coverage_thresholds, { functions: 50, branches: 90 })
    end

    it 'registers a build failure naming function coverage when it falls short' do
      bullseye = build_bullseye({ bullseye_fail_under: { functions: 90, branches: 0 } })

      expect(plugin_manager).to receive(:register_build_failure)
        .with(BULLSEYE_SYM, /Function coverage 50% is below the configured minimum of 90%/)

      bullseye.send(:enforce_coverage_thresholds, { functions: 50, branches: 8 })
    end

    it 'registers a build failure naming branch coverage when it falls short' do
      bullseye = build_bullseye({ bullseye_fail_under: { functions: 0, branches: 75 } })

      expect(plugin_manager).to receive(:register_build_failure)
        .with(BULLSEYE_SYM, /Branch coverage 8% is below the configured minimum of 75%/)

      bullseye.send(:enforce_coverage_thresholds, { functions: 50, branches: 8 })
    end

    it 'registers one failure per metric when both fall short' do
      bullseye = build_bullseye({ bullseye_fail_under: { functions: 90, branches: 75 } })

      messages = []
      allow(plugin_manager).to receive(:register_build_failure) { |_context, message| messages << message }

      bullseye.send(:enforce_coverage_thresholds, { functions: 50, branches: 8 })

      expect(messages.length).to eq(2)
      expect(messages[0]).to match(/Function coverage/)
      expect(messages[1]).to match(/Branch coverage/)
    end

    it 'registers a build failure when a threshold is configured but coverage is unavailable' do
      bullseye = build_bullseye({ bullseye_fail_under: { functions: 90, branches: 0 } })

      expect(plugin_manager).to receive(:register_build_failure)
        .with(BULLSEYE_SYM, /Function coverage is unavailable/)

      bullseye.send(:enforce_coverage_thresholds, nil)
    end
  end

  ##
  ## Report generation
  ##

  describe '#generate_html_report' do
    it 'validates covhtml, makes the output directory, and runs the tool' do
      bullseye = build_bullseye({}, file_wrapper: double('file_wrapper', exist?: false, mkdir: nil))

      expect(tool_validator).to receive(:validate).with(hash_including(tool: TOOLS_BULLSEYE_REPORT_COVHTML, boom: true))
      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVHTML, [], BULLSEYE_HTML_ARTIFACTS_PATH).and_return({})
      expect(tool_executor).to receive(:exec).and_return({ output: '' })

      bullseye.generate_html_report()
    end

    it 'registers a build failure carrying license guidance when the tool fails' do
      bullseye = build_bullseye({})

      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_raise(StandardError.new('covhtml exploded'))

      expect(plugin_manager).to receive(:register_build_failure) do |context, message|
        expect(context).to eq(BULLSEYE_SYM)
        expect(message).to match(/covhtml exploded/)
        expect(message).to match(/utils:bullseye_license/)
      end

      bullseye.generate_html_report()
    end
  end

  describe '#generate_xml_report' do
    it 'does nothing for :none' do
      bullseye = build_bullseye({ bullseye_xml_report: BULLSEYE_XML_REPORT_NONE })

      expect(tool_executor).to_not receive(:build_command_line)

      bullseye.generate_xml_report()
    end

    it 'passes an empty format flag for :native' do
      bullseye = build_bullseye({ bullseye_xml_report: BULLSEYE_XML_REPORT_NATIVE })

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVXML, [], '', BULLSEYE_XML_ARTIFACT_PATH).and_return({})
      expect(tool_executor).to receive(:exec).and_return({ output: '' })

      bullseye.generate_xml_report()
    end

    it 'passes --cobertura for :cobertura' do
      bullseye = build_bullseye({ bullseye_xml_report: BULLSEYE_XML_REPORT_COBERTURA })

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVXML, [], '--cobertura', BULLSEYE_XML_ARTIFACT_PATH).and_return({})
      expect(tool_executor).to receive(:exec).and_return({ output: '' })

      bullseye.generate_xml_report()
    end

    it 'registers a build failure carrying license guidance when the tool fails' do
      bullseye = build_bullseye({ bullseye_xml_report: BULLSEYE_XML_REPORT_COBERTURA })

      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_raise(StandardError.new('covxml exploded'))

      expect(plugin_manager).to receive(:register_build_failure) do |_context, message|
        expect(message).to match(/covxml exploded/)
        expect(message).to match(/utils:bullseye_license/)
      end

      bullseye.generate_xml_report()
    end
  end

  ##
  ## License diagnostics
  ##

  describe '#report_license_status' do
    it 'validates covlmgr and logs its output beneath a banner' do
      bullseye = build_bullseye({})

      expect(tool_validator).to receive(:validate).with(hash_including(tool: TOOLS_BULLSEYE_LICENSE_STATUS, boom: true))
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "License 123456\nLicense manager disabled\n" })

      expect(loginator).to receive(:log).with(/License manager disabled/)

      bullseye.report_license_status()
    end

    it 'registers a build failure when covlmgr is unavailable' do
      bullseye = build_bullseye({})

      allow(tool_validator).to receive(:validate).and_raise(CeedlingException.new('covlmgr not found'))

      expect(plugin_manager).to receive(:register_build_failure).with(BULLSEYE_SYM, /covlmgr not found/)

      bullseye.report_license_status()
    end
  end

  ##
  ## Per-function coverage report
  ##

  describe '#report_per_function_coverage_results' do
    let(:configurator) { double('configurator', cmock_mock_prefix: 'mock_') }

    def build_covfn_bullseye(sources, output)
      test_invoker = double('test_invoker')
      allow(test_invoker).to receive(:each_test_with_sources).and_yield('test_a', sources)
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: output })

      build_bullseye({}, configurator: configurator, test_invoker: test_invoker)
    end

    it 'runs covfn once per covered source' do
      bullseye = build_covfn_bullseye(['src/a.c', 'src/b.c'], "banner\nline\nDETAIL\n")

      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVFN, [], 'src/a.c').and_return({})
      expect(tool_executor).to receive(:build_command_line)
        .with(TOOLS_BULLSEYE_REPORT_COVFN, [], 'src/b.c').and_return({})

      bullseye.send(:report_per_function_coverage_results)
    end

    it 'skips mocks and framework sources' do
      bullseye = build_covfn_bullseye(['src/a.c', 'build/mocks/mock_a.c', 'vendor/unity.c'], "banner\nline\nDETAIL\n")

      expect(tool_executor).to receive(:build_command_line).once
        .with(TOOLS_BULLSEYE_REPORT_COVFN, [], 'src/a.c').and_return({})

      bullseye.send(:report_per_function_coverage_results)
    end

    it 'reports a source carrying no coverage data rather than printing the raw warning' do
      bullseye = build_covfn_bullseye(['src/a.c'], "banner\nline\nwarning cov814: report is empty\n")

      expect(loginator).to receive(:log).with(/src\/a\.c contains no coverage data/, Verbosity::COMPLAIN)

      bullseye.send(:report_per_function_coverage_results)
    end

    it 'de-duplicates a source referenced by more than one test' do
      test_invoker = double('test_invoker')
      allow(test_invoker).to receive(:each_test_with_sources)
        .and_yield('test_a', ['src/a.c']).and_yield('test_b', ['src/a.c'])
      allow(tool_executor).to receive(:exec).and_return({ output: "banner\nline\nDETAIL\n" })
      bullseye = build_bullseye({}, configurator: configurator, test_invoker: test_invoker)

      expect(tool_executor).to receive(:build_command_line).once.and_return({})

      bullseye.send(:report_per_function_coverage_results)
    end
  end

  ##
  ## Standalone summary
  ##

  describe '#summary' do
    let(:configurator) { double('configurator', plugins_display_raw_test_results: false) }

    def build_summary_bullseye(project_config, exists: true)
      services = ceedling.merge(
        :file_path_utils => double('file_path_utils', form_pass_results_filelist: ['a.pass'])
      )
      allow(plugin_reportinator).to receive(:assemble_test_results).and_return({})
      allow(plugin_reportinator).to receive(:run_test_results_report)

      build_bullseye(
        project_config,
        ceedling: services, configurator: configurator,
        file_wrapper: double('file_wrapper', exist?: exists)
      )
    end

    it 'does nothing when there is no coverage file' do
      bullseye = build_summary_bullseye({}, exists: false)

      expect(plugin_reportinator).to_not receive(:run_test_results_report)

      bullseye.summary()
    end

    it 'reports test results and coverage totals when summaries are enabled' do
      bullseye = build_summary_bullseye({ bullseye_summaries: true })

      expect(plugin_reportinator).to receive(:run_test_results_report)
      expect(bullseye).to receive(:collect_coverage_totals).and_return({ functions: 50, branches: 8 })
      expect(bullseye).to receive(:report_coverage_results_all).with({ functions: 50, branches: 8 })

      bullseye.summary()
    end

    it 'reports test results but no coverage totals when summaries are disabled' do
      bullseye = build_summary_bullseye({ bullseye_summaries: false })

      expect(plugin_reportinator).to receive(:run_test_results_report)
      expect(bullseye).to_not receive(:collect_coverage_totals)

      bullseye.summary()
    end
  end

  ##
  ## Report exclusions
  ##

  describe '#apply_report_exclusions' do
    it 'registers one covselect exclusion per framework source, test prefix, and mock prefix' do
      configurator = double('configurator', project_test_file_prefix: 'test_', cmock_mock_prefix: 'mock_')
      bullseye = build_bullseye({}, configurator: configurator)

      patterns = []
      allow(tool_executor).to receive(:build_command_line) do |_tool, _params, pattern|
        patterns << pattern
        { options: {} }
      end
      allow(tool_executor).to receive(:exec)

      bullseye.send(:apply_report_exclusions)

      expect(patterns).to include('!**/unity.c', '!**/cmock.c', '!**/cexception.c')
      expect(patterns).to include('!**/test_*.c')
      expect(patterns).to include('!**/mock_*.c')
    end

    it 'never lets a covselect failure end the build' do
      configurator = double('configurator', project_test_file_prefix: 'test_', cmock_mock_prefix: 'mock_')
      bullseye = build_bullseye({}, configurator: configurator)

      commands = []
      allow(tool_executor).to receive(:build_command_line) do
        command = { options: {} }
        commands << command
        command
      end
      allow(tool_executor).to receive(:exec)

      bullseye.send(:apply_report_exclusions)

      expect(commands).to_not be_empty
      expect(commands.all? { |command| command[:options][:boom] == false }).to be true
    end
  end

  ##
  ## Coverage file verification
  ##

  describe '#verify_coverage_file' do
    it 'returns true when the coverage file exists' do
      bullseye = build_bullseye({}, file_wrapper: double('file_wrapper', exist?: true))

      expect(bullseye.send(:verify_coverage_file)).to be true
    end

    it 'returns false and logs a banner when the coverage file is missing' do
      bullseye = build_bullseye({}, file_wrapper: double('file_wrapper', exist?: false))

      expect(loginator).to receive(:log).with(/No coverage file/)

      expect(bullseye.send(:verify_coverage_file)).to be false
    end
  end

  ##
  ## Untested source processing
  ##

  describe '#process_untested_sources' do
    let(:file_path_utils) { double('file_path_utils') }
    let(:configurator)    { double('configurator', collection_paths_include: []) }
    let(:defineinator)    { double('defineinator', defines: []) }
    let(:flaginator)      { double('flaginator', flag_down: []) }
    let(:dependinator)    { double('dependinator', register: nil, register_gcc_deps_file: nil, flush: nil, mark_fresh: nil) }
    let(:generator)       { double('generator', generate_object_file_c: nil) }
    let(:test_invoker)    { double('test_invoker') }

    def build_process_bullseye(project_config, ivars = {})
      allow(test_invoker).to receive(:each_test_with_sources)
      services = ceedling.merge(
        :file_path_utils => file_path_utils,
        :defineinator    => defineinator,
        :flaginator      => flaginator,
        :dependinator    => dependinator,
        :generator       => generator
      )
      build_bullseye(
        project_config,
        {
          ceedling:     services,
          configurator: configurator,
          test_invoker: test_invoker,
          file_wrapper: double('file_wrapper', exist?: false)
        }.merge(ivars)
      )
    end

    context ':ignore mode' do
      it 'has zero side effects' do
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_IGNORE })

        expect(loginator).to_not receive(:log)
        expect(dependinator).to_not receive(:register)

        bullseye.process_untested_sources(sources: ['src/a.c'])
      end
    end

    context ':list mode' do
      it 'logs that there is nothing to process when every source is tested' do
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_LIST })

        expect(loginator).to receive(:log).with(/No untested sources/)
        expect(loginator).to_not receive(:log_list)

        bullseye.process_untested_sources(sources: [])
      end

      it 'logs the sorted untested filepath list without compiling' do
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_LIST })

        expect(loginator).to receive(:log_list)
          .with(['src/a.c', 'src/b.c'], kind_of(String), Verbosity::COMPLAIN, LogLabels::WARNING)
        expect(generator).to_not receive(:generate_object_file_c)

        bullseye.process_untested_sources(sources: ['src/b.c', 'src/a.c'])
      end
    end

    context ':compile mode' do
      before do
        allow(file_path_utils).to receive(:form_test_object_filepath).and_return('build/bullseye/out/src/a.o')
        allow(file_path_utils).to receive(:form_test_dependencies_filepath).and_return('build/bullseye/out/src/a.d')
      end

      it 'never calls the generator when there is nothing untested' do
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_COMPILE })

        expect(generator).to_not receive(:generate_object_file_c)
        expect(dependinator).to_not receive(:flush)

        bullseye.process_untested_sources(sources: [])
      end

      it 'skips compilation for an already-fresh object' do
        allow(dependinator).to receive(:stale?).and_return(false)
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_COMPILE })

        expect(generator).to_not receive(:generate_object_file_c)
        expect(dependinator).to_not receive(:mark_fresh)

        bullseye.process_untested_sources(sources: ['src/a.c'])
      end

      it 'compiles a stale object with the Bullseye compiler and marks it fresh' do
        allow(dependinator).to receive(:stale?).and_return(true)
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_COMPILE })

        expect(generator).to receive(:generate_object_file_c)
          .with(hash_including(tool: TOOLS_BULLSEYE_COMPILER, context: BULLSEYE_SYM, source: 'src/a.c'))
        expect(dependinator).to receive(:mark_fresh)

        bullseye.process_untested_sources(sources: ['src/a.c'])
      end

      it 'logs remediation guidance and re-raises when compilation fails with guidance enabled' do
        allow(dependinator).to receive(:stale?).and_return(true)
        allow(generator).to receive(:generate_object_file_c).and_raise(ShellException.new(name: 'covc', message: 'compile failed'))
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_COMPILE })

        expect(loginator).to receive(:log).with(/OPTIONS:/, Verbosity::COMPLAIN, LogLabels::NOTICE)

        expect {
          bullseye.process_untested_sources(sources: ['src/a.c'])
        }.to raise_error(ShellException)
      end

      it 'stays silent and still re-raises when compilation fails with guidance disabled' do
        allow(dependinator).to receive(:stale?).and_return(true)
        allow(generator).to receive(:generate_object_file_c).and_raise(ShellException.new(name: 'covc', message: 'compile failed'))
        bullseye = build_process_bullseye({ bullseye_untested_sources: BULLSEYE_UNTESTED_SOURCES_COMPILE })

        expect(loginator).to_not receive(:log).with(/OPTIONS:/, anything, anything)

        expect {
          bullseye.process_untested_sources(sources: ['src/a.c'], guidance: false)
        }.to raise_error(ShellException)
      end
    end
  end

  ##
  ## post_build orchestration
  ##

  describe '#post_build' do
    let(:configurator) { double('configurator', plugins_display_raw_test_results: true) }

    def build_post_build_bullseye(project_config, ivars = {})
      build_bullseye(
        project_config,
        {
          cli_bullseye_task: true,
          configurator:      configurator,
          result_list:       [],
          file_wrapper:      double('file_wrapper', exist?: true, mkdir: nil)
        }.merge(ivars)
      )
    end

    it 'does nothing when no bullseye task was invoked' do
      bullseye = build_bullseye({}, cli_bullseye_task: false, configurator: configurator)

      expect(configurator).to_not receive(:plugins_display_raw_test_results)

      bullseye.post_build(0)
    end

    it 'runs the plugin test-results report when no other plugin displays raw results' do
      quiet_configurator = double('configurator', plugins_display_raw_test_results: false)
      bullseye = build_post_build_bullseye(
        { bullseye_summaries: false, bullseye_report_task: true },
        configurator: quiet_configurator
      )

      allow(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_branch_coverage_results)
      allow(plugin_reportinator).to receive(:test_results_floor_verbosity).and_return(Verbosity::ERRORS)
      expect(plugin_reportinator).to receive(:assemble_test_results).with([]).and_return({})
      expect(plugin_reportinator).to receive(:run_test_results_report)
        .with({ context: BULLSEYE_SYM, results: {} }, Verbosity::ERRORS)

      bullseye.post_build(0)
    end

    it 'skips the plugin test-results report when another plugin displays raw results' do
      bullseye = build_post_build_bullseye({ bullseye_summaries: false, bullseye_report_task: true })

      allow(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_branch_coverage_results)
      expect(plugin_reportinator).to_not receive(:assemble_test_results)

      bullseye.post_build(0)
    end

    it 'stops after the test results report when the coverage file is missing' do
      bullseye = build_post_build_bullseye(
        { bullseye_summaries: false, bullseye_report_task: true },
        file_wrapper: double('file_wrapper', exist?: false)
      )

      expect(bullseye).to_not receive(:apply_report_exclusions)

      bullseye.post_build(0)
    end

    it 'applies report exclusions even when summaries are disabled' do
      bullseye = build_post_build_bullseye({ bullseye_summaries: false, bullseye_report_task: true })

      expect(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_branch_coverage_results)

      bullseye.post_build(0)
    end

    it 'collects totals once and feeds both the summary and the threshold gate' do
      bullseye = build_post_build_bullseye({
        bullseye_summaries:  true,
        bullseye_report_task: true,
        bullseye_fail_under: { functions: 90, branches: 0 }
      })

      allow(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_per_function_coverage_results)
      allow(bullseye).to receive(:report_branch_coverage_results)
      expect(bullseye).to receive(:collect_coverage_totals).once.and_return({ functions: 50, branches: 8 })
      expect(bullseye).to receive(:report_coverage_results_all).with({ functions: 50, branches: 8 })

      expect(plugin_manager).to receive(:register_build_failure).with(BULLSEYE_SYM, /Function coverage 50%/)

      bullseye.post_build(0)
    end

    it 'never collects totals when summaries are off and no threshold is configured' do
      bullseye = build_post_build_bullseye({ bullseye_summaries: false, bullseye_report_task: true })

      allow(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_branch_coverage_results)
      expect(bullseye).to_not receive(:collect_coverage_totals)

      bullseye.post_build(0)
    end

    it 'generates both reports when automatic reporting is enabled' do
      bullseye = build_post_build_bullseye({ bullseye_summaries: false, bullseye_report_task: false })

      allow(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_branch_coverage_results)
      expect(bullseye).to receive(:generate_html_report)
      expect(bullseye).to receive(:generate_xml_report)

      bullseye.post_build(0)
    end

    it 'generates no reports when a dedicated report task is configured' do
      bullseye = build_post_build_bullseye({ bullseye_summaries: false, bullseye_report_task: true })

      allow(bullseye).to receive(:apply_report_exclusions)
      allow(bullseye).to receive(:report_branch_coverage_results)
      expect(bullseye).to_not receive(:generate_html_report)
      expect(bullseye).to_not receive(:generate_xml_report)

      bullseye.post_build(0)
    end
  end
end
