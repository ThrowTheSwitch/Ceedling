require 'fileutils'
require 'tmpdir'
require 'yaml'
require 'spec_system_helper'
require 'pp'


module GcovTestCases

  def can_test_projects_with_gcov_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all`
        expect($?.exitstatus).to match(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_fail
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_fail_because_of_uncovered_files
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov_abortonuncovered.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("uncovered_example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(255) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_success_because_of_ignore_uncovered_list
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov_abortonuncovered.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), "src/"
        FileUtils.cp test_asset_path("example_file.c"), "src/"
        FileUtils.cp test_asset_path("uncovered_example_file.c"), "src/foo_file.c" # "src/foo_file.c" is in the ignore uncovered list
        FileUtils.cp test_asset_path("test_example_file_success.c"), "test/"

        output = `bundle exec ruby -S ceedling gcov:all 2>&1`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_gcov_with_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = `bundle exec ruby -S ceedling test:all 2>&1`
        expect($?.exitstatus).to match(1) # Since a test explodes, we return error here
        expect(output).to match(/ERROR: Ceedling Failed/)
      end
    end
  end

  def can_fetch_project_help_for_gcov
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        output = `bundle exec ruby -S ceedling help`
        expect($?.exitstatus).to match(0)
        expect(output).to match(/ceedling gcov:\*/i)
        expect(output).to match(/ceedling gcov:all/i)
        expect(output).to match(/ceedling gcov:delta/i)
        expect(output).to match(/ceedling utils:gcov/i)
      end
    end
  end

  def can_create_html_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("project_with_guts_gcov.yml"), "project.yml"
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = `bundle exec ruby -S ceedling gcov:all`
        output = `bundle exec ruby -S ceedling utils:gcov`
        expect(output).to match(/Creating gcov results report\(s\) in 'build\/artifacts\/gcov'\.\.\. Done/)
        expect(File.exists?('build/artifacts/gcov/GcovCoverageResults.html')).to eq true
      end
    end
  end
end
