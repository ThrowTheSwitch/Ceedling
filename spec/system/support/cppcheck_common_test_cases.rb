# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'cppcheck_helpers'

module CppcheckCommonTestCases
  include CppcheckHelpers

  def project_build_tasks_plugins_help_for_cppcheck
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

  # Cppcheck only runs as part of generating a report. With none configured this
  # task previously analyzed nothing and said nothing.
  def warns_when_no_reports_configured
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [])
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'

        output = @c.ceedling_build_exec("cppcheck:all")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/No Cppcheck reports are configured/i)
      end
    end
  end

  def reports_findings_by_severity
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [:xml])
        copy_cppcheck_findings_fixture

        output = @c.ceedling_build_exec("cppcheck:all")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Cppcheck findings:.*error/i)
      end
    end
  end

  def fail_build_breaks_build_on_matching_severity
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [])
        @c.merge_project_yml_for_test({ cppcheck: { fail_build: true } })
        copy_cppcheck_findings_fixture

        output = @c.ceedling_build_exec("cppcheck:all")

        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/matching :cppcheck.*:fail_build_severities/i)
        # :fail_build implies an XML report, so the evidence is on disk.
        expect(File.exist?('build/artifacts/cppcheck/CppcheckReport.xml')).to eq(true)
      end
    end
  end

  def fail_build_passes_when_no_matching_severity
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [])
        @c.merge_project_yml_for_test({
          cppcheck: { fail_build: true, fail_build_severities: ['portability'] }
        })
        copy_cppcheck_findings_fixture

        output = @c.ceedling_build_exec("cppcheck:all")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Cppcheck findings:/i)
      end
    end
  end

  # Listing suppression files needs no Cppcheck executable. Same defect class as
  # issue #1252 in the Gcov plugin.
  def suppression_file_listing_needs_no_cppcheck
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_cppcheck(reports: [:text])

        output = @c.ceedling_appcmd_exec("files:cppcheck")

        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Cppcheck suppression files/i)
      end
    end
  end

end
