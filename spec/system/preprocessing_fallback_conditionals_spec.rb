# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Fallback Preprocessing Conditional-Block Tracking Tests
## ========================================================
##
## These tests verify that when Ceedling's preprocessing falls back to
## text-only parsing (preprocess_force_fallback: true), it correctly
## tracks #ifdef/#else/#endif blocks in SOURCE and HEADER files that are
## processed as Partials (:use_partials).
##
## The primary fallback use case is Partials processing: Ceedling reads
## source/header files through collect_file_contents_fallback (called by
## preprocess_partial_header/source_file_preserve_macros) and the #ifdef
## guards in those files determine what code appears in the generated
## partial implementation. The test file mirrors the same define-based
## conditions to include the corresponding mock and select test cases.
##
## Before the conditional-tracking fix, fallback mode was blind to
## #ifdef context in source/header files, so inactive blocks were still
## included in the partial content, breaking conditional mock scenarios.
##
## All tests in this file use:
##   :project    => { :use_partials => true }   — triggers source/header partial preprocessing
##   :test_build => { :preprocess_force_fallback => true }  — forces text-only fallback
##
## Test assets: assets/tests_with_fallback_conditionals/
##   - conditional_module.h: declares ConditionalModule_Init()
##   - conditional_module.c: conditionally includes optional_dep.h and
##     calls OptionalDep_DoWork() when CONDITIONAL_FEATURE is defined
##   - optional_dep.h: header for the optional dependency (mockable)
##   - test_conditional_module.c: uses TEST_PARTIAL_ALL_MODULE to pull in
##     the partial; conditionally includes mock_optional_dep.h and selects
##     test cases based on CONDITIONAL_FEATURE
##   - Files contain UTF-8 multi-byte characters in comments to exercise
##     encoding safety of the conditional-tracking path
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("fallback_cond") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end


    # =========================================================================
    describe "Fallback partial preprocessing with conditional #ifdef tracking" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_fallback_conditionals/src/conditional_module.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_fallback_conditionals/src/conditional_module.c"), 'src/'
            FileUtils.cp test_asset_path("tests_with_fallback_conditionals/src/optional_dep.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_fallback_conditionals/test/test_conditional_module.c"), 'test/'
          end
        end
      end


      # -----------------------------------------------------------------------
      # Without CONDITIONAL_FEATURE: the #ifdef CONDITIONAL_FEATURE block in
      # conditional_module.c is inactive during fallback partial preprocessing,
      # so the call to OptionalDep_DoWork() is excluded from the partial. No
      # mock is generated. The #ifndef CONDITIONAL_FEATURE test case runs and
      # passes (calls ConditionalModule_Init(), which is a no-op in the partial).
      # -----------------------------------------------------------------------
      it "should exclude inactive #ifdef block from partial and run #ifndef test case when defines are not provided" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = {
              :project    => { :use_partials => true },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec("test:conditional_module")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end


      # -----------------------------------------------------------------------
      # With CONDITIONAL_FEATURE defined: the #ifdef CONDITIONAL_FEATURE block
      # in conditional_module.c is active during fallback partial preprocessing,
      # so OptionalDep_DoWork() is included in the partial. The test file's
      # corresponding #ifdef generates the mock. The #ifdef test case runs and
      # passes (ConditionalModule_Init() calls OptionalDep_DoWork() in the
      # partial; the mock satisfies the expectation).
      # -----------------------------------------------------------------------
      it "should include active #ifdef block in partial and run #ifdef test case when defines are provided" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = {
              :project    => { :use_partials => true },
              :test_build => { :preprocess_force_fallback => true },
              :defines    => { :test => ['CONDITIONAL_FEATURE'] }
            }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec("test:conditional_module")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end


      # -----------------------------------------------------------------------
      # Encoding safety: UTF-8 multi-byte characters in comments near #ifdef
      # directives in source/header files must not cause encoding errors when
      # the fallback partial preprocessor processes them.
      # (The test assets already contain non-ASCII UTF-8 in comments.)
      # -----------------------------------------------------------------------
      it "should not raise errors when processing UTF-8 in source/header comments near #ifdef" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = {
              :project    => { :use_partials => true },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec("test:conditional_module")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

    end

  end

end
