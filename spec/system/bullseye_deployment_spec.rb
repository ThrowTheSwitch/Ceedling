# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================
#
# Gated by the "requires bullseye" shared context (see spec_system_helper.rb).
# Auto-skips everywhere without a real, licensed Bullseye installation.
# See docs/mkdocs/plugins/bullseye/licensing.md for installing Bullseye into the
# madsciencelab-plugins container to run these locally.

require 'spec_system_helper'
require_relative 'support/bullseye_common_test_cases'

ceedling_system_tests do
  describe "Bullseye" do
    include CommonSystemTestCases
    include BullseyeCommonTestCases
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

      test_case :bullseye_success
      test_case :bullseye_fail
      test_case :bullseye_license_status_task
    end

    describe "Branch coverage detail" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :bullseye_branch_detail_disabled_by_default
      test_case :bullseye_branch_detail_uncovered
      test_case :bullseye_branch_detail_all
      test_case :bullseye_branch_detail_rejects_unknown_value
    end

    describe "XML reporting" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :bullseye_xml_report_disabled_by_default
      test_case :bullseye_xml_report_cobertura
      test_case :bullseye_xml_report_native
    end

    describe "Coverage thresholds" do
      before do
        @c.with_context do
          @c.ceedling_appcmd_exec("new --local #{@proj_name}")
        end
      end

      test_case :bullseye_fail_under_met
      test_case :bullseye_fail_under_unmet
    end

    describe "Command: `ceedling example temp_sensor`" do
      before do
        @c.with_context do
          FileUtils.rm_rf('temp_sensor')
          output = @c.ceedling_appcmd_exec("example temp_sensor")
          expect(output).to match(/created/)
        end
      end

      test_case :temp_sensor_full_suite
      test_case :temp_sensor_single_module
      test_case :temp_sensor_pattern
      test_case :temp_sensor_path
      test_case :temp_sensor_untested_sources_list
      test_case :temp_sensor_untested_sources_compile
      test_case :temp_sensor_report_task
    end
  end
end
