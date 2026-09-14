# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## `files:*` / `paths:*` task reporting
## =======================================
##
## Before this file, this output was proven three times over -- once each in
## example_temp_sensor_spec.rb, example_cipher_quest_spec.rb, and
## example_wondrous_forest_spec.rb -- always as an incidental side effect of
## those files' own project-specific coverage, never as its own concern.
## Consolidated here against a single canonical fixture (temp_sensor -- already
## the suite's de facto standard, with the richest src/test/support/paths
## layout of the three example projects) so this reporting logic has one real
## home instead of three redundant echoes.
##
## `files:assembly` gets its own example (asserting "None") because it's a
## genuinely distinct check -- does the task run cleanly and report correctly
## on a project with no assembly sources at all -- separate from any project
## that has assembly files to discover in the first place (none of the three
## example projects do).
##

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "temp_sensor" }

  before do
    @c.with_context do
      output = @c.ceedling_appcmd_exec("example temp_sensor")
      expect(output).to match(/created/)
    end
  end

  describe "Command: `ceedling files:*`" do
    it "reports no assembly files for a project with none" do
      in_project do
        @output = @c.ceedling_build_exec("files:assembly")
        expect(@output).to match(/Assembly files: None/i)
      end
    end

    it "reports the header files found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("files:header")

        # Incomplete (i.e. spot check) of header files
        expect(@output).to match(/Header files:/i)
        expect(@output).to match(/src\/AdcModel\.h/i)
        expect(@output).to match(/src\/AdcHardware\.h/i)
        expect(@output).to match(/src\/AdcConductor\.h/i)
        expect(@output).to match(/src\/Main\.h/i)
        expect(@output).to match(/src\/UsartTransmitBufferStatus\.h/i)
        expect(@output).to match(/test\/support\/UnityHelper\.h/i)
      end
    end

    it "reports the source files found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("files:source")

        # Incomplete (i.e. spot check) of source files
        expect(@output).to match(/Source files:/i)
        expect(@output).to match(/src\/AdcModel\.c/i)
        expect(@output).to match(/src\/AdcHardware\.c/i)
        expect(@output).to match(/src\/AdcConductor\.c/i)
        expect(@output).to match(/src\/Main\.c/i)
        expect(@output).to match(/src\/UsartTransmitBufferStatus\.c/i)

        expect(@output).not_to match(/test\/support\/UnityHelper\.c/i)
      end
    end

    it "reports the support files found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("files:support")

        expect(@output).to match(/Support files:/i)
        expect(@output).to match(/test\/support\/UnityHelper\.c/i)
        expect(@output).to match(/test\/platform\/at91sam7s256\.c/i)
      end
    end

    it "reports the test files found in paths" do
      in_project do
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

  describe "Command: `ceedling paths:*`" do
    it "reports the include paths found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("paths:include")

        expect(@output).to match(/Include paths:/i)
        expect(@output).to match(/src/i)
      end
    end

    it "reports the source paths found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("paths:source")

        expect(@output).to match(/Source paths:/i)
        expect(@output).to match(/src/i)
      end
    end

    it "reports the support paths found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("paths:support")

        expect(@output).to match(/Support paths:/i)
        expect(@output).to match(/test\/support/i)
        expect(@output).to match(/test\/platform/i)
      end
    end

    it "reports the test paths found in paths" do
      in_project do
        @output = @c.ceedling_build_exec("paths:test")

        expect(@output).to match(/Test paths:/i)
        expect(@output).to match(/test/i)
        expect(@output).to match(/test\/adc/i)

        expect(@output).not_to match(/test\/support/i)
      end
    end
  end
end
