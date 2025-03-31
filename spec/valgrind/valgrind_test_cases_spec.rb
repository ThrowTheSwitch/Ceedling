# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'spec_system_helper'
require 'pp'

module ValgrindTestCases
  def determine_reports_to_test
    @valgrind_reports = []

    begin
      `valgrind --version 2>&1`
      @valgrind_reports << :valgrind if $?.exitstatus == 0
    rescue
      puts "No Valgrind exec to test against"
    end
  end

  def prep_project_yml_for_valgrind
    FileUtils.cp test_asset_path("project_as_gem.yml"), "project.yml"
    @c.uncomment_project_yml_option_for_test("- valgrind")
  end

  def can_test_projects_with_valgrind_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(0)

        output = `bundle exec ruby -S ceedling valgrind:all 2>&1`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
        expect(output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
      end
    end
  end

  def can_test_projects_with_valgrind_with_fail
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1)

        output = `bundle exec ruby -S ceedling valgrind:all 2>&1`
        expect($?.exitstatus).to match(1)
        expect(output).to match(/==\d+== All heap blocks were freed -- no leaks are possible/)
        expect(output).to match(/==\d+== ERROR SUMMARY: 0 errors from 0 contexts/)
      end
    end
  end

  def can_test_projects_with_valgrind_with_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1)

        output = `bundle exec ruby -S ceedling valgrind:all 2>&1`
        expect($?.exitstatus).to match(1)
        expect(output).to match(/(?:ERROR: Ceedling Failed)|(?:Ceedling could not complete operations because of errors)/)
      end
    end
  end

  def can_fetch_project_help_for_valgrind
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        output = `bundle exec ruby -S ceedling help 2>&1`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/ceedling valgrind:\*/i)
        expect(output).to match(/ceedling valgrind:all/i)
      end
    end
  end
end
