# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Header #include Path Validation & Mirroring Consistency
## ==========================================================
##
## Two related properties of a #include'd header (mock or vanilla), neither
## previously enforced:
##
## 1. A #include's path -- however much or little it carries -- must resolve to
##    exactly one real header in the project's header collection. A path that
##    matches nothing is a hard error (not silently resolved by basename alone,
##    which would let a bogus leading path go completely unnoticed), the same
##    hard-ambiguity-or-not-found policy applied everywhere else a query is
##    matched against a collection of real files.
##
## 2. A mock's own generated location mirrors its real header's resolved
##    location -- not however much path the #include itself happened to carry.
##    Two test files #including the very same header, one bare and one with a
##    disambiguating path, must place that header's mock in the very same spot.
##
## Test assets: assets/fixtures/header_include_path_validation/
##   - drivers/foo.h: declares foo_value(void), no corresponding .c (mocked only)
##   - bar.h: defines BAR_VALUE, a plain (non-mocked) header
##   - test_bare_mock.c: #include "Mockfoo.h" (bare)
##   - test_pathed_mock.c: #include "drivers/Mockfoo.h" (disambiguating path)
##   - test_bogus_mock_path.c: #include "totally/bogus/dir/Mockfoo.h"
##   - test_bogus_vanilla_path.c: #include "totally/bogus/dir/bar.h"
##

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("header_path_validation") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    # =========================================================================
    describe "A mock's own generated location, regardless of #include specificity" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.mkdir_p 'src/drivers'
            FileUtils.cp test_asset_path("header_include_path_validation/drivers/foo.h"), 'src/drivers/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_bare_mock.c"), 'test/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_pathed_mock.c"), 'test/'
          end
        end
      end

      it "is identical whether the #include is bare or carries a disambiguating path" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Ambiguous/)
            expect(output).to match(/TESTED:\s+2/)
            expect(output).to match(/PASSED:\s+2/)

            expect(File.exist?('build/test/mocks/test_bare_mock/drivers/Mockfoo.h')).to be true
            expect(File.exist?('build/test/mocks/test_pathed_mock/drivers/Mockfoo.h')).to be true
          end
        end
      end

    end

    # =========================================================================
    describe "A bogus path ahead of a mocked header's filename" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.mkdir_p 'src/drivers'
            FileUtils.cp test_asset_path("header_include_path_validation/drivers/foo.h"), 'src/drivers/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_bogus_mock_path.c"), 'test/'
          end
        end
      end

      it "is rejected rather than silently resolved by basename alone" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).not_to eq(0)
            expect(output).to_not match(/TESTED:\s+1/)
          end
        end
      end

    end

    # =========================================================================
    describe "A bogus path ahead of a plain (non-mocked) header's filename" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("header_include_path_validation/bar.h"), 'src/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_bogus_vanilla_path.c"), 'test/'
          end
        end
      end

      it "is rejected rather than being silently ignored" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).not_to eq(0)
            expect(output).to_not match(/TESTED:\s+1/)
          end
        end
      end

    end

  end

end
