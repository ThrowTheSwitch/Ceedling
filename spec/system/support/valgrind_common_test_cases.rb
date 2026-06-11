# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'valgrind_helpers'

module ValgrindCommonTestCases
  include ValgrindHelpers

  def can_fetch_project_help_for_valgrind
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

  def can_run_valgrind_on_all_tests
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("valgrind:all")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/INFO:.*valgrind/i)
        expect(File.exist?('build/artifacts/valgrind/test_example_file_success.log')).to eq(true)
        expect(File.size('build/artifacts/valgrind/test_example_file_success.log')).to be > 0
      end
    end
  end

  def can_run_valgrind_on_single_test
    @c.with_context do
      Dir.chdir @proj_name do
        prep_project_yml_for_valgrind
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("valgrind:test_example_file_success.c")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/INFO:.*valgrind/i)
        expect(output).to match(/test_example_file_success/i)
        expect(File.exist?('build/artifacts/valgrind/test_example_file_success.log')).to eq(true)
        expect(File.size('build/artifacts/valgrind/test_example_file_success.log')).to be > 0
      end
    end
  end

end
