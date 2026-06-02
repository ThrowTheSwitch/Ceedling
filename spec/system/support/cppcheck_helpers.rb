# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

module CppcheckHelpers

  def cppcheck_available?
    begin
      `cppcheck --version 2>&1`
      $?.exitstatus == 0
    rescue
      false
    end
  end

  def prep_project_yml_for_cppcheck(reports: [:text])
    FileUtils.cp test_asset_path("project.yml"), "project.yml"
    @c.uncomment_project_yml_option_for_test("- cppcheck")
    @c.merge_project_yml_for_test({cppcheck: {reports: reports}})
  end

end
