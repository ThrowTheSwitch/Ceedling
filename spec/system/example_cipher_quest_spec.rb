# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

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

  describe "Command: `ceedling examples`" do
    before do
      @c.with_context do
        @output = @c.ceedling_appcmd_exec("examples")
      end
    end

    it "should list cipher_quest as an available example" do
      expect(@output).to match(/cipher_quest/)
    end
  end

  describe "Command: `ceedling example cipher_quest`" do
    describe "cipher_quest" do
      before do
        @c.with_context do
          output = @c.ceedling_appcmd_exec("example cipher_quest")
          expect(output).to match(/created/)
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

      it "should build a release binary with the ROT13 inline YAML mixin" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("release --mixin \"=defines: {release: ['CIPHER_ROT13']}\"")
            expect(@output).to match(/Merging command line inline YAML mixin/)
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

      it "should build a release binary with the Caesar cipher inline YAML mixin" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("release --mixin \"=defines: {release: ['CIPHER_CAESAR']}\"")
            expect(@output).to match(/Merging command line inline YAML mixin/)
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

      it "should build a release binary with the full-featured inline YAML mixin" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("release --mixin \"=defines: {release: ['CIPHER_ROT13', 'CIPHER_CAESAR', 'ANALYZER_ENABLED']}\"")
            expect(@output).to match(/Merging command line inline YAML mixin/)
            expect(@output).to match(/cipher_quest\.out/)
          end
        end
      end

      it "should be able to report header files found in paths" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("files:header")
            expect(@output).to match(/Header files:/i)
            expect(@output).to match(/text_utils\.h/i)
            expect(@output).to match(/cipher\.h/i)
            expect(@output).to match(/analyzer\.h/i)
          end
        end
      end

      it "should be able to report source files found in paths" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("files:source")
            expect(@output).to match(/Source files:/i)
            expect(@output).to match(/text_utils\.c/i)
            expect(@output).to match(/cipher\.c/i)
            expect(@output).to match(/analyzer\.c/i)
            expect(@output).to match(/main\.c/i)
          end
        end
      end

      it "should be able to report test files found in paths" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("files:test")
            expect(@output).to match(/Test files:/i)
            expect(@output).to match(/TestTextUtils\.c/i)
            expect(@output).to match(/TestCipherRot13\.c/i)
            expect(@output).to match(/TestCipherCaesar\.c/i)
            expect(@output).to match(/TestAnalyzer\.c/i)
          end
        end
      end

      it "should be able to report include paths" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("paths:include")
            expect(@output).to match(/Include paths:/i)
            expect(@output).to match(/src/i)
          end
        end
      end

      it "should be able to report test paths" do
        @c.with_context do
          Dir.chdir "cipher_quest" do
            @output = @c.ceedling_build_exec("paths:test")
            expect(@output).to match(/Test paths:/i)
            expect(@output).to match(/test/i)
          end
        end
      end

    end
  end
end
