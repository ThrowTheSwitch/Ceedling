# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Conditional-#include Macro-Visibility Tests (directives-only preprocessing)
## =============================================================================
##
## Ceedling discovers a file's #includes via two preprocessor passes reconciled
## into one list: a "bare" pass and an accurate pass (gcc -E -fdirectives-only
## against the real file with real search paths -- genuinely opens every
## header). Reconciliation keeps an accurate-pass entry only if bare also found
## it, to filter out headers reached only via a deeper, nested path.
##
## "Bare" is itself two things unioned together: a gcc -M -MG -MP pass against
## an isolated, sibling-free copy of the file (so it never actually opens any
## header the file #includes, but can still resolve an #include whose own
## target is a macro, since command-line -D defines are visible even in
## isolation), and a plain literal text scan of the file's own #include lines
## (no conditional evaluation at all, so it sees past a guard the isolated gcc
## pass can't evaluate -- but also can't resolve a macro-computed #include
## target, since there's no literal filename in the source text to find).
## Neither replaces the other; each catches what the other structurally can't.
##
## These tests characterize that reconciliation's behavior for #include
## directives guarded by an #if/#ifdef, across the different places the
## guarding macro can come from -- some already handled correctly, one
## (issue #1223) fixed by adding the text-scan half of "bare" above.
##
## Test assets: assets/tests_with_conditional_includes/
##   - widget.c/.h: three scenarios that already work correctly:
##     (a) conditional include gated on a project :defines macro
##     (b) conditional include gated on a same-file #define
##     (c) a header reached only transitively (nested_wrapper.h's own
##         #include, never itself directly #include'd by widget.c) --
##         must not appear duplicated in as a false top-level entry
##   - widget_feature.c/.h + feature_config.h + feature_extra.h: issue #1223
##     itself -- a conditional include gated on a macro defined by an
##     *earlier #include in the same file* (feature_config.h's FEATURE_LEVEL),
##     which the isolated bare pass can never see, silently dropping
##     feature_extra.h and leaving FEATURE_EXTRA_MACRO undeclared.
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("cond_inc") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    # =========================================================================
    describe "Conditional includes that already resolve correctly today" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/widget.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/widget.c"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/project_flag_extra.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/local_flag_extra.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/nested_wrapper.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/nested_extra.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/test/test_widget.c"), 'test/'

            settings = {
              :project => { :use_partials => true },
              :defines => { :test => ['PROJECT_FLAG'] }
            }
            @c.merge_project_yml_for_test(settings)
          end
        end
      end

      it "resolves a project-:defines-gated include, a same-file-#define-gated include, and correctly excludes a transitively-nested header from duplication" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:widget")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+3/)
            expect(output).to match(/PASSED:\s+3/)
            expect(output).to match(/FAILED:\s+0/)

            # (c) nested_extra.h is reached only transitively, through
            # nested_wrapper.h's own #include -- confirm it is not promoted
            # into a spurious, duplicated top-level #include in the generated
            # Partial implementation (the exact filtering property the #1223
            # fix must not break).
            generated = Dir.glob('build/test/partials/**/*_impl.c').first
            expect(generated).not_to be_nil
            contents = File.read(generated)
            expect(contents.scan(/#include\s+"nested_extra\.h"/).length).to eq(0)
          end
        end
      end

    end

    # =========================================================================
    describe "Conditional include gated on a macro from an earlier #include in the same file (issue #1223)" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/widget_feature.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/widget_feature.c"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/feature_config.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/src/feature_extra.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_conditional_includes/test/test_widget_feature.c"), 'test/'

            settings = { :project => { :use_partials => true } }
            @c.merge_project_yml_for_test(settings)
          end
        end
      end

      it "keeps FEATURE_EXTRA_MACRO visible in the generated Partial so the build compiles" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:widget_feature")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

    end

  end

end
