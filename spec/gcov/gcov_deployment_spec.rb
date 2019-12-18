require 'spec_system_helper'
require 'gcov/gcov_test_cases_spec'

describe "Ceedling" do
  describe "Gcov" do
    include CeedlingTestCases
    include GcovTestCases
    before :all do
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
      it { can_test_projects_with_gcov_with_fail_because_of_uncovered_files }
      it { can_test_projects_with_gcov_with_success_because_of_ignore_uncovered_list }
      it { can_test_projects_with_gcov_with_compile_error }
      it { can_fetch_project_help_for_gcov }
      it { can_create_html_report }
    end


    describe "command: `ceedling example [example]`" do
      describe "temp_sensor" do
        before do
          @c.with_context do
            output = `bundle exec ruby -S ceedling example temp_sensor 2>&1`
            expect(output).to match(/created!/)
          end
        end

        it "should be testable" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling gcov:all 2>&1`
              expect(@output).to match(/TESTED:\s+47/)
              expect(@output).to match(/PASSED:\s+47/)

              expect(@output).to match(/AdcConductor\.c Lines executed:/i)
              expect(@output).to match(/AdcHardware\.c Lines executed:/i)
              expect(@output).to match(/AdcModel\.c Lines executed:/i)
              expect(@output).to match(/Executor\.c Lines executed:/i)
              expect(@output).to match(/Main\.c Lines executed:/i)
              expect(@output).to match(/Model\.c Lines executed:/i)
              # there are more, but this is a good place to stop.

              @output = `bundle exec ruby -S ceedling utils:gcov`
              expect(@output).to match(/For now, creating only an HtmlBasic report\./)
              expect(@output).to match(/Creating gcov results report\(s\) in 'build\/artifacts\/gcov'\.\.\. Done/)
              expect(File.exists?('build/artifacts/gcov/GcovCoverageResults.html')).to eq true

            end
          end
        end
      end
    end
  end
end
