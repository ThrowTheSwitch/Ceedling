# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require_relative 'support/gcov_common_test_cases'

ceedling_system_tests do
  describe "Gcov" do
    include CommonSystemTestCases
    include GcovCommonTestCases
    before :all do
      determine_reports_to_test
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = unique_proj_name("gcov") }

    describe "Basic operations" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :project_with_gcov_success
      test_case :project_with_gcov_fail
      test_case :gcov_console_report_with_system_header
      test_case :gcov_console_report_with_partial
      # TODO: Restore these tests when the :abort_on_uncovered option is restored in the Gcov plugin
      # test_case :project_with_gcov_fail_because_of_uncovered_files
      # test_case :project_with_gcov_success_because_of_ignore_uncovered_list
      # test_case :project_with_gcov_success_because_of_ignore_uncovered_list_with_globs
      test_case :project_with_gcov_compile_error
      test_case :help_tasks_include_gcov
      test_case :create_html_report
      test_case :create_html_report_with_gcovr_config_file_overrides_default
      test_case :create_html_report_100_coverage_excluding_crashing_test_case
    end

    describe "Backtrace with GDB" do
      include_context "requires gdb"

      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :create_html_report_from_crashing_test_with_backtrace_enabled
      test_case :create_html_report_with_zero_coverage_after_crashing_test_and_backtrace
    end


    describe "Command: `ceedling example temp_sensor`" do
      describe "temp_sensor" do
        before do
          @c.with_context do
            # Remove any previous temp_sensor directory to prevent stale build
            # artifacts (especially .gcda files) from polluting subsequent tests.
            # `ceedling example` only restores src/test/mixin/project.yml and
            # leaves build/ intact, so recompiling with different defines (e.g.
            # UNITY_USE_COMMAND_LINE_ARGS added by --test-case) produces .gcno
            # files whose checksums no longer match the stale .gcda files.
            # On macOS/Clang the gcov runtime aborts on checksum mismatch rather
            # than resetting, crashing the test executable before Unity can print
            # its statistics line.
            FileUtils.rm_rf('temp_sensor')
            output = `bundle exec ruby -S ceedling example temp_sensor 2>&1`
            expect(output).to match(/created/)
          end
        end

        it "should be testable" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_gcov gcov:all 2>&1`
              # Validate full test suite results
              expect(@output).to match(/TESTED:\s+86/)
              expect(@output).to match(/PASSED:\s+86/)

              # Incomplete (i.e. spot check) coverage reporting validation
              expect(@output).to match(/AdcConductor\.c \| Lines executed:/i)
              expect(@output).to match(/AdcHardware\.c \| Lines executed:/i)
              expect(@output).to match(/AdcModel\.c \| Lines executed:/i)
              expect(@output).to match(/Executor\.c \| Lines executed:/i)
              expect(@output).to match(/Main\.c \| Lines executed:/i)
              expect(@output).to match(/Model\.c \| Lines executed:/i)

              expect(File.exist?('build/artifacts/gcov/gcovr/GcovCoverageResults.html')).to eq true
            end
          end
        end

        it "should be able to test a single module (it should INHERIT file-specific flags)" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_gcov gcov:TemperatureCalculator 2>&1`
              expect(@output).to match(/TESTED:\s+2/)
              expect(@output).to match(/PASSED:\s+2/)

              expect(@output).to match(/TemperatureCalculator\.c \| Lines executed:/i)
            end
          end
        end

        it "should be able to test multiple files matching a pattern" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_gcov gcov:pattern[Temp] 2>&1`
              expect(@output).to match(/TESTED:\s+6/)
              expect(@output).to match(/PASSED:\s+6/)

              expect(@output).to match(/TemperatureCalculator\.c \| Lines executed:/i)
              expect(@output).to match(/TemperatureFilter\.c \| Lines executed:/i)
            end
          end
        end

        it "should be able to test all files matching in a path" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_gcov gcov:path[adc] 2>&1`
              expect(@output).to match(/TESTED:\s+24/)
              expect(@output).to match(/PASSED:\s+24/)

              expect(@output).to match(/AdcConductor\.c \| Lines executed:/i)
              expect(@output).to match(/AdcHardware\.c \| Lines executed:/i)
              expect(@output).to match(/AdcModel\.c \| Lines executed:/i)
              expect(@output).to match(/AdcPlatformStandin\.out/i)
            end
          end
        end

        it "should be able to test specific test cases in a file" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_gcov gcov:path[adc] --test-case="RunShouldNot" 2>&1`
              expect(@output).to match(/TESTED:\s+2/)
              expect(@output).to match(/PASSED:\s+2/)

              expect(@output).to match(/AdcConductor\.c \| Lines executed:/i)
              expect(@output).to match(/AdcHardware\.c \| Lines executed:/i)
              expect(@output).to match(/AdcModel\.c \| Lines executed:/i)
            end
          end
        end

      end
    end
  end
end
