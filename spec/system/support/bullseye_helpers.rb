# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

module BullseyeHelpers

  PROJECT_FILE = 'project.yml'

  # Copies the feature project file into place and enables the Bullseye plugin.
  # Mirrors GcovHelpers#prep_project_yml_for_coverage. Bullseye needs no equivalent
  # of gcov's report-utility probing, because its reporting tools ship with Bullseye
  # itself rather than being separately installable.
  def prep_project_yml_for_coverage
    FileUtils.cp feature_asset_path(PROJECT_FILE), PROJECT_FILE
    @c.uncomment_project_yml_option_for_test('- bullseye')
  end

  # Copies the partially-covered branch fixture into a prepared project.
  # See assets/fixtures/bullseye_branch_coverage/src/branchy.c for why its coverage
  # numbers are stable enough to assert against.
  def copy_branch_coverage_fixture
    asset_base = test_asset_path('bullseye_branch_coverage')
    FileUtils.cp "#{asset_base}/src/branchy.h",       'src/'
    FileUtils.cp "#{asset_base}/src/branchy.c",       'src/'
    FileUtils.cp "#{asset_base}/test/test_branchy.c", 'test/'
  end

  # Adds a simple scalar option to the project file's :bullseye: section.
  def add_bullseye_option(option, value)
    insert_into_bullseye_section(["  :#{option}: #{value}\n"])
  end

  # Adds a nested option to the project file's :bullseye: section.
  # values is a hash of sub-key => value, e.g. :fail_under with function and
  # branch minimums.
  def add_bullseye_nested_option(option, values)
    lines = ["  :#{option}:\n"]
    values.each { |key, value| lines << "    :#{key}: #{value}\n" }
    insert_into_bullseye_section(lines)
  end

  private

  # Inserts lines directly beneath the project file's :bullseye: section, creating
  # that section first if it is absent.
  #
  # A new section is placed before the YAML end-of-document marker. Content after
  # that marker belongs to no document and is silently ignored.
  def insert_into_bullseye_section(lines)
    contents = File.readlines(PROJECT_FILE)

    section_index = contents.index(":bullseye:\n")

    if section_index.nil?
      end_marker_index = contents.rindex("...\n") || contents.length
      contents.insert(end_marker_index, ":bullseye:\n")
      section_index = contents.index(":bullseye:\n")
    end

    contents.insert(section_index + 1, *lines)

    File.open(PROJECT_FILE, 'w') { |f| f.puts(contents) }
  end

end
