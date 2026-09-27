# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

module CppcheckHelpers

  # cppcheck_available? lives in spec_system_helper.rb beside the other tool probes,
  # paired with the "requires cppcheck" shared context.

  # Copies a source Cppcheck reports exactly one error-severity finding for.
  # See assets/fixtures/cppcheck_findings/findings.c.
  def copy_cppcheck_findings_fixture
    asset_base = test_asset_path('cppcheck_findings')
    FileUtils.cp "#{asset_base}/findings.h", 'src/'
    FileUtils.cp "#{asset_base}/findings.c", 'src/'
  end

  def prep_project_yml_for_cppcheck(reports: [:text])
    FileUtils.cp feature_asset_path("project.yml"), "project.yml"
    @c.uncomment_project_yml_option_for_test("- cppcheck")
    @c.merge_project_yml_for_test({cppcheck: {reports: reports}})
  end

end
