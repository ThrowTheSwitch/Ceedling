# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module CommonSystemTestCases
  def can_report_version_no_git_commit_sha
    @c.with_context do
      # Version without Git commit short SHA file in project
      output = @c.ceedling_appcmd_exec("version")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Ceedlingz => \d\.\d\.\d\n/)
    end
  end

  def can_report_version_with_git_commit_sha
    # Version with Git commit short SHA file in root of project
    # Creating the commit file before building + installing the gem simulates the CI process
    File.open('GIT_COMMIT_SHA', 'w') do |f|
      f << '---{-@'
    end

    @c.with_context do
      output = @c.ceedling_appcmd_exec("version")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Ceedling => \d\.\d\.\d----{-@\n/)
    end
  end

  def can_create_projects
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        expect(File.exist?("test/support")).to eq true
      end
    end
  end

  def has_git_support
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?(".gitignore")).to eq true
        expect(File.exist?("test/support/.gitkeep")).to eq true
      end
    end
  end

  def can_upgrade_projects
    @c.with_context do
      output = @c.ceedling_appcmd_exec("upgrade #{@proj_name}")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Upgraded/i)
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        all_docs = Dir["vendor/ceedling/docs/*.pdf"].length + Dir["vendor/ceedling/docs/*.md"].length
      end
    end
  end

  def can_upgrade_projects_even_if_test_support_folder_does_not_exist
    @c.with_context do
      output = @c.ceedling_appcmd_exec("upgrade #{@proj_name}")
      FileUtils.rm_rf("#{@proj_name}/test/support")

      updated_prj_yml = []
      File.read("#{@proj_name}/project.yml").split("\n").each do |line|
        updated_prj_yml.append(line) unless line =~ /support/
      end
      File.write("#{@proj_name}/project.yml", updated_prj_yml.join("\n"), mode: 'w')

      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Upgraded/i)
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
      end
    end
  end

  def cannot_upgrade_non_existing_project
    @c.with_context do
      output = @c.ceedling_appcmd_exec("upgrade #{@proj_name}")
      expect(@c.last_exit_status).to eq(1)
      expect(output).to match(/Could not find an existing project/i)
    end
  end

  def contains_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling")).to eq true
      end
    end
  end

  def does_not_contain_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling")).to eq false
      end
    end
  end

  def contains_documentation
    @c.with_context do
      Dir.chdir @proj_name do
        all_docs = Dir["docs/*"]
        expect(all_docs).to contain_exactly('docs/ceedling', 'docs/unity', 'docs/cmock', 'docs/c_exception', 'docs/license.txt')
      end
    end
  end

  def does_not_contain_documentation
    @c.with_context do
      Dir.chdir @proj_name do
        expect(Dir.exist?("docs/")).to eq false
      end
    end
  end

  def can_test_projects_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_test_alias
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_default
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_named_verbosity
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("--verbosity=obnoxious")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(output).to match(/:post_test_fixture_execute/)
      end
    end
  end

  def can_test_projects_with_numerical_verbosity
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("-v=4")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(output).to match(/:post_test_fixture_execute/)
      end
    end
  end

  def can_test_projects_with_unity_exec_time
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_EXEC_TIME" ] } }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_test_and_vendor_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_unity_printf.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_PRINT_FORMATTED" ] },
                     :defines => { :test => { :example_file_unity_printf => [ "TEST" ] } }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_test_name_replaced_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.copy_entry test_asset_path("tests_with_defines/src/"), 'src/'
        FileUtils.cp_r test_asset_path("tests_with_defines/test/."), 'test/'
        settings = { :defines => { :test => { '*' => [ "TEST", "STANDARD_CONFIG" ],
                                   'test_adc_hardware_special.c' => [ "TEST", "SPECIFIC_CONFIG" ],
                                 } }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either passes or is ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # Ceedling :use_test_preprocessor is disabled
  def can_test_projects_unity_parameterized_test_cases_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_test_preprocessor => :none },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # NOTE: This is not supported in this release, therefore is not getting called.
  def can_test_projects_unity_parameterized_test_cases_with_preprocessor_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_test_preprocessor => :all },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_test_files_symbols_undefined
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareA.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorA.h"), 'src/'
        # Rely on undefined symbols in our C files
        # 2 enabled intentionally failing test cases (no mocks generated)
        settings = { :project => { :use_test_preprocessor => :tests },
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareA")
        expect(@c.last_exit_status).to eq(1) # Intentional test failure in successful build
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+2/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_test_files_symbols_defined
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareA.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorA.h"), 'src/'
        # 1 enabled passing test case with 1 mock used
        settings = { :project => { :use_test_preprocessor => :tests },
                     :defines => { :test => ['PREPROCESSING_TESTS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareA")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_mocks_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareB.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorB.h"), 'src/'
        # 1 test case with 1 mocked function
        settings = { :project => { :use_test_preprocessor => :mocks },
                     :defines => { :test => ['PREPROCESSING_MOCKS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareB")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_mocks_intentional_build_failure
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareB.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorB.h"), 'src/'
        # 1 test case with a missing mocked function
        settings = { :project => { :use_test_preprocessor => :mocks }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareB")
        expect(@c.last_exit_status).to eq(1) # Failing build because of missing mock
        expect(output).to match(/(undeclared|undefined|implicit).+Adc_Reset/)
      end
    end
  end

  def can_test_projects_with_preprocessing_all
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareC.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareC.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareC.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorC.h"), 'src/'
        # 1 test case using 1 mock
        settings = { :project => { :use_test_preprocessor => :all },
                     :defines => { :test => ['PREPROCESSING_TESTS', 'PREPROCESSING_MOCKS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareC")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_fail
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_fail_alias
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = @c.ceedling_build_exec("test")
        expect(@c.last_exit_status).to eq(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_fail_default
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Since a test explodes, we return error here
        expect(output).to match(/(?:ERROR: Ceedling Failed)|(?:Ceedling could not complete operations because of errors)/)
      end
    end
  end

  def can_test_projects_with_both_mock_and_real_header
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("example_file_call.h"), 'src/'
        FileUtils.cp test_asset_path("example_file_call.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_with_mock.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either passed or was ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def uses_report_tests_raw_output_log_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_verbose.c"), 'test/'

        @c.uncomment_project_yml_option_for_test('- report_tests_raw_output_log')

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
        expect(File.exist?("build/artifacts/test/test_example_file_verbose.raw.log")).to eq true
      end
    end
  end


  def can_fetch_non_project_help
    @c.with_context do
      # notice we don't change directory into the project
      output = @c.ceedling_appcmd_exec("help")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/ceedling example/i)
      expect(output).to match(/ceedling new/i)
      expect(output).to match(/ceedling upgrade/i)
      expect(output).to match(/ceedling version/i)
    end
  end

  def can_fetch_project_help
    @c.with_context do
      Dir.chdir @proj_name do
        output = @c.ceedling_appcmd_exec("help")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/ceedling clean/i)
        expect(output).to match(/ceedling clobber/i)
        expect(output).to match(/ceedling module:create/i)
        expect(output).to match(/ceedling module:destroy/i)
        expect(output).to match(/ceedling summary/i)
        expect(output).to match(/ceedling test:\*/i)
        expect(output).to match(/ceedling test:all/i)
        expect(output).to match(/ceedling version/i)
      end
    end
  end

  def can_run_single_test_with_full_test_case_name_from_test_file_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=test_add_numbers_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_run_single_test_with_partial_test_case_name_from_test_file_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=zumzum")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/No tests executed./)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=_adds_numbers --exclude_test_case=_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/No tests executed./)
      end
    end
  end

  def exclude_test_case_name_filter_works_and_only_one_test_case_is_executed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:all --exclude_test_case=test_add_numbers_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+1/)
      end
    end
  end

  def run_one_testcase_from_one_test_file_when_test_case_name_is_passed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end


  def test_run_of_projects_fail_because_of_crash_without_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(!File.exist?('./build/test/results/test_add.fail'))
      end
    end
  end

  def test_run_of_projects_fail_because_of_crash_with_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
      end
    end
  end

  def execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all --test_case=test_add_numbers_will_fail")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all --exclude_test_case=add_numbers_adds_numbers")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_test_projects_with_test_file_directly_including_source_file
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file_with_statics.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_source_include.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_when_space_appears_between_hash_and_include
    # test case cover issue described in https://github.com/ThrowTheSwitch/Ceedling/issues/588
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path('test_example_file_success.c'), 'test/'

        add_line = false
        updated_test_file = []
        File.read(File.join('test','test_example_file_success.c')).split("\n").each do |line|
          if line =~ /#include "unity.h"/
            add_line = true
            updated_test_file.append(line)
          else
            if add_line
              updated_test_file.append('# include "unity.h"')
              add_line = false
            end
            updated_test_file.append(line)
          end
        end

        File.write(File.join('test','test_example_file_success.c'), updated_test_file.join("\n"), mode: 'w')

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end
end
