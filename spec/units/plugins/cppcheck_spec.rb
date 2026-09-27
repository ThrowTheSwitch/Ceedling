# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rake'
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/plugins/plugin'

# Define Ceedling runtime path constants needed by cppcheck_constants.rb at
# require time.  The `unless defined?` guard keeps them from being re-assigned
# if another spec already loaded them.
PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/cppcheck/lib', __FILE__)

require 'cppcheck_constants'
require 'cppcheck_reports'
require 'cppcheck'
require 'ceedling/ruby_expandinator'

# The END block at the bottom of cppcheck.rb runs after RSpec finishes and
# accesses the top-level @ceedling variable.  Set a minimal stub so it does
# not raise a NoMethodError and pollute the exit code.
_task_invoker_stub = Object.new
def _task_invoker_stub.invoked?(_); false; end
@ceedling = { task_invoker: _task_invoker_stub }

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

# Build a Cppcheck instance without running Plugin#initialize / setup so that
# unit tests can exercise individual private methods in isolation.
def build_cppcheck(config:, loginator: nil, system_wrapper: nil,
                   file_wrapper: nil, file_path_collection_utils: nil, ruby_expandinator: nil)
  instance = Cppcheck.allocate
  instance.instance_variable_set(:@config,                    config)
  instance.instance_variable_set(:@loginator,                 loginator)
  instance.instance_variable_set(:@system_wrapper,            system_wrapper)
  instance.instance_variable_set(:@file_wrapper,              file_wrapper)
  instance.instance_variable_set(:@file_path_collection_utils, file_path_collection_utils)
  instance.instance_variable_set(:@ruby_expandinator,         ruby_expandinator)
  instance
end

# Build a system-objects hash suitable for passing to report constructors.
def build_system_objects(loginator: nil, tool_executor: nil, tool_validator: nil,
                         file_wrapper: nil)
  {
    loginator:      loginator,
    tool_executor:  tool_executor,
    tool_validator: tool_validator,
    file_wrapper:   file_wrapper,
  }
end

