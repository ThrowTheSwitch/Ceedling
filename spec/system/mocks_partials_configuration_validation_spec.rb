# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Mocks/Partials Configuration Validation
## ==========================================
##
## A test file's own #includes are scanned for the mock and Partials naming
## conventions regardless of whether either feature is actually configured
## on for the project -- a test #including a Mock*.h header, or using a
## TEST_PARTIAL_*_MODULE()/MOCK_PARTIAL_*_MODULE() macro, with the
## corresponding project feature turned off is a real, loud configuration
## mistake (the test author almost certainly meant to enable the feature),
## not something to silently ignore or fail at some much later, harder to
## diagnose compile/link stage.
##

MOCK_WITHOUT_CONFIG_C = <<~C
  #include "unity.h"
  #include "mock_foo.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_dummy(void) { TEST_ASSERT_TRUE(1); }
C

PARTIAL_WITHOUT_CONFIG_C = <<~C
  #include "unity.h"
  #include "ceedling.h"
  #include TEST_PARTIAL_PUBLIC_MODULE(Foo)

  void setUp(void) {}
  void tearDown(void) {}

  void test_dummy(void) { TEST_ASSERT_TRUE(1); }
C

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("mocks_partials_config") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    describe "a test #including a mock while mocking is disabled" do
      before do
        @c.with_context do
          Dir.chdir @proj_name do
            @c.merge_project_yml_for_test({ :project => { :use_mocks => false } })
            File.write('test/test_mock_without_config.c', MOCK_WITHOUT_CONFIG_C)
          end
        end
      end

      it "fails the build naming the offending test file and mock" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).not_to eq(0)
            expect(output).to match(/not configured for mocking/)
            expect(output).to match(/test_mock_without_config\.c/)
            expect(output).to match(/mock_foo\.h/)
          end
        end
      end
    end

    describe "a test using a Partial while Partials are disabled (the project default)" do
      before do
        @c.with_context do
          Dir.chdir @proj_name do
            # Partials configuration macros are only scanned for when test
            # preprocessing is on -- off (:none) is this project's own default.
            @c.merge_project_yml_for_test({ :project => { :use_test_preprocessor => :all } })
            File.write('test/test_partial_without_config.c', PARTIAL_WITHOUT_CONFIG_C)
          end
        end
      end

      it "fails the build naming the offending test file" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")
            expect(@c.last_exit_status).not_to eq(0)
            expect(output).to match(/not configured for Partials/)
            expect(output).to match(/test_partial_without_config\.c/)
          end
        end
      end
    end
  end

end
