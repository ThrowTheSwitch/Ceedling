# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

module ValgrindHelpers

  # valgrind_available? lives in spec_system_helper.rb beside the other tool probes,
  # paired with the "requires valgrind" shared context.

  def prep_project_yml_for_valgrind
    FileUtils.cp feature_asset_path("project.yml"), "project.yml"
    @c.uncomment_project_yml_option_for_test("- valgrind")
  end

end
