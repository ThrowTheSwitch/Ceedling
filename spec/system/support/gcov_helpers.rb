# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'yaml'

module GcovHelpers

  def determine_reports_to_test
    @gcov_reports = []

    begin
      `gcovr --version 2>&1`
      @gcov_reports << :gcovr if $?.exitstatus == 0
    rescue
      puts "No GCOVR exec to test against"
    end

    begin
      `reportgenerator --version 2>&1`
      @gcov_reports << :reportgenerator if $?.exitstatus == 0
    rescue
      puts "No ReportGenerator exec to test against"
    end
  end

  def prep_project_yml_for_coverage
    FileUtils.cp test_asset_path("project.yml"), "project.yml"
    @c.uncomment_project_yml_option_for_test("- gcov")
    @c.comment_project_yml_option_for_test("- gcovr") unless @gcov_reports.include? :gcovr
    @c.uncomment_project_yml_option_for_test("- ReportGenerator") if @gcov_reports.include? :reportgenerator
  end

  def _add_gcov_section_in_project(project_file_path, name, values)
    project_file_contents = File.readlines(project_file_path)
    name_index = project_file_contents.index(":gcov:\n")

    if name_index.nil?
      # Something wrong with project.yml file, no project section?
      return
    end

    project_file_contents.insert(name_index + 1, "  :#{name}:\n")
    values.each.with_index(2) do |value, index|
      project_file_contents.insert(name_index + index, "    - #{value}\n")
    end

    File.open(project_file_path, "w+") do |f|
      f.puts(project_file_contents)
    end
  end

  def _add_gcov_option_in_project(project_file_path, option, value)
    project_file_contents = File.readlines(project_file_path)
    option_index = project_file_contents.index(":gcov:\n")

    if option_index.nil?
      # Something wrong with project.yml file, no project section?
      return
    end

    project_file_contents.insert(option_index + 1, "  :#{option}: #{value}\n")

    File.open(project_file_path, "w+") do |f|
      f.puts(project_file_contents)
    end
  end

  def add_gcov_section(name, values)
    _add_gcov_section_in_project("project.yml", name, values)
  end

  def add_gcov_option(option, value)
    _add_gcov_option_in_project("project.yml", option, value)
  end

end
