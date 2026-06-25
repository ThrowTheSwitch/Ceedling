# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("encoding") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    describe "Test builds with multibyte UTF-8 characters in C source file comments" do
      before do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.h"), 'src/'
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.c"), 'src/'
          end
        end
      end

      it "tests standard preprocessing with non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
            @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :mocks } })
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            # Only assert non-fallback when the platform actually supports -fdirectives-only.
            # Apple clang (macOS) silently ignores the flag and ceedling falls back automatically.
            expect(output).not_to match(/using fallback method/i) unless output.match(/lacks -fdirectives-only support/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests fallback preprocessing with non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
            settings = {
              :project    => { :use_test_preprocessor => :mocks },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests Partials with standard preprocessing and non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder_partial.c"), 'test/'
            # :use_partials automatically enables mocking and preprocessing — no explicit
            # :use_test_preprocessor needed.
            @c.merge_project_yml_for_test({ :project => { :use_partials => true } })
            output = @c.ceedling_build_exec("test:unicoder_partial")
            expect(@c.last_exit_status).to eq(0)
            # Only assert non-fallback when the platform actually supports -fdirectives-only.
            # Apple clang (macOS) silently ignores the flag and ceedling falls back automatically.
            expect(output).not_to match(/using fallback method/i) unless output.match(/lacks -fdirectives-only support/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "tests Partials with fallback preprocessing and non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder_partial.c"), 'test/'
            settings = {
              :project    => { :use_partials => true },
              :test_build => { :preprocess_force_fallback => true }
            }
            @c.merge_project_yml_for_test(settings)
            output = @c.ceedling_build_exec("test:unicoder_partial")
            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end
    end
  end
end
