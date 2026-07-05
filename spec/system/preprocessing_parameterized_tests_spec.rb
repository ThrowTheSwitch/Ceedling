# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Positional TEST_CASE()/TEST_RANGE()/TEST_MATRIX() Preservation Through Preprocessing
## ======================================================================================
##
## TEST_CASE()/TEST_RANGE()/TEST_MATRIX() are Unity marker macros -- #defined to expand
## to nothing -- that Unity's runner generator only recognizes when they sit immediately
## (whitespace only) ahead of the `void test_Foo(...)` function they configure.
##
## Ceedling's optional test-file preprocessing (:project ↳ :use_test_preprocessor) fully 
## expands macros before that scan happens. These tests confirm that with preprocessing 
## enabled, the exact same expansion occurs as with preprocessing disabled -- same test 
## counts, same per-case arguments in the generated runner file.
##
## Test asset: assets/test_example_with_parameterized_tests.c
##   - 3 TEST_CASE values (25, 125, 5)
##   - TEST_RANGE([5, 100, 5])                   -> 20 values
##   - TEST_RANGE([10, 100, 10], [5, 10, 5])     -> 10 * 2 = 20 values
##   - Total: 43 expanded test invocations across 3 declared functions
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("param_preprocess") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end


    # =========================================================================
    describe "Parameterized tests with test-file preprocessing enabled" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
          end
        end
      end


      # -----------------------------------------------------------------------
      # `:use_test_preprocessor => :all` fully preprocesses the test file before
      # runner generation scans it. With preservation of the macros, we should 
      # see 43 parameterized invocations.
      # -----------------------------------------------------------------------
      it "should expand all 43 parameterized test cases with :use_test_preprocessor => :all" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = { :project => { :use_test_preprocessor => :all },
                         :unity   => { :use_param_tests => true }
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


      # -----------------------------------------------------------------------
      # `:use_test_preprocessor => :tests` preprocesses only the test file (not
      # mockable headers) -- the same code path exercised above, verified here
      # for the narrower preprocessing option too.
      # -----------------------------------------------------------------------
      it "should expand all 43 parameterized test cases with :use_test_preprocessor => :tests" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = { :project => { :use_test_preprocessor => :tests },
                         :unity   => { :use_param_tests => true }
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


      # -----------------------------------------------------------------------
      # Baseline regression guard: The same test file and :use_param_tests
      # setting, with preprocessing disabled.
      # -----------------------------------------------------------------------
      it "should expand all 43 parameterized test cases with preprocessing disabled" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = { :project => { :use_test_preprocessor => :none },
                         :unity   => { :use_param_tests => true }
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


      # -----------------------------------------------------------------------
      # Confirms the *positional* association survived, not just a count. The
      # generated runner file must contain a distinct wrapper function calling
      # the parameterized test with each literal argument value Unity's
      # runner generator extracted from the (correctly repositioned) TEST_CASE
      # calls. This directly exercises Unity's create_args_wrappers(), the
      # step that only ever runs on args successfully parsed from TEST_CASE().
      # -----------------------------------------------------------------------
      it "should generate distinct argument wrappers for each TEST_CASE value" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = { :project => { :use_test_preprocessor => :all },
                         :unity   => { :use_param_tests => true }
                       }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec
            expect(@c.last_exit_status).to eq(0)

            runner_path = 'build/test/runners/test_example_with_parameterized_tests_runner.c'
            expect(File.exist?(runner_path)).to eq(true)
            runner_contents = File.read(runner_path)

            test_name = 'test_should_handle_divisible_by_5_for_parameterized_test_case'
            [25, 125, 5].each do |value|
              expect(runner_contents).to match(/#{test_name}\s*\(\s*#{value}\s*\)\s*;/)
            end
          end
        end
      end

    end

  end

end
