# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Vendored Deployment Smoke
## ===========================
##
## `deployment_as_gem_spec.rb` runs the full CommonSystemTestCases feature
## battery once, under the default (gem) install mode -- preprocessing,
## Partials, defines, Unity features, crash handling, verbosity, and test
## filtering are all install-mode-agnostic (the same build/runtime logic runs
## identically whether Ceedling's own files are gem-installed or vendored
## into the project), so repeating that whole battery here a second (or
## third) time under each vendored scaffold variant would only be
## re-verifying behavior that install mode can't affect.
##
## What genuinely differs by scaffold variant -- does `--local`/`--docs`/
## `--gitsupport` produce the right files, and does a real build actually run
## against the vendored copy (a broken vendored $LOAD_PATH is exactly the
## kind of thing file-presence checks alone wouldn't catch) -- keeps its own
## dedicated coverage below, once per variant. Not "a fresh ceedling gem
## project" (spec_system_helper.rb) here -- that shared context always
## scaffolds a plain `new`, but every describe block below needs its own
## differently-flagged `new --local ...` variant instead.
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

  before { @proj_name = unique_proj_name("vendor") }

  describe "Deployed in a project's `vendor` directory" do
    before { @c.with_context { @c.ceedling_appcmd_exec("new --local --docs #{@proj_name}") } }

    describe "Project creation" do
      test_case :can_create_projects
      test_case :contains_a_vendor_directory
      test_case :contains_documentation
    end

    describe "Basic test execution" do
      test_case :test_project_success
    end
  end

  describe "Deployed in a project's `vendor` directory with Git support" do
    before { @c.with_context { @c.ceedling_appcmd_exec("new --local --docs --gitsupport #{@proj_name}") } }

    describe "Project creation" do
      test_case :can_create_projects
      test_case :has_git_support
      test_case :contains_a_vendor_directory
      test_case :contains_documentation
    end

    describe "Basic test execution" do
      test_case :test_project_success
    end
  end

  describe "Deployed in a project's `vendor` directory without docs" do
    before { @c.with_context { @c.ceedling_appcmd_exec("new --local #{@proj_name}") } }

    describe "Project creation" do
      test_case :can_create_projects
      test_case :contains_a_vendor_directory
      test_case :does_not_contain_documentation
    end

    describe "Basic test execution" do
      test_case :test_project_success
    end
  end
end
