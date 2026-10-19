# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

module SanitizeHelpers

  # sanitizers_available? and leak_detection_available? live in spec_system_helper.rb beside
  # the other tool probes, paired with their "requires ..." shared contexts.

  def prep_project_yml_for_sanitize
    FileUtils.cp feature_asset_path("project.yml"), "project.yml"
    @c.uncomment_project_yml_option_for_test("- sanitize")
  end

  # The module every sanitize fixture tests, plus the fixtures named
  def prep_sanitize_sources(*fixtures)
    FileUtils.cp test_asset_path("example_file.h"), 'src/'
    FileUtils.cp test_asset_path("example_file.c"), 'src/'
    fixtures.each { |fixture| FileUtils.cp test_asset_path(fixture), 'test/' }
  end

end
