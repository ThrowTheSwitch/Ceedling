# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## temp_sensor Example Project
## =============================
##
## `files:*`/`paths:*` reporting, previously checked here too, now lives
## solely in files_paths_reporting_spec.rb, built against this same fixture --
## nothing about that output is temp_sensor-specific, so repeating it here
## added nothing. `test:TemperatureCalculator` (single-module test) and
## `test:pattern[Temp]` (pattern test) are dropped as redundant with
## example_wondrous_forest_spec.rb's `test:SoilMoisture` and
## pinned_thread_count_spec.rb/delta_builds_spec.rb's own pattern-test
## coverage -- what's kept below is what's unique to this project: the
## examples-listing check (kept only here, dropped from the other two example
## specs), `test:all`, `test:path[]` and its `--test-case=` combination (the
## suite's sole coverage of `test:path[]` anywhere), and one mixin-loading
## smoke proving a real mixin's content reaches a real 86-test build --
## simple-named form only, since the relative-path and CEEDLING_MIXIN_1
## variants are now covered as *mechanisms* by
## spec/integration/mixin_loading_spec.rb and mixin_ordering_spec.rb.
##

ceedling_system_tests do
  include CommonSystemTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "temp_sensor" }

  describe "Command: `ceedling examples`" do
    before do
      @c.with_context do
        @output = @c.ceedling_appcmd_exec("examples")
      end
    end

    it "should list out all the examples" do
      expect(@output).to match(/temp_sensor/)
    end
  end

  describe "Command: `ceedling example temp_sensor`" do
    describe "temp_sensor" do
      before do
        @c.with_context do
          output = @c.ceedling_appcmd_exec("example temp_sensor")
          expect(output).to match(/created/)

          # `ceedling example` only overwrites src/, test/, mixin/, and project.yml --
          # it never touches build/. Without clobbering it here, a dependency cache
          # populated by an earlier example in this describe block would carry over
          # and make delta-build staleness tracking correctly (but unhelpfully, for
          # these tests) treat this "fresh" example as already fully built.
          Dir.chdir "temp_sensor" do
            @c.ceedling_build_exec("clobber")
          end
        end
      end

      it "should be testable" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:all")
            expect(@output).to match(/TESTED:\s+86/)
            expect(@output).to match(/PASSED:\s+86/)
          end
        end
      end

      it "should be able to test all files matching in a path" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:path[adc]")
            expect(@output).to match(/TESTED:\s+24/)
            expect(@output).to match(/PASSED:\s+24/)

            expect(@output).to match(/AdcModel\.out/i)
            expect(@output).to match(/AdcHardware\.out/i)
            expect(@output).to match(/AdcConductor\.out/i)
            expect(@output).to match(/AdcPlatformStandin\.out/i)
          end
        end
      end

      it "should be able to test specific test cases in a file" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec('test:path[adc] --test-case="RunShouldNot"')
            expect(@output).to match(/TESTED:\s+2/)
            expect(@output).to match(/PASSED:\s+2/)

            # Incomplete (i.e. spot check) of test executable builds
            expect(@output).to match(/AdcModel\.out/i)
            expect(@output).to match(/AdcHardware\.out/i)
            expect(@output).to match(/AdcConductor\.out/i)
          end
        end
      end

      it "should be able to test when using a custom Unity Helper file added by simple-named mixin" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:all --verbosity=obnoxious --mixin=add_unity_helper")
            expect(@output).to match(/Merging command line mixin using mixin\/add_unity_helper\.yml/)
            expect(@output).to match(/TESTED:\s+86/)
            expect(@output).to match(/PASSED:\s+86/)
          end
        end
      end

    end
  end
end
