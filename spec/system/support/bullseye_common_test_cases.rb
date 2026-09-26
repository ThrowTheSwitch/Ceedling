# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'bullseye_helpers'

module BullseyeCommonTestCases
  include BullseyeHelpers

  ##
  ## Basic operations
  ##

  def bullseye_success
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage

        FileUtils.cp test_asset_path('example_file.h'), 'src/'
        FileUtils.cp test_asset_path('example_file.c'), 'src/'
        FileUtils.cp test_asset_path('test_example_file_success.c'), 'test/'

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(File.exist?('test.cov')).to eq true
        expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
      end
    end
  end

  def bullseye_fail
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage

        FileUtils.cp test_asset_path('example_file.h'), 'src/'
        FileUtils.cp test_asset_path('example_file.c'), 'src/'
        FileUtils.cp test_asset_path('test_example_file.c'), 'test/'

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/FAILED:\s+[1-9]/)
      end
    end
  end

  ##
  ## Branch coverage detail
  ##

  def bullseye_branch_detail_disabled_by_default
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(output).not_to match(/BRANCH COVERAGE DETAIL/)
      end
    end
  end

  def bullseye_branch_detail_uncovered
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture
        add_bullseye_option('branch_detail', ':uncovered')

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/BRANCH COVERAGE DETAIL/)

        # The annotated listing marks incomplete coverage with '-->' and reports
        # the wholly untested function.
        expect(output).to match(/-->/)
        expect(output).to match(/branchy_unused/)

        # Report exclusions are verified against the XML artifact instead of this
        # console output. Debug verbosity prints a compilation line for every
        # framework source, so their names appear here regardless of what the
        # coverage listing itself contains.
      end
    end
  end

  def bullseye_branch_detail_all
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture
        add_bullseye_option('branch_detail', ':all')

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/BRANCH COVERAGE DETAIL/)

        # :all annotates every source line, including the fully covered function
        # signature that :uncovered would omit.
        expect(output).to match(/branchy_classify/)
        expect(output).to match(/branchy_unused/)
      end
    end
  end

  def bullseye_branch_detail_rejects_unknown_value
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        add_bullseye_option('branch_detail', ':bogus')

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/:branch_detail/)
        expect(output).to match(/bogus/)
      end
    end
  end

  ##
  ## XML reporting
  ##

  def bullseye_xml_report_disabled_by_default
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture

        @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'coverage.xml'))).to eq false
      end
    end
  end

  def bullseye_xml_report_cobertura
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture
        add_bullseye_option('xml_report', ':cobertura')

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/XML coverage report/)

        xml_path = File.join('build', 'artifacts', 'bullseye', 'coverage.xml')
        expect(File.exist?(xml_path)).to eq true

        contents = File.read(xml_path)
        expect(contents).to match(/cobertura/)
        expect(contents).to match(/line-rate=/)

        # The report artifact is the reliable place to verify report exclusions.
        # Project sources appear. Framework sources, generated runners, and test
        # files do not.
        expect(contents).to match(/branchy\.c/)
        expect(contents).not_to match(/unity\.c/)
        expect(contents).not_to match(/test_branchy\.c/)
      end
    end
  end

  def bullseye_xml_report_native
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture
        add_bullseye_option('xml_report', ':native')

        @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)

        xml_path = File.join('build', 'artifacts', 'bullseye', 'coverage.xml')
        expect(File.exist?(xml_path)).to eq true

        contents = File.read(xml_path)
        expect(contents).to match(/BullseyeCoverage/)
        expect(contents).to match(/fn_cov=/)
      end
    end
  end

  ##
  ## Coverage thresholds
  ##

  def bullseye_fail_under_met
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture

        # The fixture covers 1 of 2 functions and 1 of 10 conditions/decisions.
        # These minimums sit below both.
        add_bullseye_nested_option('fail_under', { 'functions' => 40, 'branches' => 5 })

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(0)
        expect(output).not_to match(/below the configured minimum/)
      end
    end
  end

  def bullseye_fail_under_unmet
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        copy_branch_coverage_fixture

        # These minimums sit above the fixture's actual coverage on both metrics.
        add_bullseye_nested_option('fail_under', { 'functions' => 90, 'branches' => 75 })

        output = @c.ceedling_build_exec('bullseye:all')

        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/Function coverage \d+% is below the configured minimum of 90%/)
        expect(output).to match(/Branch coverage \d+% is below the configured minimum of 75%/)

        # Reports still generate. The threshold check runs last so coverage numbers
        # are visible before the failure.
        expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
      end
    end
  end

  ##
  ## License diagnostics
  ##

  def bullseye_license_status_task
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage

        # Not a `build` command, so this goes through the application-command path.
        output = @c.ceedling_appcmd_exec('utils:bullseye_license')

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/LICENSE STATUS/)
        # covlmgr reports the license number and expiry for every license type.
        expect(output).to match(/License \d+/)
      end
    end
  end

  ##
  ## temp_sensor example project
  ##

  def temp_sensor_full_suite
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        output = @c.ceedling_build_exec('bullseye:all --mixin=add_bullseye')

        expect(output).to match(/TESTED:\s+86/)
        expect(output).to match(/PASSED:\s+86/)

        # Incomplete (i.e. spot check) per-function coverage reporting validation
        expect(output).to match(/TemperatureCalculator_Calculate\(uint16\)/)
        expect(output).to match(/AdcConductor_Run\(void\)/)
        expect(output).to match(/UsartConductor_Run\(void\)/)

        # Aggregate console summary
        expect(output).to match(/FUNCTIONS:\s+\d+%/)
        expect(output).to match(/BRANCHES:\s+\d+%/)

        expect(File.exist?('test.cov')).to eq true
        expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
      end
    end
  end

  def temp_sensor_single_module
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        output = @c.ceedling_build_exec('bullseye:TemperatureCalculator --mixin=add_bullseye')

        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+2/)
        expect(output).to match(/TemperatureCalculator_Calculate\(uint16\)/)
      end
    end
  end

  def temp_sensor_pattern
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        output = @c.ceedling_build_exec('bullseye:pattern[Temp] --mixin=add_bullseye')

        expect(output).to match(/TESTED:\s+6/)
        expect(output).to match(/PASSED:\s+6/)
        expect(output).to match(/TemperatureCalculator_Calculate\(uint16\)/)
      end
    end
  end

  def temp_sensor_path
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        output = @c.ceedling_build_exec('bullseye:path[adc] --mixin=add_bullseye')

        expect(output).to match(/TESTED:\s+24/)
        expect(output).to match(/PASSED:\s+24/)
        expect(output).to match(/AdcConductor_Run\(void\)/)
      end
    end
  end

  def temp_sensor_untested_sources_list
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        # Only the `all` task calls process_untested_sources -- matching gcov's
        # own design, where this same accounting only happens for a full run.
        output = @c.ceedling_build_exec('bullseye:all --mixin=add_bullseye')

        expect(output).to match(/Untested source files not in the coverage report/)
        expect(output).to match(/IntrinsicsWrapper\.c/)
      end
    end
  end

  def temp_sensor_untested_sources_compile
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        add_bullseye_option('untested_sources', ':compile')

        output = @c.ceedling_build_exec('bullseye:untested_sources --mixin=add_bullseye')

        expect(output).to match(/Compiling with coverage IntrinsicsWrapper\.c/)
      end
    end
  end

  def temp_sensor_report_task
    @c.with_context do
      Dir.chdir 'temp_sensor' do
        add_bullseye_option('report_task', 'TRUE')

        output = @c.ceedling_build_exec('bullseye:all --mixin=add_bullseye')
        expect(output).not_to match(/Bullseye HTML coverage report/)

        output = @c.ceedling_build_exec('report:bullseye --mixin=add_bullseye')
        expect(output).to match(/Bullseye HTML coverage report/)
        expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
      end
    end
  end

end
