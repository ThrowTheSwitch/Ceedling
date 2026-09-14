# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## cipher_quest Example Project
## ===============================
##
## `files:*`/`paths:*` reporting, previously checked here too, now lives
## solely in files_paths_reporting_spec.rb. The inline-YAML mixin duplicates
## of each release build are dropped -- inline-YAML *syntax* is proven once by
## mixin_ordering_spec.rb/mixin_loading_spec.rb, and repeating it per release
## scenario here added nothing the sigil-file builds below don't already
## prove. What's kept: `test:all`, the `#error`-without-mixin failure (a guard
## specific to this project's own shipped main.c, no analog elsewhere), and
## all three sigil-file release builds -- ROT13, Caesar, and full-featured are
## functionally distinct feature-selection scenarios, not redundant with each
## other.
##

ceedling_system_tests do
  include CommonSystemTestCases

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = "cipher_quest" }

  describe "Command: `ceedling example cipher_quest`" do
    describe "cipher_quest" do
      before do
        @c.with_context do
          output = @c.ceedling_appcmd_exec("example cipher_quest")
          expect(output).to match(/created/)

          # `ceedling example` only overwrites src/, test/, mixin/, and project.yml --
          # it never touches build/. Without clobbering it here, a dependency cache
          # populated by an earlier example in this describe block would carry over
          # and make delta-build staleness tracking correctly (but unhelpfully, for
          # these tests) treat this "fresh" example as already fully built.
          Dir.chdir "cipher_quest" do
            @c.ceedling_build_exec("clobber")
          end
        end
      end

      it "should run all tests with all passing" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("test:all")
            expect(@output).to match(/TESTED:\s+59/)
            expect(@output).to match(/PASSED:\s+59/)
            expect(@output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "should fail to build a release binary without a mixin" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            # Without any feature symbols, main.c raises a #error — build must fail
            @output = @c.ceedling_build_exec("release")
            expect(@output).to match(/No feature defined/i)
          end
        end
      end

      it "should build a release binary with the ROT13 file mixin via sigil" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("release --mixin=@mixin/release_rot13.yml")
            expect(@output).to match(/Merging command line mixin using mixin\/release_rot13\.yml/)
            expect(@output).to match(/cipher_quest\.out/)
          end
        end
      end

      it "should build a release binary with the Caesar cipher file mixin via sigil" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("release --mixin=@mixin/release_caesar.yml")
            expect(@output).to match(/Merging command line mixin using mixin\/release_caesar\.yml/)
            expect(@output).to match(/cipher_quest\.out/)
          end
        end
      end

      it "should build a release binary with the full-featured file mixin via sigil" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("release --mixin=@mixin/release_full.yml")
            expect(@output).to match(/Merging command line mixin using mixin\/release_full\.yml/)
            expect(@output).to match(/cipher_quest\.out/)
          end
        end
      end

    end
  end
end
