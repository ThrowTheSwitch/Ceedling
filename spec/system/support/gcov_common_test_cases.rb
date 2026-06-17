# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'gcov_helpers'

module GcovCommonTestCases
  include GcovHelpers

  def project_with_gcov_success
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(0) # Since test cases either pass or are ignored, Ceedling exits with success
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def project_with_gcov_fail
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Unit test failures => Ceedling exit code 1
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # TODO: Restore this test when the :abort_on_uncovered option is restored in the Gcov plugin
  # def project_with_gcov_fail_because_of_uncovered_files
  #   @c.with_context do
  #     Dir.chdir @proj_name do
  #       prep_project_yml_for_coverage
  #       add_gcov_option("abort_on_uncovered", "TRUE")
  #       FileUtils.cp test_asset_path("example_file.h"), 'src/'
  #       FileUtils.cp test_asset_path("example_file.c"), 'src/'
  #       FileUtils.cp test_asset_path("uncovered_example_file.c"), 'src/'
  #       FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

  #       output = `bundle exec ruby -S ceedling gcov:all 2>&1`
  #       expect($?.exitstatus).to match(1) # Gcov causes Ceedlng to exit with error
  #       expect(output).to match(/TESTED:\s+\d/)
  #       expect(output).to match(/PASSED:\s+\d/)
  #       expect(output).to match(/FAILED:\s+\d/)
  #       expect(output).to match(/IGNORED:\s+\d/)
  #     end
  #   end
  # end

  # TODO: Restore this test when the :abort_on_uncovered option is restored in the Gcov plugin
  # def project_with_gcov_success_because_of_ignore_uncovered_list
  #   @c.with_context do
  #     Dir.chdir @proj_name do
  #       prep_project_yml_for_coverage
  #       add_gcov_option("abort_on_uncovered", "TRUE")
  #       add_gcov_section("uncovered_ignore_list", ["src/foo_file.c"])
  #       FileUtils.cp test_asset_path("example_file.h"), "src/"
  #       FileUtils.cp test_asset_path("example_file.c"), "src/"
  #       # "src/foo_file.c" is in the ignore uncovered list
  #       FileUtils.cp test_asset_path("uncovered_example_file.c"), "src/foo_file.c"
  #       FileUtils.cp test_asset_path("test_example_file_success.c"), "test/"

  #       output = `bundle exec ruby -S ceedling gcov:all 2>&1`
  #       expect($?.exitstatus).to match(0)
  #       expect(output).to match(/TESTED:\s+\d/)
  #       expect(output).to match(/PASSED:\s+\d/)
  #       expect(output).to match(/FAILED:\s+\d/)
  #       expect(output).to match(/IGNORED:\s+\d/)
  #     end
  #   end
  # end

  # TODO: Restore this test when the :abort_on_uncovered option is restored in the Gcov plugin
  # def project_with_gcov_success_because_of_ignore_uncovered_list_with_globs
  #   @c.with_context do
  #     Dir.chdir @proj_name do
  #       prep_project_yml_for_coverage
  #       add_gcov_option("abort_on_uncovered", "TRUE")
  #       add_gcov_section("uncovered_ignore_list", ["src/B/**"])
  #       FileUtils.mkdir_p(["src/A", "src/B/C"])
  #       FileUtils.cp test_asset_path("example_file.h"), "src/A"
  #       FileUtils.cp test_asset_path("example_file.c"), "src/A"
  #       # "src/B/**" is in the ignore uncovered list
  #       FileUtils.cp test_asset_path("uncovered_example_file.c"), "src/B/C/foo_file.c"
  #       FileUtils.cp test_asset_path("test_example_file_success.c"), "test/"

  #       output = `bundle exec ruby -S ceedling gcov:all 2>&1`
  #       expect($?.exitstatus).to match(1) # Unit test failures => Ceedling exit code 1
  #       expect(output).to match(/TESTED:\s+\d/)
  #       expect(output).to match(/PASSED:\s+\d/)
  #       expect(output).to match(/FAILED:\s+\d/)
  #       expect(output).to match(/IGNORED:\s+\d/)
  #     end
  #   end
  # end

  def project_with_gcov_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test explodes, Ceedling exits with error
        expect(output).to match(/(?:ERROR: Ceedling Failed)|(?:Ceedling could not complete operations because of errors)/)
      end
    end
  end

  def help_tasks_include_gcov
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        output = `bundle exec ruby -S ceedling help 2>&1`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/ceedling gcov:\*/i)
        expect(output).to match(/ceedling gcov:all/i)
      end
    end
  end

  def create_html_report
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        if @gcov_reports.include? :gcovr
          expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        end
        if @gcov_reports.include? :modulegenerator
          expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
        end
      end
    end
  end

  def create_html_report_with_gcovr_config_file_overrides_default
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        # A second test file covering the same source creates duplicate function
        # coverage entries: Ceedling builds one executable per test file, and both
        # link against example_file.c, producing two sets of .gcda coverage data
        # for the same functions.
        File.write('test/test_example_file_2.c', <<~C)
          #include "unity.h"
          #include "example_file.h"

          void setUp(void) {}
          void tearDown(void) {}

          void test_difference_between_two_numbers(void)
          {
            TEST_ASSERT_EQUAL_INT(0, difference_between_numbers(1, 1));
          }
        C

        # 'strict' causes gcovr to exit non-zero when the same function appears in
        # multiple test executables' coverage data. Ceedling's default is
        # 'merge-use-line-max' (set in defaults.yml), which it injects as a CLI
        # arg that would override this config file setting without the fix.
        File.write('gcovr.cfg', [
          "[gcovr]",
          "merge-mode-functions = strict"
        ].join("\n"))

        @c.merge_project_yml_for_test({
          :gcov => {
            :gcovr => {
              :config_file => 'gcovr.cfg'
            }
          }
        })

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        if @gcov_reports.include? :gcovr
          # Config file honored (fix applied): strict mode exits non-zero on duplicate functions.
          # Config file overridden by Ceedling CLI (bug): merge-use-line-max exits 0.
          expect($?.exitstatus).not_to eq(0)
        end
      end
    end
  end

  def create_html_report_from_crashing_test_with_backtrace_enabled
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Ceedling should exit with error because of failed test due to crash
        expect(output).to match(/crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/gcov/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/gcov/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
        expect(output).to match(/example_file.c \| Lines executed:5?0.00% of 4/)
        if @gcov_reports.include? :gcovr
          expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        end
        if @gcov_reports.include? :modulegenerator
          expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
        end
      end
    end
  end

  def create_html_report_with_zero_coverage_after_crashing_test_and_backtrace
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = `bundle exec ruby -S ceedling gcov:all --exclude_test_case=test_add_numbers_adds_numbers 2>&1`
        expect($?.exitstatus).to match(1) # Ceedling should exit with error because of failed test due to crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/gcov/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/gcov/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+1/)
        expect(output).to match(/IGNORED:\s+0/)
        expect(output).to match(/example_file.c \| Lines executed:0.00% of 4/)

        if @gcov_reports.include? :gcovr
          expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        end
        if @gcov_reports.include? :modulegenerator
          expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
        end
      end
    end
  end

  def create_html_report_100_coverage_excluding_crashing_test_case
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_coverage
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        add_test_case = "\nvoid test_difference_between_two_numbers(void)\n"\
                        "{\n" \
                        "  TEST_ASSERT_EQUAL_INT(0, difference_between_numbers(1,1));\n" \
                        "}\n"

        updated_test_file = File.read('test/test_example_file_crash.c').split("\n")
        updated_test_file.insert(updated_test_file.length(), add_test_case)
        File.write('test/test_example_file_crash.c', updated_test_file.join("\n"), mode: 'w')

        output = `bundle exec ruby -S ceedling gcov:all --exclude_test_case=test_add_numbers_will_fail 2>&1`
        expect($?.exitstatus).to match(0)
        expect(File.exist?('./build/gcov/results/test_example_file_crash.pass'))
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+2/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
        expect(output).to match(/example_file.c \| Lines executed:100.00% of 4/)

        if @gcov_reports.include? :gcovr
          expect(output).to match(/Generating HTML coverage report in 'build\/artifacts\/gcov\/gcovr\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
        end
        if @gcov_reports.include? :modulegenerator
          expect(output).to match(/Generating HtmlBasic coverage report in 'build\/artifacts\/gcov\/ReportGenerator\/'\.\.\./)
          expect(File.exist?('build/artifacts/gcov/ReportGenerator/summary.htm')).to eq true
        end
      end
    end
  end
end
