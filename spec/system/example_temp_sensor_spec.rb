# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

      it "should be able to test a single module (it includes file-specific flags)" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:TemperatureCalculator")
            expect(@output).to match(/TESTED:\s+2/)
            expect(@output).to match(/PASSED:\s+2/)

            expect(@output).to match(/TemperatureCalculator\.out/i)
          end
        end
      end

      it "should be able to test multiple files matching a pattern" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:pattern[Temp]")
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

      it "should be able to test when using a custom Unity Helper file added by relative-path mixin" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:all --verbosity=obnoxious --mixin=mixin/add_unity_helper.yml")
            expect(@output).to match(/Merging command line mixin using mixin\/add_unity_helper\.yml/)
            expect(@output).to match(/TESTED:\s+86/)
            expect(@output).to match(/PASSED:\s+86/)
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

      it "should be able to test when using a custom Unity Helper file added by env-named mixin" do
        @c.with_context do
          ENV['CEEDLING_MIXIN_1'] = 'mixin/add_unity_helper.yml'
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("test:all --verbosity=obnoxious")
            expect(@output).to match(/Merging CEEDLING_MIXIN_1 mixin using mixin\/add_unity_helper\.yml/)
            expect(@output).to match(/TESTED:\s+86/)
            expect(@output).to match(/PASSED:\s+86/)
          end
        end
      end

      it "should be able to report the assembly files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("files:assembly")

            expect(@output).to match(/Assembly files: None/i)
          end
        end
      end

      it "should be able to report the header files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("files:header")

            # Incomplete (i.e. spot check) of header files
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
            @output = @c.ceedling_build_exec("files:source")

            # Incomplete (i.e. spot check) of source files
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
            @output = @c.ceedling_build_exec("files:support")

            expect(@output).to match(/Support files:/i)
            expect(@output).to match(/test\/support\/UnityHelper\.c/i)
            expect(@output).to match(/test\/platform\/at91sam7s256\.c/i)
          end
        end
      end

      it "should be able to report the test files found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("files:test")

            # Incomplete (i.e. spot check) of test files
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
            @output = @c.ceedling_build_exec("paths:include")

            expect(@output).to match(/Include paths:/i)
            expect(@output).to match(/src/i)
          end
        end
      end

      it "should be able to report the source paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("paths:source")

            expect(@output).to match(/Source paths:/i)
            expect(@output).to match(/src/i)
          end
        end
      end

      it "should be able to report the support paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("paths:support")

            expect(@output).to match(/Support paths:/i)
            expect(@output).to match(/test\/support/i)
            expect(@output).to match(/test\/platform/i)
          end
        end
      end

      it "should be able to report the test paths found in paths" do
        @c.with_context do
          Dir.chdir "temp_sensor" do
            @output = @c.ceedling_build_exec("paths:test")

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
