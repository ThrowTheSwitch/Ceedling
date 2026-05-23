# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

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
  after  { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "Command: `ceedling examples`" do
    before do
      @c.with_context do
        @output = @c.ceedling_appcmd_exec("examples")
      end
    end

    it "should list wondrous_forest as an available example" do
      expect(@output).to match(/wondrous_forest/)
    end
  end

  describe "Command: `ceedling example wondrous_forest`" do
    describe "wondrous_forest" do
      before do
        @c.with_context do
          output = @c.ceedling_appcmd_exec("example wondrous_forest")
          expect(output).to match(/created/)
        end
      end

      it "should be testable with all tests passing" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("test:all")
            expect(@output).to match(/TESTED:\s+65/)
            expect(@output).to match(/PASSED:\s+65/)
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

      it "should be able to test multiple modules matching a pattern" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("test:pattern[Sensor]")
            expect(@output).to match(/PASSED/)
            expect(@output).to match(/TemperatureSensor\.out/i)
            expect(@output).to match(/HumiditySensor\.out/i)
            expect(@output).to match(/LightSensor\.out/i)
          end
        end
      end

      it "should be able to report header files" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("files:header")
            expect(@output).to match(/Header files:/i)
            expect(@output).to match(/TemperatureSensor\.h/i)
            expect(@output).to match(/AlertManager\.h/i)
            expect(@output).to match(/EventQueue\.h/i)
            expect(@output).to match(/ForestMonitor\.h/i)
          end
        end
      end

      it "should be able to report source files" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("files:source")
            expect(@output).to match(/Source files:/i)
            expect(@output).to match(/TemperatureSensor\.c/i)
            expect(@output).to match(/SensorHal\.c/i)
            expect(@output).to match(/ForestMonitor\.c/i)
          end
        end
      end

      it "should be able to report test files" do
        @c.with_context do
          Dir.chdir "wondrous_forest" do
            @output = @c.ceedling_build_exec("files:test")
            expect(@output).to match(/Test files:/i)
            expect(@output).to match(/TestTemperatureSensor\.c/i)
            expect(@output).to match(/TestAlertManager\.c/i)
            expect(@output).to match(/TestForestMonitor\.c/i)
          end
        end
      end
    end
  end
end
