# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'valgrind_helpers'

module ValgrindCommonTestCases
  include ValgrindHelpers

  def project_build_tasks_plugins_help_for_valgrind
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        output = @c.ceedling_appcmd_exec("help")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/ceedling valgrind:\*/i)
        expect(output).to match(/ceedling valgrind:all/i)
      end
    end
  end

  def run_valgrind_on_all_tests
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("valgrind:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Wrote 1 Valgrind report/i)
        expect(File.exist?('build/artifacts/valgrind/test_example_file_success.log')).to eq(true)
        expect(File.size('build/artifacts/valgrind/test_example_file_success.log')).to be > 0
      end
    end
  end

  def run_valgrind_on_single_test
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("valgrind:test_example_file_success.c")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/Wrote 1 Valgrind report/i)
        expect(File.exist?('build/artifacts/valgrind/test_example_file_success.log')).to eq(true)
        expect(File.size('build/artifacts/valgrind/test_example_file_success.log')).to be > 0
      end
    end
  end

  # Validates that the default `:fail_build: true` behavior:
  # the suite runs to completion, a per-test error is logged, and Valgrind
  # registers a build failure with an aggregate memory error count.
  # Uses a SIGSEGV (null-pointer dereference) crash, which produces Valgrind memory errors.
  def run_valgrind_memory_error_fail_build_enabled
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        output = @c.ceedling_build_exec("valgrind:all")

        expect(@c.last_exit_status).to eq(1) # Crash + Valgrind build failure
        # Ceedling crash detection
        expect(output).to match(/test_example_file_crash_sigsegv.+crashed/i)
        # Per-test Valgrind memory error log (always fires when errors found)
        expect(output).to match(/Valgrind detected.*memory error/i)
        # Aggregate build failure registered by Valgrind plugin
        expect(output).to match(/Valgrind detected.*memory error.*across/i)
        expect(output).to match(/Wrote 1 Valgrind report/i)
        expect(File.exist?('build/artifacts/valgrind/test_example_file_crash_sigsegv.log')).to eq(true)
        expect(File.size('build/artifacts/valgrind/test_example_file_crash_sigsegv.log')).to be > 0
        # Expected memory error(s) detected by Valgrind
        expect(File.read('build/artifacts/valgrind/test_example_file_crash_sigsegv.log')).to match(/ERROR SUMMARY:\s+[1-9]/)
      end
    end
  end

  # Validates that `:fail_build: false` suppresses the Valgrind aggregate build failure:
  # the suite runs to completion, the per-test error is still logged, but no Valgrind
  # build failure is registered. The build still fails due to the test case crash.
  # Uses a SIGSEGV (null-pointer dereference) crash, which produces Valgrind memory errors.
  def run_valgrind_memory_error_fail_build_disabled
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        @c.merge_project_yml_for_test({ :valgrind => { :fail_build => false } })
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        output = @c.ceedling_build_exec("valgrind:all")

        expect(@c.last_exit_status).to eq(1) # Crash causes failure even without Valgrind build failure
        # Ceedling crash detection
        expect(output).to match(/test_example_file_crash_sigsegv.+crashed/i)
        # Per-test Valgrind error log still fires (independent of :fail_build)
        expect(output).to match(/Valgrind detected.*memory error/i)
        # No aggregate Valgrind build failure registered
        expect(output).not_to match(/Valgrind detected.*memory error.*across/i)
        expect(output).to match(/Wrote 1 Valgrind report/i)
        expect(File.exist?('build/artifacts/valgrind/test_example_file_crash_sigsegv.log')).to eq(true)
        expect(File.size('build/artifacts/valgrind/test_example_file_crash_sigsegv.log')).to be > 0
        # Expected memory error(s) detected by Valgrind
        expect(File.read('build/artifacts/valgrind/test_example_file_crash_sigsegv.log')).to match(/ERROR SUMMARY:\s+[1-9]/)
      end
    end
  end

end
