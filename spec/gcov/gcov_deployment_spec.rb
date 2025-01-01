# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'gcov/gcov_test_cases_spec'

describe "Ceedling" do
  describe "Gcov" do
    include CeedlingTestCases
    include GcovTestCases
    before :all do
      determine_reports_to_test
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = "fake_project" }
    after { @c.with_context { FileUtils.rm_rf @proj_name } }

    describe "basic operations" do
      before do
        @c.with_context do
          `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
        end
      end

      it { can_test_projects_with_gcov_with_success }
      it { can_test_projects_with_gcov_with_fail }
      # TODO: Restore these tests when the :abort_on_uncovered option is restored in the Gcov plugin
      # it { can_test_projects_with_gcov_with_fail_because_of_uncovered_files }
      # it { can_test_projects_with_gcov_with_success_because_of_ignore_uncovered_list }
      # it { can_test_projects_with_gcov_with_success_because_of_ignore_uncovered_list_with_globs }
      it { can_test_projects_with_gcov_with_compile_error }
      it { can_fetch_project_help_for_gcov }
      it { can_create_html_reports }
      it { can_create_html_reports_from_crashing_test_runner_with_enabled_debug_for_test_cases_not_causing_crash }
      it { can_create_html_reports_from_crashing_test_runner_with_enabled_debug_with_zero_coverage }
      it { can_create_html_reports_from_test_runner_with_enabled_debug_with_100_coverage_when_excluding_crashing_test_case }
    end


    describe "command: `ceedling example temp_sensor`" do
      describe "temp_sensor" do
        before do
          @c.with_context do
            output = `bundle exec ruby -S ceedling example temp_sensor 2>&1`
            expect(output).to match(/created/)
          end
        end

        it "should be testable" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_gcov gcov:all 2>&1`
              expect(@output).to match(/TESTED:\s+51/)
              expect(@output).to match(/PASSED:\s+51/)

              expect(@output).to match(/AdcConductor\.c \| Lines executed:/i)
              expect(@output).to match(/AdcHardware\.c \| Lines executed:/i)
              expect(@output).to match(/AdcModel\.c \| Lines executed:/i)
              expect(@output).to match(/Executor\.c \| Lines executed:/i)
              expect(@output).to match(/Main\.c \| Lines executed:/i)
              expect(@output).to match(/Model\.c \| Lines executed:/i)
              # there are more, but this is a good place to stop.

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
              expect(@output).to match(/TESTED:\s+15/)
              expect(@output).to match(/PASSED:\s+15/)

              expect(@output).to match(/AdcConductor\.c \| Lines executed:/i)
              expect(@output).to match(/AdcHardware\.c \| Lines executed:/i)
              expect(@output).to match(/AdcModel\.c \| Lines executed:/i)
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
