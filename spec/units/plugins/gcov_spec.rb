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
require 'ceedling/path_mirror'
require 'ceedling/filename_extension'

PROJECT_BUILD_ROOT           = 'build'     unless defined?(PROJECT_BUILD_ROOT)
PROJECT_BUILD_ARTIFACTS_ROOT = 'artifacts' unless defined?(PROJECT_BUILD_ARTIFACTS_ROOT)

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcov_constants'
require 'gcov_types'
require 'gcov_reportinator'
require 'console_reportinator'
require 'gcovr_reportinator'
require 'reportgenerator_reportinator'
require 'gcov'

TOOLS_GCOV_GCC_VERSION = { name: 'gcov_gcc_version' }.freeze unless defined?(TOOLS_GCOV_GCC_VERSION)
TOOLS_GCOV_COMPILER    = { name: 'gcov_compiler' }.freeze    unless defined?(TOOLS_GCOV_COMPILER)
TOOLS_GCOV_LINKER      = { name: 'gcov_linker' }.freeze      unless defined?(TOOLS_GCOV_LINKER)
EXTENSION_ASSEMBLY     = FilenameExtension.new('.s')         unless defined?(EXTENSION_ASSEMBLY)

# Bypasses Plugin#initialize (which would run the real setup(), pulling in far
# more than any single method under test needs) via .allocate, setting only
# the instance variables the method(s) under test actually touch. Each
# describe block below is scoped to one Gcov method/behavior -- not full-file
# mirroring coverage (see plan notes on what's deliberately excluded).
describe Gcov do
  let(:loginator)        { double('loginator', log: nil, lazy: nil) }
  let(:reportinator_obj) { double('reportinator', generate_progress: '') }
  let(:tool_executor)    { double('tool_executor') }

  # ivars: hash of instance-variable-name (without @) => value, letting each
  # test set only the collaborators its own method under test needs, on top
  # of the always-present loginator/reportinator/tool_executor/mcdc_gcc_checked
  # defaults (overridable the same way).
  def build_gcov(project_config, ivars = {})
    instance = Gcov.allocate
    defaults = {
      project_config:   project_config,
      loginator:        loginator,
      reportinator:     reportinator_obj,
      tool_executor:    tool_executor,
      mcdc_gcc_checked: false,
    }
    defaults.merge(ivars).each { |key, value| instance.instance_variable_set(:"@#{key}", value) }
    instance
  end

  describe '#validate_mcdc_gcc_version!' do
    it 'never shells out to gcc when :mcdc is not configured' do
      gcov = build_gcov({ gcov_mcdc: false })
      expect(tool_executor).to_not receive(:build_command_line)
      gcov.send(:validate_mcdc_gcc_version!)
    end

    it 'raises CeedlingException when :mcdc is configured against GCC older than 14' do
      gcov = build_gcov({ gcov_mcdc: true })
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "gcc (Ubuntu) 13.2.0\n" })

      expect {
        gcov.send(:validate_mcdc_gcc_version!)
      }.to raise_error(CeedlingException, /:mcdc.*requires GCC 14\.0 or higher \(found 13\.2\)/)
    end

    it 'does not raise when :mcdc is configured against GCC 14+' do
      gcov = build_gcov({ gcov_mcdc: true })
      allow(tool_executor).to receive(:build_command_line).and_return({})
      allow(tool_executor).to receive(:exec).and_return({ output: "gcc (Ubuntu) 14.2.0\n" })

      expect { gcov.send(:validate_mcdc_gcc_version!) }.to_not raise_error
    end

    it 'checks gcc --version at most once even when called repeatedly' do
      gcov = build_gcov({ gcov_mcdc: true })
      allow(tool_executor).to receive(:build_command_line).and_return({})
      expect(tool_executor).to receive(:exec).once.and_return({ output: "gcc (Ubuntu) 14.2.0\n" })

      3.times { gcov.send(:validate_mcdc_gcc_version!) }
    end
  end

  describe '#validate_untested_sources' do
    it 'passes for every recognized :untested_sources mode' do
      gcov = build_gcov({})
      GCOV_UNTESTED_SOURCES_OPTIONS.each do |mode|
        expect { gcov.send(:validate_untested_sources, { gcov_untested_sources: mode }) }.to_not raise_error
      end
    end

    it 'raises CeedlingException naming the bad value and listing valid options' do
      gcov = build_gcov({})
      expect {
        gcov.send(:validate_untested_sources, { gcov_untested_sources: :bogus })
      }.to raise_error(CeedlingException, /:untested_sources.*bogus.*:ignore.*:list.*:compile/)
    end
  end

  describe '#validate_utilities_config' do
    it 'passes for recognized utility names, case-insensitively' do
      gcov = build_gcov({})
      expect { gcov.send(:validate_utilities_config, ['gcovr', 'ReportGenerator']) }.to_not raise_error
      expect { gcov.send(:validate_utilities_config, ['GCOVR']) }.to_not raise_error
    end

    it 'raises CeedlingException naming the unrecognized utility' do
      gcov = build_gcov({})
      expect {
        gcov.send(:validate_utilities_config, ['bogus_tool'])
      }.to raise_error(CeedlingException, /:utilities.*bogus_tool/)
    end
  end

  describe '#collect_untested_sources' do
    it 'returns every source minus those referenced by any test, accumulated across tests' do
      test_invoker = double('test_invoker')
      allow(test_invoker).to receive(:each_test_with_sources)
        .and_yield('test_a', ['src/a.c']).and_yield('test_b', ['src/b.c'])
      gcov = build_gcov({}, test_invoker: test_invoker)

      result = gcov.send(:collect_untested_sources, ['src/a.c', 'src/b.c', 'src/c.c'])
      expect(result).to eq(['src/c.c'])
    end
  end

  describe '#post_test_fixture_execute' do
    # The #104 bracket-escaping regression itself (a literal '[' or ']' in
    # GCOV_RESULTS_PATH breaking this match) can't be reproduced here --
    # GCOV_RESULTS_PATH is a frozen constant fixed once for this whole spec
    # process from PROJECT_BUILD_ROOT, which contains no brackets. That
    # regression stays covered only by the system-test suite.
    it 'appends a result_file whose path matches GCOV_RESULTS_PATH' do
      gcov = build_gcov({}, mutex: Mutex.new, result_list: [])
      path = File.join(GCOV_RESULTS_PATH, 'test_foo.pass')
      gcov.post_test_fixture_execute({ result_file: path })
      expect(gcov.instance_variable_get(:@result_list)).to eq([path])
    end

    it 'ignores a result_file outside GCOV_RESULTS_PATH' do
      gcov = build_gcov({}, mutex: Mutex.new, result_list: [])
      gcov.post_test_fixture_execute({ result_file: 'build/other/test_foo.pass' })
      expect(gcov.instance_variable_get(:@result_list)).to eq([])
    end

    it 'does not add the same result_file twice' do
      gcov = build_gcov({}, mutex: Mutex.new, result_list: [])
      path = File.join(GCOV_RESULTS_PATH, 'test_foo.pass')
      gcov.post_test_fixture_execute({ result_file: path })
      gcov.post_test_fixture_execute({ result_file: path })
      expect(gcov.instance_variable_get(:@result_list)).to eq([path])
    end
  end

  describe '#process_untested_sources' do
    let(:file_path_utils) { double('file_path_utils') }
    let(:configurator)    { double('configurator', collection_paths_include: []) }
    let(:defineinator)    { double('defineinator', defines: []) }
    let(:flaginator)      { double('flaginator', flag_down: []) }
    let(:dependinator)    { double('dependinator', register: nil, register_gcc_deps_file: nil, flush: nil, mark_fresh: nil) }
    let(:generator)       { double('generator', generate_object_file_c: nil) }
    let(:file_wrapper)    { double('file_wrapper', exist?: false) }
    let(:test_invoker)    { double('test_invoker') }

    def build_process_gcov(project_config, ivars = {})
      allow(test_invoker).to receive(:each_test_with_sources)
      allow(reportinator_obj).to receive(:generate_heading).and_return('HEADING')
      allow(reportinator_obj).to receive(:generate_skip_summary).and_return(nil)
      allow(reportinator_obj).to receive(:generate_module_progress).and_return('PROGRESS')
      allow(loginator).to receive(:decorate).and_return('DECORATED')
      allow(loginator).to receive(:log_list)
      build_gcov(
        project_config,
        {
          file_path_utils: file_path_utils, configurator: configurator, defineinator: defineinator,
          flaginator: flaginator, dependinator: dependinator, generator: generator,
          file_wrapper: file_wrapper, test_invoker: test_invoker, mcdc_gcc_checked: true,
          gcov_config: {},
        }.merge(ivars)
      )
    end

    context ':ignore mode' do
      it 'has zero side effects' do
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_IGNORE })
        expect(loginator).to_not receive(:log)
        expect(dependinator).to_not receive(:register)
        gcov.process_untested_sources(sources: ['src/a.c'])
      end
    end

    context ':list mode' do
      it 'logs "no untested sources" and does not touch dependinator when the list is empty' do
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_LIST })
        expect(dependinator).to_not receive(:register)
        gcov.process_untested_sources(sources: [])
      end

      it 'logs the full, sorted filepath list and records @untested_sources without compiling' do
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_LIST })
        expect(loginator).to receive(:log_list).with(['src/a.c', 'src/b.c'], kind_of(String), Verbosity::COMPLAIN, LogLabels::WARNING)
        expect(generator).to_not receive(:generate_object_file_c)
        gcov.process_untested_sources(sources: ['src/b.c', 'src/a.c'])
        expect(gcov.instance_variable_get(:@untested_sources)).to eq(['src/b.c', 'src/a.c'])
      end
    end

    context ':compile mode' do
      before do
        allow(file_path_utils).to receive(:form_test_object_filepath).and_return('build/gcov/out/src/a.o')
        allow(file_path_utils).to receive(:form_test_dependencies_filepath).and_return('build/gcov/out/src/a.d')
      end

      it 'logs "no untested sources" and never calls the generator when the list is empty' do
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(generator).to_not receive(:generate_object_file_c)
        expect(dependinator).to_not receive(:flush)
        gcov.process_untested_sources(sources: [])
      end

      it 'skips compilation for an already-fresh object without calling the generator' do
        allow(dependinator).to receive(:stale?).and_return(false)
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(generator).to_not receive(:generate_object_file_c)
        expect(dependinator).to_not receive(:mark_fresh)
        gcov.process_untested_sources(sources: ['src/a.c'])
      end

      it 'compiles a stale object and marks it fresh' do
        allow(dependinator).to receive(:stale?).and_return(true)
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(generator).to receive(:generate_object_file_c)
        expect(dependinator).to receive(:mark_fresh)
        gcov.process_untested_sources(sources: ['src/a.c'])
      end

      it 'injects -fcondition-coverage into the compile flags only when :gcov_mcdc is set' do
        allow(dependinator).to receive(:stale?).and_return(true)
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: true })
        expect(generator).to receive(:generate_object_file_c) do |args|
          expect(args[:flags]).to include('-fcondition-coverage')
        end
        gcov.process_untested_sources(sources: ['src/a.c'])
      end

      it 'omits -fcondition-coverage when :gcov_mcdc is not set' do
        allow(dependinator).to receive(:stale?).and_return(true)
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(generator).to receive(:generate_object_file_c) do |args|
          expect(args[:flags]).to_not include('-fcondition-coverage')
        end
        gcov.process_untested_sources(sources: ['src/a.c'])
      end

      it 're-raises a ShellException and logs guidance when guidance: true (the default)' do
        allow(dependinator).to receive(:stale?).and_return(true)
        allow(generator).to receive(:generate_object_file_c)
          .and_raise(ShellException.new(name: 'compile', message: 'compile failed'))
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(loginator).to receive(:log).with(/Compiling untested/, Verbosity::COMPLAIN, LogLabels::NOTICE)
        expect(dependinator).to_not receive(:mark_fresh)
        expect { gcov.process_untested_sources(sources: ['src/a.c']) }.to raise_error(ShellException)
      end

      it 're-raises a ShellException without logging guidance when guidance: false' do
        allow(dependinator).to receive(:stale?).and_return(true)
        allow(generator).to receive(:generate_object_file_c)
          .and_raise(ShellException.new(name: 'compile', message: 'compile failed'))
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(loginator).to_not receive(:log).with(/Compiling untested/, any_args)
        expect { gcov.process_untested_sources(sources: ['src/a.c'], guidance: false) }.to raise_error(ShellException)
      end

      it 'registers gcc deps files only when file_wrapper reports the dependencies file exists' do
        allow(dependinator).to receive(:stale?).and_return(true)
        allow(file_wrapper).to receive(:exist?).and_return(true)
        gcov = build_process_gcov({ gcov_untested_sources: GCOV_UNTESTED_SOURCES_COMPILE, gcov_mcdc: false })
        expect(dependinator).to receive(:register_gcc_deps_file).twice
        gcov.process_untested_sources(sources: ['src/a.c'])
      end
    end
  end

  describe '#generate_coverage_reports' do
    let(:configurator) { double('configurator', project_config_hash: {}) }

    it 'does nothing when no reports are enabled' do
      gcov = build_gcov({}, reports_enabled: false)
      expect(gcov).to_not receive(:build_reportinators)
      gcov.generate_coverage_reports
    end

    it 'builds reportinators at most once across repeated calls' do
      r = double('reportinator_instance', artifacts_path: nil, generate_reports: nil, summary: '', name: 'X')
      gcov = build_gcov({}, reports_enabled: true, configurator: configurator)
      expect(gcov).to receive(:build_reportinators).once.and_return([r])
      gcov.generate_coverage_reports
      gcov.generate_coverage_reports
    end

    it 'isolates a raised exception in one reportinator as a build failure without aborting the loop' do
      failing = double('failing_reportinator', artifacts_path: nil, name: 'Failing', summary: '')
      allow(failing).to receive(:generate_reports).and_raise(StandardError.new('boom'))
      succeeding = double('succeeding_reportinator', artifacts_path: nil, generate_reports: nil, name: 'OK', summary: '')

      plugin_manager = double('plugin_manager')
      expect(plugin_manager).to receive(:register_build_failure).with(GCOV_SYM, 'boom')

      gcov = build_gcov({}, reports_enabled: true, configurator: configurator, ceedling: { plugin_manager: plugin_manager })
      allow(gcov).to receive(:build_reportinators).and_return([failing, succeeding])

      gcov.generate_coverage_reports
      expect(succeeding).to have_received(:generate_reports)
    end

    it 'logs the reportinator summary only when non-empty' do
      r_with_summary = double('r1', artifacts_path: nil, generate_reports: nil, name: 'R1', summary: 'coverage: 80%')
      r_without       = double('r2', artifacts_path: nil, generate_reports: nil, name: 'R2', summary: '')
      gcov = build_gcov({}, reports_enabled: true, configurator: configurator)
      allow(gcov).to receive(:build_reportinators).and_return([r_with_summary, r_without])

      allow(reportinator_obj).to receive(:generate_heading).and_return('HEADING')
      allow(loginator).to receive(:log)
      expect(loginator).to receive(:log).with('coverage: 80%')
      gcov.generate_coverage_reports
    end

    it 'creates the artifacts directory only when artifacts_path is present' do
      file_wrapper = double('file_wrapper')
      r_with_path    = double('r1', artifacts_path: 'artifacts/x', generate_reports: nil, name: 'R1', summary: '')
      r_without_path = double('r2', artifacts_path: nil, generate_reports: nil, name: 'R2', summary: '')
      expect(file_wrapper).to receive(:mkdir).with('artifacts/x')
      gcov = build_gcov({}, reports_enabled: true, configurator: configurator, file_wrapper: file_wrapper)
      allow(gcov).to receive(:build_reportinators).and_return([r_with_path, r_without_path])
      gcov.generate_coverage_reports
    end
  end

  describe '#post_build' do
    it 'does nothing when no gcov: task was invoked' do
      configurator = double('configurator')
      gcov = build_gcov({}, cli_gcov_task: false, configurator: configurator)
      expect(configurator).to_not receive(:plugins_display_raw_test_results)
      gcov.post_build(0)
    end

    it 'skips the plugin-based test-results report when another plugin already displays raw results' do
      configurator = double('configurator', plugins_display_raw_test_results: true)
      plugin_reportinator = double('plugin_reportinator')
      gcov = build_gcov(
        {}, cli_gcov_task: true, configurator: configurator,
        plugin_reportinator: plugin_reportinator, console_reportinator: nil, reports_enabled: false
      )
      expect(plugin_reportinator).to_not receive(:assemble_test_results)
      gcov.post_build(0)
    end

    it 'runs the plugin-based test-results report when no other plugin displays raw results' do
      configurator = double('configurator', plugins_display_raw_test_results: false)
      plugin_reportinator = double('plugin_reportinator', test_results_floor_verbosity: Verbosity::ERRORS, assemble_test_results: {})
      expect(plugin_reportinator).to receive(:run_test_results_report)
      gcov = build_gcov(
        {}, cli_gcov_task: true, configurator: configurator, plugin_reportinator: plugin_reportinator,
        console_reportinator: nil, reports_enabled: false, result_list: []
      )
      gcov.post_build(0)
    end

    it 'safely no-ops the console reportinator call when summaries are disabled (nil)' do
      configurator = double('configurator', plugins_display_raw_test_results: true)
      gcov = build_gcov({}, cli_gcov_task: true, configurator: configurator, console_reportinator: nil, reports_enabled: false)
      expect { gcov.post_build(0) }.to_not raise_error
    end

    it 'runs automatic report generation only when automatic_reporting_enabled? is true' do
      configurator = double('configurator', plugins_display_raw_test_results: true)
      gcov = build_gcov({ gcov_report_task: false }, cli_gcov_task: true, configurator: configurator, console_reportinator: nil)
      expect(gcov).to receive(:generate_coverage_reports)
      gcov.post_build(0)
    end

    it 'skips automatic report generation when :report_task is enabled (manual reporting)' do
      configurator = double('configurator', plugins_display_raw_test_results: true)
      gcov = build_gcov({ gcov_report_task: true }, cli_gcov_task: true, configurator: configurator, console_reportinator: nil)
      expect(gcov).to_not receive(:generate_coverage_reports)
      gcov.post_build(0)
    end
  end

  describe '#build_reportinators' do
    it 'instantiates GcovrReportinator when :utilities includes gcovr, case-insensitively' do
      gcovr_double = double('gcovr_reportinator')
      allow(GcovrReportinator).to receive(:new).and_return(gcovr_double)
      ceedling_hash = { some: 'objects' }
      gcov = build_gcov({}, ceedling: ceedling_hash)
      result = gcov.send(:build_reportinators, ['GCOVR'])
      expect(result).to eq([gcovr_double])
      expect(GcovrReportinator).to have_received(:new).with(ceedling_hash, {})
    end

    it 'instantiates ReportGeneratorReportinator when :utilities includes ReportGenerator' do
      rg_double = double('rg_reportinator')
      allow(ReportGeneratorReportinator).to receive(:new).and_return(rg_double)
      gcov = build_gcov({}, ceedling: {})
      result = gcov.send(:build_reportinators, ['reportgenerator'])
      expect(result).to eq([rg_double])
    end

    it 'instantiates both when both utilities are configured' do
      gcovr_double = double('gcovr_reportinator')
      rg_double    = double('rg_reportinator')
      allow(GcovrReportinator).to receive(:new).and_return(gcovr_double)
      allow(ReportGeneratorReportinator).to receive(:new).and_return(rg_double)
      gcov = build_gcov({}, ceedling: {})
      result = gcov.send(:build_reportinators, ['gcovr', 'ReportGenerator'])
      expect(result).to eq([gcovr_double, rg_double])
    end

    it 'instantiates neither when :utilities is empty' do
      gcov = build_gcov({}, ceedling: {})
      expect(GcovrReportinator).to_not receive(:new)
      expect(ReportGeneratorReportinator).to_not receive(:new)
      expect(gcov.send(:build_reportinators, [])).to eq([])
    end
  end

  describe '#pre_test_compile_register' do
    let(:dependinator) { double('dependinator', register: nil) }

    it 'does nothing outside the gcov context' do
      gcov = build_gcov({}, dependinator: dependinator)
      arg_hash = { context: :test, tool: :original, flags: [] }
      expect(dependinator).to_not receive(:register)
      gcov.pre_test_compile_register(arg_hash)
      expect(arg_hash[:tool]).to eq(:original)
    end

    it 'does nothing for an assembly source' do
      gcov = build_gcov({}, dependinator: dependinator)
      arg_hash = { context: GCOV_SYM, source: 'foo.s', tool: :original, flags: [] }
      expect(dependinator).to_not receive(:register)
      gcov.pre_test_compile_register(arg_hash)
    end

    it 'swaps in the coverage compiler and adds -fcondition-coverage only when :gcov_mcdc is set' do
      gcov = build_gcov({ gcov_mcdc: true }, dependinator: dependinator, mcdc_gcc_checked: true, gcov_config: {})
      arg_hash = { context: GCOV_SYM, source: 'foo.c', tool: :original, flags: [], object: 'foo.o' }
      gcov.pre_test_compile_register(arg_hash)
      expect(arg_hash[:tool]).to eq(TOOLS_GCOV_COMPILER)
      expect(arg_hash[:flags]).to include('-fcondition-coverage')
    end

    it 'omits -fcondition-coverage when :gcov_mcdc is not set' do
      gcov = build_gcov({ gcov_mcdc: false }, dependinator: dependinator, mcdc_gcc_checked: true, gcov_config: {})
      arg_hash = { context: GCOV_SYM, source: 'foo.c', tool: :original, flags: [], object: 'foo.o' }
      gcov.pre_test_compile_register(arg_hash)
      expect(arg_hash[:flags]).to_not include('-fcondition-coverage')
    end
  end

  describe '#pre_test_link_register' do
    let(:dependinator) { double('dependinator', register: nil) }

    it 'does nothing outside the gcov context, and does not set @cli_gcov_task' do
      gcov = build_gcov({}, dependinator: dependinator, cli_gcov_task: false)
      arg_hash = { context: :test, tool: :original, flags: [] }
      expect(dependinator).to_not receive(:register)
      gcov.pre_test_link_register(arg_hash)
      expect(gcov.instance_variable_get(:@cli_gcov_task)).to eq(false)
    end

    it 'is the sole site that flips @cli_gcov_task to true for a real gcov-context link' do
      gcov = build_gcov(
        { gcov_mcdc: false }, dependinator: dependinator, cli_gcov_task: false,
        mcdc_gcc_checked: true, gcov_config: {}
      )
      arg_hash = { context: GCOV_SYM, tool: :original, flags: [], executable: 'foo.out' }
      gcov.pre_test_link_register(arg_hash)
      expect(gcov.instance_variable_get(:@cli_gcov_task)).to eq(true)
      expect(arg_hash[:tool]).to eq(TOOLS_GCOV_LINKER)
    end

    it 'adds -fcondition-coverage only when :gcov_mcdc is set' do
      gcov = build_gcov(
        { gcov_mcdc: true }, dependinator: dependinator, cli_gcov_task: false,
        mcdc_gcc_checked: true, gcov_config: {}
      )
      arg_hash = { context: GCOV_SYM, tool: :original, flags: [], executable: 'foo.out' }
      gcov.pre_test_link_register(arg_hash)
      expect(arg_hash[:flags]).to include('-fcondition-coverage')
    end
  end
end
