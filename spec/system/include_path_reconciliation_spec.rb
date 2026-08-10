# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Include Path Reconciliation
## ============================
##
## A single test file may legitimately #include two different headers that
## happen to share a basename, as long as each #include names enough path to
## tell them apart (e.g. "foo/bar.h" and "baz/bar.h"). Deduping and reconciling
## these by basename alone would collapse the two into one and leave no way to
## tell a genuinely ambiguous bare-list correspondence from a legitimate one --
## Ceedling does both by path instead.
##
## This test confirms both same-named headers survive #include extraction and
## reconciliation as distinct entries, and that both modules-under-test
## actually compile, link, and run correctly in the same test executable.
##
## Test assets: assets/fixtures/sources_with_duplicate_basenames/
##   - foo/bar.c, foo/bar.h: defines foo_bar_value() returning 111
##   - baz/bar.c, baz/bar.h: defines baz_bar_value() returning 222
##   - test_both_bars.c: #includes both "foo/bar.h" and "baz/bar.h",
##     asserting both functions return their distinct values
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("dup_include_name") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")

        Dir.chdir @proj_name do
          FileUtils.mkdir_p 'src/foo'
          FileUtils.mkdir_p 'src/baz'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/foo/bar.c"), 'src/foo/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/foo/bar.h"), 'src/foo/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/baz/bar.c"), 'src/baz/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/baz/bar.h"), 'src/baz/'
          FileUtils.cp test_asset_path("sources_with_duplicate_basenames/test_both_bars.c"), 'test/'
        end
      end
    end

    # =========================================================================
    describe "A test file that #includes two different same-basename headers" do
    # =========================================================================

      it "compiles, links, and passes with both modules-under-test present and correct" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Ambiguous/)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

    end

  end

end
