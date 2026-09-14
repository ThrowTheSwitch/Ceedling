# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## wondrous_forest Example Project
## ==================================
##
## `files:*`/`paths:*` reporting, previously checked here too, now lives
## solely in files_paths_reporting_spec.rb. The examples-listing check is
## dropped as redundant (kept only in example_temp_sensor_spec.rb), and
## `test:pattern[Sensor]` is dropped as redundant with
## pinned_thread_count_spec.rb/delta_builds_spec.rb's own pattern-test
## coverage. What's left: `test:all`, and `test:SoilMoisture`, which becomes
## the suite's sole remaining single-module-test example (a promotion, not a
## loss -- temp_sensor's equivalent was trimmed in favor of this one).
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

  before { @proj_name = "wondrous_forest" }

  describe "Command: `ceedling example wondrous_forest`" do
    describe "wondrous_forest" do
      before do
        @c.with_context do
          output = @c.ceedling_appcmd_exec("example wondrous_forest")
          expect(output).to match(/created/)

          # `ceedling example` only overwrites src/, test/, mixin/, and project.yml --
          # it never touches build/. Without clobbering it here, a dependency cache
          # populated by an earlier example in this describe block would carry over
          # and make delta-build staleness tracking correctly (but unhelpfully, for
          # these tests) treat this "fresh" example as already fully built.
          Dir.chdir "wondrous_forest" do
            @c.ceedling_build_exec("clobber")
          end
        end
      end

      it "should be testable with all tests passing" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("test:all")
            expect(@output).to match(/TESTED:\s+68/)
            expect(@output).to match(/PASSED:\s+68/)
            expect(@output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "should be able to test a single module" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("test:SoilMoisture")
            expect(@output).to match(/TESTED:\s+7/)
            expect(@output).to match(/PASSED:\s+7/)
            expect(@output).to match(/SoilMoisture\.out/i)
          end
        end
      end

    end
  end
end
