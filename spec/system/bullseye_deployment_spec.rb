# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================
#
# Gated by the "requires bullseye" shared context (see spec_system_helper.rb) —
# auto-skips everywhere without a real Bullseye license/installation.

require 'spec_system_helper'

# temp_sensor's project.yml has no :bullseye: section by default (only the plugin's
# own compiled-in defaults apply). Inserts a fresh :bullseye: section with the given
# option override, just before the YAML end-of-document marker.
def add_bullseye_option_to_project_yml(option, value)
  contents = File.readlines('project.yml')
  end_marker_index = contents.rindex("...\n")
  contents.insert(end_marker_index, ":bullseye:\n  :#{option}: #{value}\n\n")
  File.open('project.yml', 'w') { |f| f.puts(contents) }
end

ceedling_system_tests do
  describe "Bullseye" do
    include CommonSystemTestCases
    include_context "requires bullseye"

    before :all do
      @c = SystemContext.new
      @c.deploy_gem
    end

    after :all do
      @c.done!
    end

    before { @proj_name = unique_proj_name("bullseye") }

    describe "Basic operations" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      it "should run a passing test suite with coverage instrumentation" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("project.yml"), "project.yml"
            @c.uncomment_project_yml_option_for_test("- bullseye")

            FileUtils.cp test_asset_path("example_file.h"), 'src/'
            FileUtils.cp test_asset_path("example_file.c"), 'src/'
            FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

            output = `bundle exec ruby -S ceedling bullseye:all 2>&1`
            expect($?.exitstatus).to eq(0)
            expect(output).to match(/TESTED:\s+\d/)
            expect(output).to match(/PASSED:\s+\d/)
            expect(output).to match(/FAILED:\s+\d/)
            expect(output).to match(/IGNORED:\s+\d/)

            expect(File.exist?('test.cov')).to eq true
            expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
          end
        end
      end

      it "should report a failing test suite" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("project.yml"), "project.yml"
            @c.uncomment_project_yml_option_for_test("- bullseye")

            FileUtils.cp test_asset_path("example_file.h"), 'src/'
            FileUtils.cp test_asset_path("example_file.c"), 'src/'
            FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

            output = `bundle exec ruby -S ceedling bullseye:all 2>&1`
            expect($?.exitstatus).to eq(1)
            expect(output).to match(/FAILED:\s+[1-9]/)
          end
        end
      end
    end

    describe "Command: `ceedling example temp_sensor`" do
      describe "temp_sensor" do
        before do
          @c.with_context do
            FileUtils.rm_rf('temp_sensor')
            output = `bundle exec ruby -S ceedling example temp_sensor 2>&1`
            expect(output).to match(/created/)
          end
        end

        it "should be testable" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:all 2>&1`
              # Validate full test suite results
              expect(@output).to match(/TESTED:\s+86/)
              expect(@output).to match(/PASSED:\s+86/)

              # Incomplete (i.e. spot check) per-function coverage reporting validation
              expect(@output).to match(/TemperatureCalculator_Calculate\(uint16\)/)
              expect(@output).to match(/AdcConductor_Run\(void\)/)
              expect(@output).to match(/UsartConductor_Run\(void\)/)

              # Aggregate console summary
              expect(@output).to match(/FUNCTIONS:\s+\d+%/)
              expect(@output).to match(/BRANCHES:\s+\d+%/)

              expect(File.exist?('test.cov')).to eq true
              expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
            end
          end
        end

        it "should be able to test a single module (it should INHERIT file-specific flags)" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:TemperatureCalculator 2>&1`
              expect(@output).to match(/TESTED:\s+2/)
              expect(@output).to match(/PASSED:\s+2/)

              expect(@output).to match(/TemperatureCalculator_Calculate\(uint16\)/)
            end
          end
        end

        it "should be able to test multiple files matching a pattern" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:pattern[Temp] 2>&1`
              expect(@output).to match(/TESTED:\s+6/)
              expect(@output).to match(/PASSED:\s+6/)

              expect(@output).to match(/TemperatureCalculator_Calculate\(uint16\)/)
            end
          end
        end

        it "should be able to test all files matching in a path" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:path[adc] 2>&1`
              expect(@output).to match(/TESTED:\s+24/)
              expect(@output).to match(/PASSED:\s+24/)

              expect(@output).to match(/AdcConductor_Run\(void\)/)
            end
          end
        end

        it "should list untested sources without compiling them by default" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              # Only the `all` task calls process_untested_sources — matching gcov's
              # own design, where this same accounting only happens for a full run.
              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:all 2>&1`
              expect(@output).to match(/Untested source files not in the coverage report/)
              expect(@output).to match(/IntrinsicsWrapper\.c/)
            end
          end
        end

        it "should compile untested sources on demand via the standalone task" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              add_bullseye_option_to_project_yml('untested_sources', ':compile')

              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:untested_sources 2>&1`
              expect(@output).to match(/Compiling with coverage IntrinsicsWrapper\.c/)
            end
          end
        end

        it "should generate an HTML report on demand instead of automatically when :report_task is enabled" do
          @c.with_context do
            Dir.chdir "temp_sensor" do
              add_bullseye_option_to_project_yml('report_task', 'TRUE')

              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye bullseye:all 2>&1`
              expect(@output).not_to match(/Bullseye HTML coverage report/)

              @output = `bundle exec ruby -S ceedling --mixin=add_bullseye report:bullseye 2>&1`
              expect(@output).to match(/Bullseye HTML coverage report/)
              expect(File.exist?(File.join('build', 'artifacts', 'bullseye', 'covhtml', 'index.html'))).to eq true
            end
          end
        end
      end
    end
  end
end
