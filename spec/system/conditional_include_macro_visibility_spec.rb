# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Conditional-#include Macro-Visibility -- end-to-end smoke
## =======================================================
##
## The detail of how Ceedling reconciles a file's #includes across its bare and
## accurate preprocessor passes -- project-:defines guards, same-file #define
## guards, sibling-header-macro guards (issue #1223), a sibling-header-macro-guarded
## *computed* include split across a backslash continuation (issue #1267),
## transitive headers not promoted to spurious top-level entries -- is characterized
## directly against real GCC in spec/integration/includes_extraction_spec.rb. This
## spec keeps one full `ceedling` build over all of those shapes at once, to prove
## the pieces still fit together through a real Partials build.
##
## Assets: assets/fixtures/tests_with_conditional_includes/
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
        Dir.chdir @proj_name do
          %w[
            widget.h widget.c project_flag_extra.h local_flag_extra.h
            nested_wrapper.h nested_extra.h macro_target_extra.h
            widget_feature.h widget_feature.c feature_config.h feature_extra.h
            feature_extra2.h
          ].each { |f| FileUtils.cp test_asset_path("tests_with_conditional_includes/src/#{f}"), 'src/' }
          %w[test_widget.c test_widget_feature.c].each do |f|
            FileUtils.cp test_asset_path("tests_with_conditional_includes/test/#{f}"), 'test/'
          end

          @c.merge_project_yml_for_test(
            :project => { :use_partials => true },
            :defines => { :test => ['PROJECT_FLAG'] }
          )
        end
      end
    end

    it "builds and passes every conditional-#include Partials scenario in one run" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+5/)
          expect(output).to match(/PASSED:\s+5/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end
  end

end
