# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Upgrade Smoke
## ===============
##
## Like deployment_as_vendor_spec.rb, this doesn't repeat the full
## CommonSystemTestCases battery -- deployment_as_gem_spec.rb already proves
## that install-mode-agnostic behavior once. What's unique to this file is
## the two-phase shape itself (scaffold a vendored project, then upgrade it
## in place) and `ceedling upgrade`'s own operations, which nothing else in
## the suite exercises at all:
##
##   - can_upgrade_projects / can_upgrade_projects_with_no_test_support_folder
##     are the only tests that invoke `ceedling upgrade` and assert success.
##   - cannot_upgrade_non_existing_project is the only coverage of the
##     upgrade failure path.
##
## A lean pre/post test_project_success pair brackets the upgrade itself --
## proving a real build still works both before and after is arguably this
## file's single most important assertion, since it's the one thing that
## would catch an upgrade silently breaking a project's ability to build at
## all, which none of the operation-specific assertions above would notice.
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

  before { @proj_name = unique_proj_name("upgrade") }

  describe "Upgrade a project's `vendor` directory" do
    before { @c.with_context { @c.ceedling_appcmd_exec("new --local #{@proj_name}") } }

    describe "Initial project state" do
      describe "Project creation" do
        test_case :can_create_projects
        test_case :contains_a_vendor_directory
        test_case :does_not_contain_documentation
      end

      describe "Basic test execution" do
        test_case :test_project_success
      end
    end

    describe "After upgrade" do
      describe "Upgrade operations" do
        test_case :can_upgrade_projects
        test_case :can_upgrade_projects_with_no_test_support_folder
      end

      describe "Project structure" do
        test_case :contains_a_vendor_directory
        test_case :does_not_contain_documentation
      end

      describe "Basic test execution" do
        test_case :test_project_success
      end
    end
  end

  describe "Upgrade error handling" do
    test_case :cannot_upgrade_non_existing_project
  end
end
