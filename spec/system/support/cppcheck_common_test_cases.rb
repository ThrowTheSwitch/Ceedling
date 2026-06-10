# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'cppcheck_helpers'

module CppcheckCommonTestCases
  include CppcheckHelpers

  def can_fetch_project_help_for_cppcheck
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck
        output = @c.ceedling_appcmd_exec("help")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/ceedling cppcheck:\*/i)
        expect(output).to match(/ceedling cppcheck:all/i)
        expect(output).to match(/ceedling files:cppcheck/i)
      end
    end
  end

  def can_run_cppcheck_on_whole_project
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [:text])
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'

        output = @c.ceedling_build_exec("cppcheck:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Creating Cppcheck text report/i)
      end
    end
  end

  def can_run_cppcheck_on_single_file
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [:text])
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'

        output = @c.ceedling_build_exec("cppcheck:example_file.c")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Running Cppcheck on file/i)
        expect(output).to match(/example_file\.c/i)
      end
    end
  end

  def can_list_cppcheck_suppression_files
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck
        output = @c.ceedling_build_exec("files:cppcheck")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Cppcheck suppression files/i)
      end
    end
  end

  def can_create_xml_report
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [:xml])
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'

        output = @c.ceedling_build_exec("cppcheck:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Creating Cppcheck xml report/i)
        expect(File.exist?('build/artifacts/cppcheck/CppcheckReport.xml')).to eq(true)
        expect(File.size('build/artifacts/cppcheck/CppcheckReport.xml')).to be > 0
      end
    end
  end

  def can_create_text_report
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [:text])
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'

        output = @c.ceedling_build_exec("cppcheck:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Creating Cppcheck text report/i)
        expect(File.exist?('build/artifacts/cppcheck/CppcheckReport.txt')).to eq(true)
        expect(File.size('build/artifacts/cppcheck/CppcheckReport.txt')).to be > 0
      end
    end
  end

end
