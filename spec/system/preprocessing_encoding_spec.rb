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

  before { @proj_name = "encoding_test_proj" }
  after  { @c.with_context { FileUtils.rm_rf @proj_name } }

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
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.h"),       'src/'
            FileUtils.cp test_asset_path("tests_with_encoding/src/unicoder.c"),       'src/'
            FileUtils.cp test_asset_path("tests_with_encoding/test/test_unicoder.c"), 'test/'
          end
        end
      end

      it "can test with standard preprocessing when source files contain non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :mocks } })
            output = @c.ceedling_build_exec("test:unicoder")
            expect(@c.last_exit_status).to eq(0)
            expect(output).not_to match(/using fallback method/i)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)
          end
        end
      end

      it "can test with fallback preprocessing when source files contain non-ASCII UTF-8 characters in comments" do
        @c.with_context do
          Dir.chdir @proj_name do
            settings = {
              :project    => { :use_test_preprocessor => :mocks },
              :test_build => { :preprocessing_fallback => true }
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
    end
  end
end
