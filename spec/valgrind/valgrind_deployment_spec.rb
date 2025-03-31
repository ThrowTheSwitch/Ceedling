# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'
require 'valgrind/valgrind_test_cases_spec'

describe "Ceedling" do
  describe "Valgrind" do
    include CeedlingTestCases
    include ValgrindTestCases
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

      it { can_test_projects_with_valgrind_with_success }
      it { can_test_projects_with_valgrind_with_fail }
      it { can_test_projects_with_valgrind_with_compile_error }
      it { can_fetch_project_help_for_valgrind }
    end

    describe "command: `ceedling example temp_sensor`" do
      describe "temp_sensor" do
        before do
          @c.with_context do
            output = `bundle exec ruby -S ceedling example temp_sensor 2>&1`
            expect(output).to match(/created/)

            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_valgrind test:all 2>&1`
              expect(@output).to match(/TESTED:\s+51/)
              expect(@output).to match(/PASSED:\s+51/)
            end
          end
        end

        it "should be testable" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_valgrind valgrind:all 2>&1`
              expect(@output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
              expect(@output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
            end
          end
        end

        it "should be able to test a single module (it should INHERIT file-specific flags)" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_valgrind valgrind:TemperatureCalculator 2>&1`
              expect(@output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
              expect(@output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
            end
          end
        end

        it "should be able to test multiple files matching a pattern" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_valgrind valgrind:pattern[Temp] 2>&1`
              expect(@output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
              expect(@output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
            end
          end
        end

        it "should be able to test all files matching in a path" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_valgrind valgrind:path[adc] 2>&1`
              expect(@output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
              expect(@output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
            end
          end
        end

        it "should be able to test specific test cases in a file" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_valgrind valgrind:path[adc] --test-case="RunShouldNot" 2>&1`
              expect(@output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
              expect(@output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
            end
          end
        end
      end
    end
  end
end
