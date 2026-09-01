# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rbconfig'
require 'ceedling/file_wrapper'
require 'ceedling/yaml_wrapper'

module CommonSystemTestCases
  def yaml_wrapper_for_test
    file_wrapper = FileWrapper.new({
      :loginator    => double('loginator').as_null_object,
      :verbosinator => double('verbosinator').as_null_object
    })
    YamlWrapper.new({ file_wrapper: file_wrapper })
  end

  def can_report_version_no_git_commit_sha
    @c.with_context do
      # Version without Git commit short SHA file in project
      output = @c.ceedling_appcmd_exec("version")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Ceedling => \d\.\d\.\d\n/)
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

  def can_upgrade_projects_with_no_test_support_folder
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
        # docs/ceedling only exists when this repo's own local HTML docs bundle
        # (site-local/) was available to copy in -- see html_docs_bundle_available?.
        expected = ['docs/unity', 'docs/cmock', 'docs/c_exception', 'docs/license.txt']
        expected << 'docs/ceedling' if html_docs_bundle_available?
        expect(all_docs).to contain_exactly(*expected)
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

  def test_project_success
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

  def test_project_with_test_all_alias
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

  def test_project_success_default_task
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

  def test_project_with_named_verbosity
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

  # #1251 -- the Overall Test Summary must still print at :warnings verbosity
  # (`--verbosity=warnings`, Verbosity::COMPLAIN) on an all-passing run, not just
  # when verbosity is :normal or higher, or when a test fails. Before this fix, the
  # summary's own gate mistakenly required :normal, silently swallowing the summary
  # on the (default) all-clean case at :warnings.
  def test_project_with_warnings_verbosity_prints_overall_summary
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("--verbosity=warnings")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/OVERALL TEST SUMMARY/)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def test_project_with_numerical_verbosity
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

  def test_project_with_unity_exec_time
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

  def test_project_with_test_and_vendor_defines
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

  def test_project_with_per_file_defines
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.copy_entry test_asset_path("tests_with_defines/src/"), 'src/'
        FileUtils.cp_r test_asset_path("tests_with_defines/test/."), 'test/'
        settings = { 
          :defines => { 
            :test => {
              '*' => [ "TEST", "STANDARD_CONFIG" ],
              'test_adc_hardware_special.c' => [ "TEST", "SPECIFIC_CONFIG" ],
            }
          }
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
  def test_project_unity_parameterized_test_cases
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

  # assets/test_example_with_parameterized_tests.c declares 3 TEST_CASE values,
  # TEST_RANGE([5,100,5]) (20 values), and TEST_RANGE([10,100,10],[5,10,5]) (10*2=20 values)
  # for a total of 43 expanded test invocations. Asserting the exact counts (rather than
  # the file's usual loose `\d` match) matters here specifically. A broken positional
  # association would silently degrade to 3 un-parameterized tests (one per declared
  # function) and a loose digit match would still pass.
  def test_project_preprocessed_unity_parameterized_test_cases
    @c.with_context do
      Dir.chdir @proj_name do
        # Short destination filename: Ceedling's directives-only preprocessing path
        # repeats the test module name twice (.../preprocess/files/<name>/directives_only/raw/<name>.c).
        # Combined with an already-deep Windows CI temp project path, the asset's original
        # long filename pushed the full absolute path past Windows' 260-char MAX_PATH limit,
        # causing gcc.exe to fail opening its own output file with a spurious
        # "No such file or directory". Keeping the copied filename short avoids that.
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/test_ptc.c'
        settings = { :project => { :use_test_preprocessor => :all },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/TESTED:\s+43/)
        expect(output).to match(/PASSED:\s+43/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def test_project_preprocessing_undefined_symbols
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

  def test_project_preprocessing_defined_symbols
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

  def test_project_with_preprocessing_for_mocks
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

  def test_project_with_preprocessing_for_missing_mock
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

  def test_project_with_preprocessing_all
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

  # A module splits its function declarations (same_dir_pairing_module_func.h, mocked by
  # this test) from its type declarations (same_dir_pairing_module.h, reached only
  # transitively via same_dir_pairing_other.h, never included directly by the test). All
  # of these files are colocated in the test's own directory, which is what exercises
  # GCC's same-directory quoted #include resolution during bare-includes extraction.
  # Auto source-pairing must not pull the real source implementing the type header's
  # like-named stem into this build alongside its mock of the differently-named header.
  def test_project_preprocessing_same_dir_mock_pairing
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("same_dir_pairing_module.h"), 'test/'
        FileUtils.cp test_asset_path("same_dir_pairing_module_func.h"), 'test/'
        FileUtils.cp test_asset_path("same_dir_pairing_module.c"), 'test/'
        FileUtils.cp test_asset_path("same_dir_pairing_other.h"), 'test/'
        FileUtils.cp test_asset_path("same_dir_pairing_other.c"), 'test/'
        FileUtils.cp test_asset_path("test_same_dir_pairing.c"), 'test/'

        settings = {
          :project => { :use_test_preprocessor => :all },
          :paths => {
            :source  => ['src/**', 'test/**'],
            :include => ['src/**', 'test/**']
          }
        }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:same_dir_pairing")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).not_to match(/multiple definition|duplicate symbol/)
      end
    end
  end

  # A module header with both a plain (non-inline) function prototype and a `static
  # inline` function, with no paired .c source providing a body for the plain prototype
  # (so it exists only as a bare declaration, never a definition). MOCK_PARTIAL_ALL_MODULE()
  # must mock both functions, not just the one with a body.
  def test_project_partial_all_module_mocks_declaration_only_function
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("partial_all_module.h"), 'src/'
        FileUtils.cp test_asset_path("test_partial_all_module.c"), 'test/'

        settings = {
          :project => {
            :use_partials          => true,
            :use_test_preprocessor => :all
          }
        }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:partial_all_module")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def test_project_fail
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

  def test_project_fail_alias
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

  def test_project_fail_default
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

  def test_project_with_compile_error
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

  def test_project_with_both_mock_and_real_header
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

  def report_tests_raw_output_log_plugin
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

  def application_commands_help
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

  def project_build_tasks_plugins_help
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

  def run_single_test_with_full_name_filter
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

  def run_single_test_with_partial_name_filter
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

  def no_tests_run_when_filter_matches_nothing
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

  def no_tests_run_when_filter_and_exclusion_cancel
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

  def exclusion_filter_leaves_one_test_case
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

  def run_one_test_case_with_name_filter
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


  # Validates that a crash with :use_backtrace => :none reports "Test Executable Crashed"
  # in Ceedling output and returns a failing exit code.
  # Uses a SIGSEGV (null-pointer dereference) crash.
  def crash_none_reports_executable_crashed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(!File.exist?('./build/test/results/test_add.fail'))
      end
    end
  end

  # Validates that a crash with :use_backtrace => :none writes a .fail results file
  # containing the crashed test case name and crash location.
  # Uses a SIGSEGV (null-pointer dereference) crash.
  def crash_none_writes_fail_results_file
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(File.exist?('./build/test/results/test_example_file_crash_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash_sigsegv.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash_sigsegv.c\:\d+/ )
      end
    end
  end

  # Validates that :use_backtrace => :gdb runs all test cases, identifies the crashing
  # one (SIGSEGV from null-pointer dereference), writes a gdb log file, and includes
  # a log path reference in Ceedling output.
  def crash_gdb_sigsegv_all_test_cases
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(File.exist?('./build/test/results/test_example_file_crash_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash_sigsegv.fail')
        expect(output_rd).to match(/Test case crashed/)
        expect(output_rd).to match(/SIGSEGV/i)
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
        log_path = './build/logs/test/test_example_file_crash_sigsegv/test_add_numbers_will_fail.gdb.log'
        expect(File.exist?(log_path)).to be(true)
        expect(File.read(log_path)).to match(/SIGSEGV|Segmentation fault/i)
        expect(output).to match(/test_add_numbers_will_fail\.gdb\.log/)
      end
    end
  end

  # Validates that :use_backtrace => :gdb respects --test_case filter, running only
  # the named crashing test case (SIGSEGV) and writing a gdb log for it.
  def crash_gdb_sigsegv_targets_test_case_filter
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all --test_case=test_add_numbers_will_fail")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(File.exist?('./build/test/results/test_example_file_crash_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash_sigsegv.fail')
        expect(output_rd).to match(/Test case crashed/)
        expect(output_rd).to match(/SIGSEGV/i)
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
        log_path = './build/logs/test/test_example_file_crash_sigsegv/test_add_numbers_will_fail.gdb.log'
        expect(File.exist?(log_path)).to be(true)
        expect(File.read(log_path)).to match(/SIGSEGV|Segmentation fault/i)
        expect(output).to match(/test_add_numbers_will_fail\.gdb\.log/)
      end
    end
  end

  # Validates that :use_backtrace => :gdb respects --exclude_test_case filter, running
  # only the crashing test case (SIGSEGV) after the passing one is excluded, and writing a gdb log.
  def crash_gdb_sigsegv_excludes_test_case_filter
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all --exclude_test_case=add_numbers_adds_numbers")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(File.exist?('./build/test/results/test_example_file_crash_sigsegv.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash_sigsegv.fail')
        expect(output_rd).to match(/Test case crashed/)
        expect(output_rd).to match(/SIGSEGV/i)
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
        log_path = './build/logs/test/test_example_file_crash_sigsegv/test_add_numbers_will_fail.gdb.log'
        expect(File.exist?(log_path)).to be(true)
        expect(File.read(log_path)).to match(/SIGSEGV|Segmentation fault/i)
        expect(output).to match(/test_add_numbers_will_fail\.gdb\.log/)
      end
    end
  end

  # Validates that :use_backtrace => :gdb handles a SIGABRT crash from assert(0),
  # surfacing the assertion expression (not bare "Aborted") in the crash summary,
  # writing a gdb log containing the raw gdb output, and including a log path reference
  # in Ceedling output. This is the core gdb-mode regression test for issue #1038.
  def crash_gdb_sigabrt_assert_failure
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_assert.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(output).to match(/SIGABRT/i)
        expect(output).to match(/Assertion/i)
        log_path = './build/logs/test/test_example_file_crash_assert/test_add_numbers_triggers_assert.gdb.log'
        expect(File.exist?(log_path)).to be(true)
        # Windwos gdb output for an assertion failure can be quite different from Linux.
        # Windows gdb reports do not seem to cite the signal "SIGABRT" and may be quite brief, 
        # only citing an assertion failure.
        expect(File.read(log_path)).to match(/SIGABRT|abort|assert/i)
        expect(output).to match(/test_add_numbers_triggers_assert\.gdb\.log/)
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  # Validates that :use_backtrace => :simple runs each test case individually,
  # identifies the crashing one (SIGSEGV from null-pointer dereference), and reports
  # it as a per-test-case failure rather than a whole-executable crash.
  def crash_simple_sigsegv_all_test_cases
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :simple }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures/)
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  # Validates that :use_backtrace => :simple captures the glibc assertion message written
  # to stderr before SIGABRT and includes it in the Ceedling crash report output.
  # This is the core simple-mode regression test for issue #1038.
  def crash_simple_sigabrt_assert_failure
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_assert.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :simple }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1)
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures/)
        # glibc assertion diagnostic written to stderr must appear in Ceedling output
        expect(output).to match(/Assertion.*failed/i)
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  # Regression test for issue #1185: a parameterized test (TEST_CASE) defined after a
  # crashing test in the same file must still report its own real PASS results instead
  # of being swept up as "crashed" alongside the actual crash. Uses :use_backtrace => :simple
  # (Ceedling's default), which is the mode in which the bug was reported.
  def crash_simple_sigsegv_with_parameterized_test
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv_with_param.c"), 'test/'

        @c.merge_project_yml_for_test({
          :project => { :use_backtrace => :simple },
          :unity   => { :use_param_tests => true }
        })

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Unit test failures/)
        # 1 crashing test + 3 parameterized cases
        expect(output).to match(/TESTED:\s+4/)
        expect(output).to match(/PASSED:\s+3/)
        expect(output).to match(/FAILED:\s+1/)
        expect(output).to match(/IGNORED:\s+0/)

        result_file = './build/test/results/test_example_file_crash_sigsegv_with_param.fail'
        expect(File.exist?(result_file)).to be(true)
        results = yaml_wrapper_for_test.load(result_file)

        # Only the truly crashing test is reported as a failure/crash
        expect(results[:failures].map { |f| f[:test] }).to eq(['test_add_numbers_will_fail'])
        expect(results[:failures].first[:message]).to match(/Test case crashed/)

        # Each parameterized case reports its own real (passing) result, by name, not a crash
        expect(results[:successes].map { |s| s[:test] }).to contain_exactly(
          'test_difference_between_numbers_is_correct(5, 3, 2)',
          'test_difference_between_numbers_is_correct(10, 4, 6)',
          'test_difference_between_numbers_is_correct(0, 0, 0)'
        )
      end
    end
  end

  # Same regression coverage as `crash_simple_sigsegv_with_parameterized_test`, but for
  # :use_backtrace => :gdb: confirms gdb-based isolation also correctly distinguishes the
  # crashing test from the unrelated parameterized test, and still attributes the crash to
  # the correct source line (exercising the gdb crash-frame symbol matching fix).
  def crash_gdb_sigsegv_with_parameterized_test
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash_sigsegv_with_param.c"), 'test/'

        @c.merge_project_yml_for_test({
          :project => { :use_backtrace => :gdb },
          :unity   => { :use_param_tests => true }
        })

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Unit test failures/)
        expect(output).to match(/TESTED:\s+4/)
        expect(output).to match(/PASSED:\s+3/)
        expect(output).to match(/FAILED:\s+1/)
        expect(output).to match(/IGNORED:\s+0/)

        result_file = './build/test/results/test_example_file_crash_sigsegv_with_param.fail'
        expect(File.exist?(result_file)).to be(true)
        results = yaml_wrapper_for_test.load(result_file)

        # Only the truly crashing test is reported as a failure/crash
        expect(results[:failures].map { |f| f[:test] }).to eq(['test_add_numbers_will_fail'])
        expect(results[:failures].first[:message]).to match(/Test case crashed/)
        expect(results[:failures].first[:message]).to match(/SIGSEGV/i)

        # Each parameterized case reports its own real (passing) result, by name, not a crash
        expect(results[:successes].map { |s| s[:test] }).to contain_exactly(
          'test_difference_between_numbers_is_correct(5, 3, 2)',
          'test_difference_between_numbers_is_correct(10, 4, 6)',
          'test_difference_between_numbers_is_correct(0, 0, 0)'
        )

        log_path = './build/logs/test/test_example_file_crash_sigsegv_with_param/test_add_numbers_will_fail.gdb.log'
        expect(File.exist?(log_path)).to be(true)
        expect(File.read(log_path)).to match(/SIGSEGV|Segmentation fault/i)
      end
    end
  end

  # Regression test for issue #1198: a custom :test_fixture tool (e.g. a wrapper
  # enabling a sanitizer's halt-on-error) can correctly detect a crash on the main run,
  # only for that crash to be silently overwritten by a :simple backtrace diagnostic
  # retry that runs through a *different*, independently-configured tool
  # (test_fixture_simple_backtrace) and behaves differently there -- legitimately
  # passing in that other environment. fake_crash_test_fixture.rb reproduces the
  # mismatch without needing a real sanitizer: it always exits nonzero without ever
  # running the real, bug-free test executable it's given, while the unmodified default
  # backtrace retry tool runs that same executable directly and passes.
  def crash_simple_diagnostic_retry_disagrees_with_main_fixture
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        FileUtils.cp test_asset_path("fake_crash_test_fixture.rb"), 'test/'

        @c.merge_project_yml_for_test({
          :project => { :use_backtrace => :simple },
          :tools   => {
            :test_fixture => {
              :executable => RbConfig.ruby,
              :arguments  => ['test/fake_crash_test_fixture.rb']
            }
          }
        })

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).not_to eq(0)
        expect(output).to match(/Unit test failures/)
        expect(output).not_to match(/PASSED:\s+1/)
      end
    end
  end

  # Same regression coverage as crash_simple_diagnostic_retry_disagrees_with_main_fixture
  # above, but with a real UBSan-triggered crash (matching issue #1198's own
  # reproduction exactly) instead of the portable simulated fixture. UBSan doesn't
  # produce an OS-level crash signal the way a segfault does -- run_with_ubsan.rb's
  # halt_on_error setting is what turns the undefined behavior into a hard stop, and
  # only the main :test_fixture invocation goes through that wrapper. Requires a Linux
  # gcc toolchain with -fsanitize=undefined support -- see "requires gcc with UBSan".
  def crash_simple_ubsan_diagnostic_retry_disagrees_with_main_fixture
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_file_ub_shift_overflow.c"), 'test/'
        FileUtils.cp test_asset_path("run_with_ubsan.rb"), 'test/'

        @c.merge_project_yml_for_test({
          :project => { :use_backtrace => :simple },
          :flags   => {
            :test => {
              :compile => { '*' => ['-fsanitize=undefined'] },
              :link    => { '*' => ['-fsanitize=undefined'] }
            }
          },
          :tools => {
            :test_fixture => {
              :executable => RbConfig.ruby,
              :arguments  => ['test/run_with_ubsan.rb', '${1}']
            }
          }
        })

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).not_to eq(0)
        expect(output).to match(/Unit test failures/)
        expect(output).not_to match(/PASSED:\s+1/)
      end
    end
  end

  def project_with_test_file_directly_including_source_file
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

  def space_between_hash_and_include_is_valid
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