# ===========================================================================
describe Cppcheck do
  let(:loginator)                  { double('loginator', log: nil, lazy: nil) }
  let(:system_wrapper)             { double('system_wrapper') }
  let(:file_wrapper)               { double('file_wrapper') }
  let(:file_path_collection_utils) { double('file_path_collection_utils') }
  # Default pass-through stub mirrors RubyExpandinator#expand's real behavior for
  # strings without a `#{...}` pattern. Individual tests override with a tighter
  # `.with(...)` expectation where expansion matters.
  let(:ruby_expandinator) do
    d = double('ruby_expandinator')
    allow(d).to receive(:expand) { |s, source:| s }
    d
  end

  # Stub the two runtime constants that come from Ceedling's configurator.
  before(:each) do
    stub_const('COLLECTION_ALL_CPPCHECK', [])
    stub_const('CPPCHECK_BUILD_PATH', 'build/cppcheck')
  end

  # -------------------------------------------------------------------------
  describe '#build_common_opts' do
    it 'returns an empty array when no optional settings are configured' do
      cppcheck = build_cppcheck(config: {})
      expect(cppcheck.send(:build_common_opts)).to eq([])
    end

    it 'adds --platform flag when configured' do
      cppcheck = build_cppcheck(config: { platform: 'unix64' })
      expect(cppcheck.send(:build_common_opts)).to include('--platform=unix64')
    end

    it 'omits --platform when value is nil' do
      cppcheck = build_cppcheck(config: { platform: nil })
      expect(cppcheck.send(:build_common_opts)).not_to include(a_string_starting_with('--platform'))
    end

    it 'omits --platform when value is empty' do
      cppcheck = build_cppcheck(config: { platform: '' })
      expect(cppcheck.send(:build_common_opts)).not_to include(a_string_starting_with('--platform'))
    end

    it 'adds --template flag when configured' do
      cppcheck = build_cppcheck(config: { template: '{file}:{line}: {message}' })
      expect(cppcheck.send(:build_common_opts)).to include('--template={file}:{line}: {message}')
    end

    it 'adds --std flag when configured' do
      cppcheck = build_cppcheck(config: { standard: 'c11' })
      expect(cppcheck.send(:build_common_opts)).to include('--std=c11')
    end

    it 'adds --inline-suppr when inline_suppressions is true' do
      cppcheck = build_cppcheck(config: { inline_suppressions: true })
      expect(cppcheck.send(:build_common_opts)).to include('--inline-suppr')
    end

    it 'omits --inline-suppr when inline_suppressions is false' do
      cppcheck = build_cppcheck(config: { inline_suppressions: false })
      expect(cppcheck.send(:build_common_opts)).not_to include('--inline-suppr')
    end

    it 'omits --inline-suppr when inline_suppressions is nil' do
      cppcheck = build_cppcheck(config: { inline_suppressions: nil })
      expect(cppcheck.send(:build_common_opts)).not_to include('--inline-suppr')
    end

    it 'adds --check-level flag when configured' do
      cppcheck = build_cppcheck(config: { check_level: 'exhaustive' })
      expect(cppcheck.send(:build_common_opts)).to include('--check-level=exhaustive')
    end

    it 'joins multiple disable_checks with commas into a single --disable flag' do
      cppcheck = build_cppcheck(config: { disable_checks: ['style', 'performance'] })
      expect(cppcheck.send(:build_common_opts)).to include('--disable=style,performance')
    end

    it 'adds one --addon flag per addon' do
      cppcheck = build_cppcheck(config: { addons: ['misra', 'cert'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('--addon=misra', '--addon=cert')
    end

    it 'adds one --include flag per include' do
      cppcheck = build_cppcheck(config: { includes: ['defs.h', 'config.h'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('--include=defs.h', '--include=config.h')
    end

    it 'adds one -i flag per exclude path' do
      cppcheck = build_cppcheck(config: { excludes: ['vendor/', 'generated/'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('-ivendor/', '-igenerated/')
    end

    it 'adds one --library flag per library' do
      cppcheck = build_cppcheck(config: { libraries: ['gnu', 'posix'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('--library=gnu', '--library=posix')
    end

    it 'adds one --rule flag per rule' do
      cppcheck = build_cppcheck(config: { rules: ['.*'] })
      expect(cppcheck.send(:build_common_opts)).to include('--rule=.*')
    end

    it 'adds one --suppress flag per suppression string' do
      cppcheck = build_cppcheck(config: { suppressions: ['unusedVariable', 'uninitvar:foo.c'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('--suppress=unusedVariable', '--suppress=uninitvar:foo.c')
    end

    it 'adds one -D flag per define' do
      cppcheck = build_cppcheck(config: { defines: ['DEBUG', 'VERSION=1'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('-DDEBUG', '-DVERSION=1')
    end

    it 'adds one -U flag per undefine' do
      cppcheck = build_cppcheck(config: { undefines: ['NDEBUG'] })
      expect(cppcheck.send(:build_common_opts)).to include('-UNDEBUG')
    end

    it 'passes each option in :options through verbatim' do
      cppcheck = build_cppcheck(config: { options: ['--max-configs=10', '--verbose'] })
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('--max-configs=10', '--verbose')
    end

    it 'uses --suppress-xml for .xml suppression files' do
      stub_const('COLLECTION_ALL_CPPCHECK', ['suppress/rules.xml'])
      cppcheck = build_cppcheck(config: {})
      expect(cppcheck.send(:build_common_opts)).to include('--suppress-xml=suppress/rules.xml')
    end

    it 'uses --suppressions-list for non-xml suppression files' do
      stub_const('COLLECTION_ALL_CPPCHECK', ['suppress/suppressions.txt'])
      cppcheck = build_cppcheck(config: {})
      expect(cppcheck.send(:build_common_opts)).to include('--suppressions-list=suppress/suppressions.txt')
    end

    it 'handles a mix of xml and non-xml suppression files' do
      stub_const('COLLECTION_ALL_CPPCHECK', ['rules.xml', 'list.txt'])
      cppcheck = build_cppcheck(config: {})
      opts = cppcheck.send(:build_common_opts)
      expect(opts).to include('--suppress-xml=rules.xml', '--suppressions-list=list.txt')
    end
  end

  # -------------------------------------------------------------------------
  describe '#build_project_opts' do
    it 'always includes --cppcheck-build-dir and --enable=all' do
      cppcheck = build_cppcheck(config: {})
      opts = cppcheck.send(:build_project_opts)
      expect(opts).to include('--cppcheck-build-dir=build/cppcheck', '--enable=all')
    end

    it 'adds --project flag when project is configured' do
      cppcheck = build_cppcheck(config: { project: 'compile_commands.json' })
      expect(cppcheck.send(:build_project_opts)).to include('--project=compile_commands.json')
    end

    it 'omits --project flag when project is nil' do
      cppcheck = build_cppcheck(config: { project: nil })
      expect(cppcheck.send(:build_project_opts)).not_to include(a_string_starting_with('--project'))
    end

    it 'omits --project flag when project is empty' do
      cppcheck = build_cppcheck(config: { project: '' })
      expect(cppcheck.send(:build_project_opts)).not_to include(a_string_starting_with('--project'))
    end

    it 'includes all common opts' do
      cppcheck = build_cppcheck(config: { platform: 'win64', standard: 'c99' })
      opts = cppcheck.send(:build_project_opts)
      expect(opts).to include('--platform=win64', '--std=c99')
    end
  end

  # -------------------------------------------------------------------------
  describe '#build_file_opts' do
    it 'adds --enable flag when enable_checks is configured' do
      cppcheck = build_cppcheck(config: { enable_checks: ['style', 'warning'] })
      expect(cppcheck.send(:build_file_opts)).to include('--enable=style,warning')
    end

    it 'omits --enable flag when enable_checks is nil' do
      cppcheck = build_cppcheck(config: { enable_checks: nil })
      expect(cppcheck.send(:build_file_opts)).not_to include(a_string_starting_with('--enable'))
    end

    it 'omits --enable flag when enable_checks is empty' do
      cppcheck = build_cppcheck(config: { enable_checks: [] })
      expect(cppcheck.send(:build_file_opts)).not_to include(a_string_starting_with('--enable'))
    end

    it 'includes all common opts' do
      cppcheck = build_cppcheck(config: { standard: 'c11', enable_checks: ['warning'] })
      opts = cppcheck.send(:build_file_opts)
      expect(opts).to include('--std=c11', '--enable=warning')
    end
  end

  # -------------------------------------------------------------------------
  describe '#traverse_config_eval_strings' do
    it 'replaces Ruby interpolation patterns in a string via ruby_expandinator' do
      allow(ruby_expandinator).to receive(:expand)
        .with('#{ENV["HOME"]}', source: 'cppcheck plugin configuration')
        .and_return('/home/user')
      cppcheck = build_cppcheck(config: {}, ruby_expandinator: ruby_expandinator)
      value = '#{ENV["HOME"]}'
      cppcheck.send(:traverse_config_eval_strings, value)
      expect(value).to eq('/home/user')
    end

    it 'leaves a plain string unchanged' do
      cppcheck = build_cppcheck(config: {}, ruby_expandinator: ruby_expandinator)
      value = 'no interpolation here'
      cppcheck.send(:traverse_config_eval_strings, value)
      expect(value).to eq('no interpolation here')
    end

    it 'evaluates strings with interpolation patterns in an array' do
      allow(ruby_expandinator).to receive(:expand)
        .with('#{foo}', source: 'cppcheck plugin configuration')
        .and_return('evaluated')
      cppcheck = build_cppcheck(config: {}, ruby_expandinator: ruby_expandinator)
      arr = ['plain', '#{foo}']
      cppcheck.send(:traverse_config_eval_strings, arr)
      expect(arr).to eq(['plain', 'evaluated'])
    end

    it 'recurses into hash values' do
      allow(ruby_expandinator).to receive(:expand)
        .with('#{bar}', source: 'cppcheck plugin configuration')
        .and_return('result')
      cppcheck = build_cppcheck(config: {}, ruby_expandinator: ruby_expandinator)
      config = { key: '#{bar}' }
      cppcheck.send(:traverse_config_eval_strings, config)
      expect(config[:key]).to eq('result')
    end

    it 'does not call expand on non-string array elements' do
      expect(ruby_expandinator).not_to receive(:expand)
      cppcheck = build_cppcheck(config: {}, ruby_expandinator: ruby_expandinator)
      cppcheck.send(:traverse_config_eval_strings, [1, 2, :sym])
    end

    it 'raises CeedlingException when a value contains inline Ruby and the feature is disabled' do
      real_ruby_expandinator = RubyExpandinator.new # disabled by default
      cppcheck = build_cppcheck(config: {}, ruby_expandinator: real_ruby_expandinator)

      expect {
        cppcheck.send(:traverse_config_eval_strings, '#{1+1}')
      }.to raise_error(CeedlingException, /cppcheck/)
    end
  end

  # -------------------------------------------------------------------------
  describe '#collect_suppressions' do
    let(:file_list) { double('file_list') }

    before(:each) do
      allow(file_wrapper).to receive(:instantiate_file_list).and_return(file_list)
      allow(file_path_collection_utils).to receive(:revise_filelist).and_return(file_list)
    end

    it 'includes a file path directly when it is not a directory' do
      allow(file_wrapper).to receive(:exist?).with('suppress/rules.xml').and_return(true)
      allow(file_wrapper).to receive(:directory?).with('suppress/rules.xml').and_return(false)
      expect(file_list).to receive(:include).with('suppress/rules.xml')

      cppcheck = build_cppcheck(
        config: {},
        file_wrapper: file_wrapper,
        file_path_collection_utils: file_path_collection_utils
      )
      cppcheck.send(:collect_suppressions, {
        collection_paths_cppcheck: ['suppress/rules.xml'],
        files_cppcheck: [],
        extension_cppcheck: '.xml'
      })
    end

    it 'adds xml and extension glob patterns when path is a directory' do
      allow(file_wrapper).to receive(:exist?).with('suppress/').and_return(true)
      allow(file_wrapper).to receive(:directory?).with('suppress/').and_return(true)
      expect(file_list).to receive(:include).with('suppress/*.xml')
      expect(file_list).to receive(:include).with('suppress/*.txt')

      cppcheck = build_cppcheck(
        config: {},
        file_wrapper: file_wrapper,
        file_path_collection_utils: file_path_collection_utils
      )
      cppcheck.send(:collect_suppressions, {
        collection_paths_cppcheck: ['suppress/'],
        files_cppcheck: [],
        extension_cppcheck: '.txt'
      })
    end

    it 'adds xml and extension glob patterns when path does not exist, and warns' do
      allow(file_wrapper).to receive(:exist?).with('missing/').and_return(false)
      expect(file_list).to receive(:include).with('missing/*.xml')
      expect(file_list).to receive(:include).with('missing/*.cfg')
      # A nonexistent path globs to nothing. Without the warning a typo looks exactly
      # like a directory holding no suppression files.
      expect(loginator).to receive(:log).with(/'missing\/' does not exist/, anything, anything)

      cppcheck = build_cppcheck(
        config: {},
        file_wrapper: file_wrapper,
        file_path_collection_utils: file_path_collection_utils,
        loginator: loginator
      )
      cppcheck.send(:collect_suppressions, {
        collection_paths_cppcheck: ['missing/'],
        files_cppcheck: [],
        extension_cppcheck: '.cfg'
      })
    end

    it 'returns a hash with :collection_all_cppcheck key' do
      allow(file_wrapper).to receive(:exist?).and_return(false)
      allow(file_list).to receive(:include)

      cppcheck = build_cppcheck(
        config: {},
        file_wrapper: file_wrapper,
        file_path_collection_utils: file_path_collection_utils
      )
      result = cppcheck.send(:collect_suppressions, {
        collection_paths_cppcheck: [],
        files_cppcheck: [],
        extension_cppcheck: '.xml'
      })
      expect(result).to have_key(:collection_all_cppcheck)
    end
  end

  # -------------------------------------------------------------------------
  describe '#validate_environment!' do
    it 'validates the Cppcheck tool' do
      stub_const('TOOLS_CPPCHECK', { executable: 'cppcheck' })
      tool_validator = double('tool_validator')
      cppcheck = build_cppcheck(config: {})
      cppcheck.instance_variable_set(:@tool_validator, tool_validator)

      expect(tool_validator).to receive(:validate).with(
        tool: { executable: 'cppcheck' }, boom: true
      )

      cppcheck.validate_environment!
    end
  end

  # -------------------------------------------------------------------------
  describe '#validate_fail_build_severities' do
    it 'accepts every severity Cppcheck reports' do
      cppcheck = build_cppcheck(config: { fail_build_severities: CPPCHECK_SEVERITIES })

      expect { cppcheck.send(:validate_fail_build_severities) }.to_not raise_error
    end

    it 'accepts an empty list' do
      cppcheck = build_cppcheck(config: {})

      expect { cppcheck.send(:validate_fail_build_severities) }.to_not raise_error
    end

    # An unrecognized severity would otherwise silently never match a finding.
    it 'raises CeedlingException naming the bad value and listing valid severities' do
      cppcheck = build_cppcheck(config: { fail_build_severities: ['error', 'bogus'] })

      expect { cppcheck.send(:validate_fail_build_severities) }.to raise_error(
        CeedlingException, /bogus.*'error'.*'warning'.*'information'/m
      )
    end
  end

  # -------------------------------------------------------------------------
  describe '#tally_findings' do
    def build_tally(contents, exists: true)
      wrapper = double('file_wrapper', exist?: exists, read: contents)
      build_cppcheck(config: {}, file_wrapper: wrapper, loginator: loginator)
    end

    it 'counts findings by severity attribute' do
      xml = '<results><errors>' \
            '<error id="a" severity="error" msg="x"></error>' \
            '<error id="b" severity="style" msg="y"></error>' \
            '<error id="c" severity="style" msg="z"></error>' \
            '</errors></results>'

      expect(build_tally(xml).send(:tally_findings, 'r.xml')).to eq({ 'error' => 1, 'style' => 2 })
    end

    it 'returns an empty tally for a report with no findings' do
      xml = '<results><errors></errors></results>'

      expect(build_tally(xml).send(:tally_findings, 'r.xml')).to eq({})
    end

    it 'warns and returns nil when no report was written' do
      cppcheck = build_tally('', exists: false)

      expect(loginator).to receive(:log).with(/wrote no XML report/, anything, anything)
      expect(cppcheck.send(:tally_findings, 'r.xml')).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  describe '#report_findings' do
    def build_reporter(config, contents)
      wrapper = double('file_wrapper', exist?: true, read: contents)
      build_cppcheck(config: config, file_wrapper: wrapper, loginator: loginator)
    end

    let(:xml_report) { double('xml_report', artifact_filepath: 'r.xml') }
    let(:one_error)  { '<error id="a" severity="error" msg="x"></error>' }

    it 'does nothing without an XML report' do
      cppcheck = build_reporter({}, '')

      expect(loginator).to_not receive(:log)

      cppcheck.send(:report_findings, nil)
    end

    it 'reports that nothing was found for an empty tally' do
      cppcheck = build_reporter({}, '<results/>')

      expect(loginator).to receive(:log).with(/found no issues/, anything)

      cppcheck.send(:report_findings, xml_report)
    end

    it 'summarizes findings by severity' do
      cppcheck = build_reporter({}, one_error)

      expect(loginator).to receive(:log).with(/findings: 1 error/, anything)

      cppcheck.send(:report_findings, xml_report)
    end

    it 'raises naming the matching severities when :fail_build is enabled' do
      cppcheck = build_reporter({ fail_build: true, fail_build_severities: ['error'] }, one_error)

      expect { cppcheck.send(:report_findings, xml_report) }.to raise_error(
        CeedlingException, /1 finding matching.*1 error/m
      )
    end

    it 'does not raise when findings fall outside the configured severities' do
      cppcheck = build_reporter({ fail_build: true, fail_build_severities: ['portability'] }, one_error)

      expect { cppcheck.send(:report_findings, xml_report) }.to_not raise_error
    end

    it 'does not raise when :fail_build is disabled' do
      cppcheck = build_reporter({ fail_build: false, fail_build_severities: ['error'] }, one_error)

      expect { cppcheck.send(:report_findings, xml_report) }.to_not raise_error
    end
  end

  # -------------------------------------------------------------------------
  describe '#build_reports' do
    before(:each) do
      stub_const('CPPCHECK_ARTIFACTS_PATH', 'artifacts/cppcheck')
      stub_const('CPPCHECK_ARTIFACTS_FILE_XML', 'CppcheckReport.xml')
      stub_const('CPPCHECK_ARTIFACTS_FILE_TEXT', 'CppcheckReport.txt')
    end

    def build_lazy(config)
      cppcheck = build_cppcheck(config: config, loginator: loginator)
      cppcheck.instance_variable_set(:@reports, nil)
      # Report constructors receive this hash and pull their own collaborators from it.
      cppcheck.instance_variable_set(:@ceedling, build_system_objects(
        loginator:      loginator,
        tool_executor:  double('tool_executor'),
        tool_validator: double('tool_validator', validate: nil),
        file_wrapper:   double('file_wrapper')
      ))
      cppcheck
    end

    it 'builds nothing when no report is configured' do
      expect(build_lazy({ reports: [] }).send(:build_reports)).to eq({})
    end

    it 'builds the configured report types' do
      reports = build_lazy({ reports: ['text'] }).send(:build_reports)

      expect(reports.keys).to eq([:text])
    end

    it 'memoizes so reports are constructed once' do
      cppcheck = build_lazy({ reports: ['text'] })

      expect(cppcheck.send(:build_reports)).to be(cppcheck.send(:build_reports))
    end

    # Findings are counted from Cppcheck's own XML, so :fail_build needs that report
    # to exist. This mirrors how :html already implies :xml.
    it 'implies an XML report when :fail_build is enabled' do
      reports = build_lazy({ reports: ['text'], fail_build: true }).send(:build_reports)

      expect(reports.keys).to include(:xml)
    end

    it 'does not duplicate an XML report already requested' do
      reports = build_lazy({ reports: ['xml'], fail_build: true }).send(:build_reports)

      expect(reports.keys).to eq([:xml])
    end

    # HTML needs the XML artifact as its own input, so requesting it implies XML.
    it 'implies an XML report when HTML is requested' do
      stub_const('TOOLS_CPPCHECK_HTMLREPORT', { executable: 'cppcheck-htmlreport' })
      stub_const('CPPCHECK_ARTIFACTS_HTML_PATH', 'artifacts/cppcheck/html')

      reports = build_lazy({ reports: ['html'] }).send(:build_reports)

      expect(reports.keys).to include(:xml, :html)
    end
  end

  # -------------------------------------------------------------------------
  describe '#new_report' do
    it 'logs an error and returns nil for an unrecognized report type' do
      cppcheck = build_cppcheck(config: {}, loginator: loginator)

      expect(loginator).to receive(:log).with(/'bogus' is not supported/, anything)
      expect(cppcheck.send(:new_report, :bogus)).to be_nil
    end
  end

  # -------------------------------------------------------------------------
  describe '#generate_reports' do
    before(:each) do
      stub_const('COLLECTION_PATHS_INCLUDE', ['src'])
      stub_const('COLLECTION_PATHS_SOURCE', ['src'])
    end

    def build_generator(config, reports)
      cppcheck = build_cppcheck(config: config, loginator: loginator)
      cppcheck.instance_variable_set(:@reports, reports)
      cppcheck
    end

    # Cppcheck only runs as part of generating a report. With no report configured
    # this task analyzed nothing and said nothing, which reads like a clean run.
    it 'warns and runs nothing when no report is configured' do
      cppcheck = build_generator({ reports: [], project: nil }, {})

      expect(loginator).to receive(:log).with(/No Cppcheck reports are configured/, anything, anything)

      cppcheck.generate_reports()
    end

    it 'generates each configured report' do
      report = double('report', generate: nil, artifact_filepath: 'r.txt')
      cppcheck = build_generator({ reports: ['text'], project: nil }, { text: report })

      expect(report).to receive(:generate)

      cppcheck.generate_reports()
    end

    # cppcheck-htmlreport consumes the XML artifact, so XML has to be written first.
    it 'generates the XML report before the HTML report' do
      order = []
      xml  = double('xml',  artifact_filepath: 'r.xml')
      html = double('html', artifact_filepath: 'html')
      allow(xml).to receive(:generate)  { order << :xml }
      allow(html).to receive(:generate) { order << :html }

      cppcheck = build_generator({ reports: ['html'], project: nil }, { html: html, xml: xml })
      allow(cppcheck).to receive(:report_findings)

      cppcheck.generate_reports()

      expect(order).to eq([:xml, :html])
    end

    # :project hands source and include discovery to Cppcheck itself.
    it 'passes no Ceedling source or include paths when :project is configured' do
      report = double('report', artifact_filepath: 'r.txt')
      cppcheck = build_generator({ reports: ['text'], project: 'compile_commands.json' }, { text: report })

      expect(report).to receive(:generate).with(anything, [], [])

      cppcheck.generate_reports()
    end

    it 'passes Ceedling source and include paths when :project is not configured' do
      report = double('report', artifact_filepath: 'r.txt')
      cppcheck = build_generator({ reports: ['text'], project: nil }, { text: report })

      expect(report).to receive(:generate).with(anything, ['src'], ['src'])

      cppcheck.generate_reports()
    end
  end

  # -------------------------------------------------------------------------
  describe '#analyze_file' do
    before(:each) { stub_const('COLLECTION_PATHS_INCLUDE', ['src']) }

    it 'runs Cppcheck against the single file and logs its output' do
      stub_const('TOOLS_CPPCHECK', { executable: 'cppcheck' })
      reportinator = double('reportinator', generate_progress: 'PROGRESS')
      cppcheck = build_cppcheck(config: { enable_checks: ['style'] }, loginator: loginator)
      cppcheck.instance_variable_set(:@reportinator, reportinator)

      expect(cppcheck).to receive(:run_tool).with(
        { executable: 'cppcheck' }, ['--enable=style'], ['src'], 'src/thing.c'
      ).and_return({ output: 'FINDINGS' })
      expect(loginator).to receive(:log).with('FINDINGS', anything, anything)

      cppcheck.analyze_file('src/thing.c')
    end
  end
end

# ===========================================================================
describe CppcheckXmlReport do
  let(:loginator)      { double('loginator', log: nil) }
  let(:tool_executor)  { double('tool_executor') }
  let(:tool_validator) { double('tool_validator') }
  let(:file_wrapper)   { double('file_wrapper') }
  let(:system_objects) do
    build_system_objects(
      loginator:      loginator,
      tool_executor:  tool_executor,
      tool_validator: tool_validator,
      file_wrapper:   file_wrapper
    )
  end

  before(:each) do
    stub_const('CPPCHECK_ARTIFACTS_PATH', 'artifacts/cppcheck')
    stub_const('CPPCHECK_ARTIFACTS_FILE_XML', 'CppcheckReport.xml')
  end

  # Version 2 is accepted by every Cppcheck. Version 3 requires a newer Cppcheck and
  # is rejected outright by older ones, so it is not a safe default.
  it 'uses --xml-version=2 by default' do
    report = described_class.new(system_objects, {})
    expect(report.send(:build_opts)).to include('--xml', '--xml-version=2')
  end

  it 'uses --xml-version=3 when version 3 is requested' do
    report = described_class.new(system_objects, { xml_report_version: 3 })
    expect(report.send(:build_opts)).to include('--xml', '--xml-version=3')
  end

  it 'uses --xml-version=2 when version 2 is requested' do
    report = described_class.new(system_objects, { xml_report_version: 2 })
    expect(report.send(:build_opts)).to include('--xml', '--xml-version=2')
  end

  it 'raises CeedlingException for an unsupported version' do
    expect {
      described_class.new(system_objects, { xml_report_version: 99 })
    }.to raise_error(CeedlingException, /invalid xml report version/i)
  end

  it 'derives artifact_filepath from config when xml_artifact_filename is set' do
    report = described_class.new(system_objects, { xml_artifact_filename: 'MyReport.xml' })
    expect(report.artifact_filepath).to eq('artifacts/cppcheck/MyReport.xml')
  end

  it 'falls back to the default artifact filename when xml_artifact_filename is absent' do
    report = described_class.new(system_objects, {})
    expect(report.artifact_filepath).to eq('artifacts/cppcheck/CppcheckReport.xml')
  end
end

# ===========================================================================
describe CppcheckHtmlReport do
  let(:loginator)      { double('loginator', log: nil) }
  let(:tool_executor)  { double('tool_executor') }
  let(:tool_validator) { double('tool_validator', validate: true) }
  let(:file_wrapper)   { double('file_wrapper') }
  let(:system_objects) do
    build_system_objects(
      loginator:      loginator,
      tool_executor:  tool_executor,
      tool_validator: tool_validator,
      file_wrapper:   file_wrapper
    )
  end

  before(:each) do
    stub_const('TOOLS_CPPCHECK_HTMLREPORT', { executable: 'cppcheck-htmlreport' })
    stub_const('CPPCHECK_ARTIFACTS_HTML_PATH', 'artifacts/cppcheck/html')
  end

  def build_html_report(config = {}, xml_path = 'artifacts/cppcheck/CppcheckReport.xml')
    described_class.new(system_objects, config, xml_path)
  end

  it 'always includes --file, --report-dir, and --source-dir in opts' do
    report = build_html_report({}, 'artifacts/cppcheck/CppcheckReport.xml')
    opts = report.send(:build_opts)
    expect(opts).to include(
      '--file=artifacts/cppcheck/CppcheckReport.xml',
      '--report-dir=artifacts/cppcheck/html',
      '--source-dir=.'
    )
  end

  it 'adds --title when html_title is configured' do
    report = build_html_report({ html_title: 'My Project' })
    expect(report.send(:build_opts)).to include('--title=My Project')
  end

  it 'omits --title when html_title is nil' do
    report = build_html_report({ html_title: nil })
    expect(report.send(:build_opts)).not_to include(a_string_starting_with('--title'))
  end

  it 'omits --title when html_title is empty' do
    report = build_html_report({ html_title: '' })
    expect(report.send(:build_opts)).not_to include(a_string_starting_with('--title'))
  end

  # respect_optional honors the tool's own `:optional => true` default, so a missing
  # cppcheck-htmlreport does not hard-fail a build that never generates HTML.
  it 'validates the htmlreport tool during initialization, respecting its optional flag' do
    expect(tool_validator).to receive(:validate).with(
      tool: { executable: 'cppcheck-htmlreport' },
      respect_optional: true,
      boom: true
    )
    build_html_report
  end
end

# ===========================================================================
describe CppcheckTextReport do
  before(:each) { stub_const('CPPCHECK_ARTIFACTS_PATH', 'artifacts/cppcheck') }

  let(:system_objects) do
    build_system_objects(
      loginator:      double('loginator'),
      tool_executor:  double('tool_executor'),
      tool_validator: double('tool_validator'),
      file_wrapper:   double('file_wrapper')
    )
  end

  it 'uses text as the report type' do
    stub_const('CPPCHECK_ARTIFACTS_FILE_TEXT', 'CppcheckReport.txt')
    report = described_class.new(system_objects, {})
    expect(report.report_type).to eq(:text)
  end

  it 'derives artifact_filepath from config when text_artifact_filename is set' do
    stub_const('CPPCHECK_ARTIFACTS_FILE_TEXT', 'CppcheckReport.txt')
    report = described_class.new(system_objects, { text_artifact_filename: 'Custom.txt' })
    expect(report.artifact_filepath).to eq('artifacts/cppcheck/Custom.txt')
  end
end

# ===========================================================================
describe CppcheckSarifReport do
  before(:each) { stub_const('CPPCHECK_ARTIFACTS_PATH', 'artifacts/cppcheck') }

  let(:system_objects) do
    build_system_objects(
      loginator:      double('loginator'),
      tool_executor:  double('tool_executor'),
      tool_validator: double('tool_validator'),
      file_wrapper:   double('file_wrapper')
    )
  end

  it 'uses sarif as the report type' do
    stub_const('CPPCHECK_ARTIFACTS_FILE_SARIF', 'CppcheckReport.sarif')
    report = described_class.new(system_objects, {})
    expect(report.report_type).to eq(:sarif)
  end

  it 'derives artifact_filepath from config when sarif_artifact_filename is set' do
    stub_const('CPPCHECK_ARTIFACTS_FILE_SARIF', 'CppcheckReport.sarif')
    report = described_class.new(system_objects, { sarif_artifact_filename: 'Custom.sarif' })
    expect(report.artifact_filepath).to eq('artifacts/cppcheck/Custom.sarif')
  end
end
