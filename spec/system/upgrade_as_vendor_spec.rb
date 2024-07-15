# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

  before { @proj_name = "fake_project" }
  after { @c.with_context { FileUtils.rm_rf @proj_name } }

  describe "upgrade a project's `vendor` directory" do
    before do
      @c.with_context do
        `bundle exec ruby -S ceedling new --local #{@proj_name} 2>&1`
      end
    end

    it { can_create_projects }
    it { contains_a_vendor_directory }
    it { does_not_contain_documentation }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }

    it { can_upgrade_projects }
    it { can_upgrade_projects_even_if_test_support_folder_does_not_exist }
    it { contains_a_vendor_directory }
    it { does_not_contain_documentation }
    it { can_fetch_non_project_help }
    it { can_fetch_project_help }
    it { can_test_projects_with_success }
    it { can_test_projects_with_success_test_alias }
    it { can_test_projects_with_success_default }
    it { can_test_projects_with_unity_exec_time }
    it { can_test_projects_with_test_and_vendor_defines_with_success }
    it { can_test_projects_with_fail }
    it { can_test_projects_with_fail_alias }
    it { can_test_projects_with_fail_default }
    it { can_test_projects_with_compile_error }
  end

  describe "Cannot upgrade a non existing project" do
    it { cannot_upgrade_non_existing_project }
  end

end
