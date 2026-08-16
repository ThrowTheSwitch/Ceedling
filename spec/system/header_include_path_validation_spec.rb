# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Header #include Path Validation
## =================================
##
## A #include's path -- however much or little it carries -- must resolve to
## exactly one real header in the project's header collection. A path that
## matches nothing is still a hard error (not silently resolved by basename
## alone, which would let a bogus leading path go completely unnoticed). A path
## that matches more than one real header, however, resolves to the first
## candidate by this test's own search-path order (mirroring the order the
## real compiler's own -I flags would search), logging an ℹ️ NOTICE naming what
## else matched rather than halting the build -- the same policy applied
## everywhere else a query is matched against a collection of real files. This
## applies to both mocks (find_header_input_for_mock) and ordinary, non-mock
## headers (validate_header_includes).
##
## A directory named via TEST_INCLUDE_PATH() ranks ahead of :paths -> :include
## in that search-path order, so an ambiguous #include resolves to the
## TEST_INCLUDE_PATH()-supplied header even when a same-named :include header
## would otherwise come first alphabetically.
##
## A mock's own generated location mirrors its real header's resolved path, not
## the #include's own path -- so a mock's location stays stable regardless of
## how much disambiguating path a given #include happens to carry, and no stale
## mock is ever left behind under a differently-shaped path when a #include's
## specificity changes between builds. Since C's own #include resolution has no
## notion of a recursive search path, the compiler can only find a mock via a
## search path pointing directly at wherever it actually lives, so that
## mirrored directory is folded into the test's own search paths alongside the
## flat per-test mock root. The first test below confirms a mock whose real
## header lives in a subdirectory compiles correctly whether its #include is
## bare or carries a disambiguating path -- both land at the same mirrored
## location, since both name the same real header.
##
## Test assets: assets/fixtures/header_include_path_validation/
##   - drivers/foo.h, alt_drivers/foo.h: identical declarations of foo_value(void),
##     no corresponding .c (mocked only) -- two same-named headers in different
##     :include-configured subdirectories
##   - bar.h: defines BAR_VALUE, a plain (non-mocked) header
##   - other_inc/dup.h: #define DUP_VALUE 111 -- reached only via TEST_INCLUDE_PATH()
##   - dup.h (copied to src/): #define DUP_VALUE 222 -- reached via :include
##   - test_bare_mock.c: #include "mock_foo.h" (bare)
##   - test_pathed_mock.c: #include "drivers/mock_foo.h" (disambiguating path)
##   - test_bogus_mock_path.c: #include "totally/bogus/dir/mock_foo.h"
##   - test_bogus_vanilla_path.c: #include "totally/bogus/dir/bar.h"
##   - test_ambiguous_mock.c: #include "mock_foo.h" (bare), ambiguous between
##     src/alt_drivers/foo.h and src/drivers/foo.h
##   - test_test_include_path_outranks_include.c: TEST_INCLUDE_PATH("other_inc"),
##     then #include "dup.h" (bare), ambiguous between other_inc/dup.h and src/dup.h
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
    describe "A mock whose real header lives in a subdirectory" do
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

      it "compiles whether the #include is bare or carries a disambiguating path" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Ambiguous/)
            expect(output).to match(/TESTED:\s+2/)
            expect(output).to match(/PASSED:\s+2/)

            # A mock's location mirrors its real header's resolved path, not whatever path its
            # own #include happened to write, so both tests' mocks land at the identical
            # location -- each #include names the same real header, drivers/foo.h.
            expect(File.exist?('build/test/mocks/test_bare_mock/drivers/mock_foo.h')).to be true
            expect(File.exist?('build/test/mocks/test_pathed_mock/drivers/mock_foo.h')).to be true
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

    # =========================================================================
    describe "A mocked header whose same name exists in two configured :include directories" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.mkdir_p 'src/drivers'
            FileUtils.mkdir_p 'src/alt_drivers'
            FileUtils.cp test_asset_path("header_include_path_validation/drivers/foo.h"), 'src/drivers/'
            FileUtils.cp test_asset_path("header_include_path_validation/alt_drivers/foo.h"), 'src/alt_drivers/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_ambiguous_mock.c"), 'test/'
          end
        end
      end

      it "resolves to the first candidate by search-path order, logging a NOTICE naming the other" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/Multiple files matched/)
            expect(output).to match(/alt_drivers[\/\\]foo\.h/)
            expect(output).to match(/drivers[\/\\]foo\.h/)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)

            # alt_drivers sorts ahead of drivers within :include's single src/** glob,
            # so the generated mock mirrors alt_drivers/foo.h's own location.
            expect(File.exist?('build/test/mocks/test_ambiguous_mock/alt_drivers/mock_foo.h')).to be true
          end
        end
      end

      it "resolves to the non-default candidate when disambiguated by path, logging nothing" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("header_include_path_validation/test_pathed_mock_ambiguous.c"), 'test/'
            output = @c.ceedling_build_exec("test:test_pathed_mock_ambiguous.c")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Multiple files matched/)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)

            expect(File.exist?('build/test/mocks/test_pathed_mock_ambiguous/drivers/mock_foo.h')).to be true
          end
        end
      end

    end

    # =========================================================================
    describe "A plain (non-mocked) header reachable both via TEST_INCLUDE_PATH() and :include" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.mkdir_p 'other_inc'
            FileUtils.cp test_asset_path("header_include_path_validation/other_inc/dup.h"), 'other_inc/'
            FileUtils.cp test_asset_path("header_include_path_validation/dup.h"), 'src/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_test_include_path_outranks_include.c"), 'test/'
          end
        end
      end

      it "resolves to the TEST_INCLUDE_PATH()-supplied header, ranked ahead of :include" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/Multiple files matched/)
            expect(output).to match(/other_inc[\/\\]dup\.h/)
            expect(output).to match(/src[\/\\]dup\.h/)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

      it "resolves to the :include-supplied header instead when disambiguated by path, logging nothing" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.mkdir_p 'src/inc_dup'
            FileUtils.cp test_asset_path("header_include_path_validation/dup.h"), 'src/inc_dup/'
            FileUtils.cp test_asset_path("header_include_path_validation/test_include_outranks_test_include_path.c"), 'test/'

            output = @c.ceedling_build_exec("test:test_include_outranks_test_include_path.c")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to_not match(/Multiple files matched/)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
          end
        end
      end

    end

  end

end
