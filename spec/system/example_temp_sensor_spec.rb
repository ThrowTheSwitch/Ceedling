# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

describe "Ceedling" do
  include CeedlingTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "temp_sensor" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "command: `ceedling examples`" do
    before do
      @c.with_context do
        @output = `bundle exec ruby -S ceedling examples 2>&1`
      end
    end

    it "should list out all the examples" do
      expect(@output).to match(/temp_sensor/)
    end
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
            @output = `bundle exec ruby -S ceedling test:all 2>&1`
            expect(@output).to match(/TESTED:\s+51/)
            expect(@output).to match(/PASSED:\s+51/)
          end
        end
      end

      it "should be able to test a single module (it includes file-specific flags)" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:TemperatureCalculator 2>&1`
            expect(@output).to match(/TESTED:\s+2/)
            expect(@output).to match(/PASSED:\s+2/)

            expect(@output).to match(/TemperatureCalculator\.out/i)
          end
        end
      end

      it "should be able to test multiple files matching a pattern" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:pattern[Temp] 2>&1`
            expect(@output).to match(/TESTED:\s+6/)
            expect(@output).to match(/PASSED:\s+6/)

            expect(@output).to match(/TemperatureCalculator\.out/i)
            expect(@output).to match(/TemperatureFilter\.out/i)
          end
        end
      end

      it "should be able to test all files matching in a path" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:path[adc] 2>&1`
            expect(@output).to match(/TESTED:\s+15/)
            expect(@output).to match(/PASSED:\s+15/)

            expect(@output).to match(/AdcModel\.out/i)
            expect(@output).to match(/AdcHardware\.out/i)
            expect(@output).to match(/AdcConductor\.out/i)
          end
        end
      end

      it "should be able to test specific test cases in a file" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:path[adc] --test-case="RunShouldNot" 2>&1`
            expect(@output).to match(/TESTED:\s+2/)
            expect(@output).to match(/PASSED:\s+2/)

            expect(@output).to match(/AdcModel\.out/i)
            expect(@output).to match(/AdcHardware\.out/i)
            expect(@output).to match(/AdcConductor\.out/i)
          end
        end
      end

      it "should be able to test when using a custom Unity Helper file added by relative-path mixin" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:all --verbosity=obnoxious --mixin=mixin/add_unity_helper.yml 2>&1`
            expect(@output).to match(/Merging command line mixin using mixin\/add_unity_helper\.yml/)
            expect(@output).to match(/TESTED:\s+51/)
            expect(@output).to match(/PASSED:\s+51/)
          end
        end
      end

      it "should be able to test when using a custom Unity Helper file added by simple-named mixin" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:all --verbosity=obnoxious --mixin=add_unity_helper 2>&1`
            expect(@output).to match(/Merging command line mixin using mixin\/add_unity_helper\.yml/)
            expect(@output).to match(/TESTED:\s+51/)
            expect(@output).to match(/PASSED:\s+51/)
          end
        end
      end

      it "should be able to test when using a custom Unity Helper file added by env-named mixin" do
        @c.with_context do
          ENV['CEEDLING_MIXIN_1'] = 'mixin/add_unity_helper.yml'
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling test:all --verbosity=obnoxious 2>&1`
            expect(@output).to match(/Merging CEEDLING_MIXIN_1 mixin using mixin\/add_unity_helper\.yml/)
            expect(@output).to match(/TESTED:\s+51/)
            expect(@output).to match(/PASSED:\s+51/)
          end
        end
      end

      it "should be able to report the assembly files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling files:assembly 2>&1`

            expect(@output).to match(/Assembly files: None/i)
          end
        end
      end

      it "should be able to report the header files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling files:header 2>&1`

            expect(@output).to match(/Header files:/i)
            expect(@output).to match(/src\/AdcModel\.h/i)
            expect(@output).to match(/src\/AdcHardware\.h/i)
            expect(@output).to match(/src\/AdcConductor\.h/i)
            expect(@output).to match(/src\/Main\.h/i)
            expect(@output).to match(/src\/UsartTransmitBufferStatus\.h/i)
            #and many more

            expect(@output).to match(/test\/support\/UnityHelper\.h/i)
          end
        end
      end

      it "should be able to report the source files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling files:source 2>&1`

            expect(@output).to match(/Source files:/i)
            expect(@output).to match(/src\/AdcModel\.c/i)
            expect(@output).to match(/src\/AdcHardware\.c/i)
            expect(@output).to match(/src\/AdcConductor\.c/i)
            expect(@output).to match(/src\/Main\.c/i)
            expect(@output).to match(/src\/UsartTransmitBufferStatus\.c/i)
            #and many more

            expect(@output).not_to match(/test\/support\/UnityHelper\.c/i)
          end
        end
      end

      it "should be able to report the support files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling files:support 2>&1`

            expect(@output).to match(/Support files:/i)
            expect(@output).to match(/test\/support\/UnityHelper\.c/i)
          end
        end
      end

      it "should be able to report the test files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling files:test 2>&1`

            expect(@output).to match(/Test files:/i)
            expect(@output).to match(/test\/adc\/TestAdcModel\.c/i)
            expect(@output).to match(/test\/adc\/TestAdcHardware\.c/i)
            expect(@output).to match(/test\/adc\/TestAdcConductor\.c/i)
            expect(@output).to match(/test\/TestMain\.c/i)
            expect(@output).to match(/test\/TestUsartBaudRateRegisterCalculator.c/i)
          end
        end
      end

      it "should be able to report the header paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling paths:include 2>&1`

            expect(@output).to match(/Include paths:/i)
            expect(@output).to match(/src/i)
          end
        end
      end

      it "should be able to report the source paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling paths:source 2>&1`

            expect(@output).to match(/Source paths:/i)
            expect(@output).to match(/src/i)
          end
        end
      end

      it "should be able to report the support paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling paths:support 2>&1`

            expect(@output).to match(/Support paths:/i)
            expect(@output).to match(/test\/support/i)
          end
        end
      end

      it "should be able to report the test paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = `bundle exec ruby -S ceedling paths:test 2>&1`

            expect(@output).to match(/Test paths:/i)
            expect(@output).to match(/test/i)
            expect(@output).to match(/test\/adc/i)

            expect(@output).not_to match(/test\/support/i)
          end
        end
      end

    end
  end
end
