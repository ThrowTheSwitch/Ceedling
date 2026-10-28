# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Tests Under Paths Holding Shell Characters Run (issue #1373)
## ==============================================================
##
## A test's executable sits beneath its path from the project root, and tools run through
## the system shell. The default tools that run a test executable named it unquoted, so a
## test under `test/o'neil/` reported every case as a crash, and one under `test/my dir/`
## stopped the build. Each runs here, with a pass, a failure, and a crash that the simple
## backtrace reruns pin to its own case.
##

SPECIAL_PATH_TEST_C = <<~C
  #include "unity.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_passes(void) { TEST_ASSERT_TRUE(1); }
  void test_fails(void)  { TEST_ASSERT_EQUAL_INT(1, 2); }
C

SPECIAL_PATH_CRASH_C = <<~C

  void test_crashes(void) { volatile int *p = 0; *p = 1; }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "special_path"

  ["o'neil", "my dir"].each do |directory|
    describe "A test under `test/#{directory}/`" do
      before do
        in_project do
          FileUtils.mkdir_p( "test/#{directory}" )
          File.write( "test/#{directory}/test_special.c", SPECIAL_PATH_TEST_C )
        end
      end

      it "runs a test under `test/#{directory}/`, reporting each case's own result" do
        in_project do
          output = @c.ceedling_build_exec( "test:all" )

          expect(@c.last_exit_status).to eq(1), output
          expect(output).to_not match(/crashed/i)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+1/)
        end
      end

      it "pins a crash under `test/#{directory}/` to its own case through simple backtrace reruns" do
        in_project do
          File.write( "test/#{directory}/test_special.c", SPECIAL_PATH_TEST_C + SPECIAL_PATH_CRASH_C )

          output = @c.ceedling_build_exec( "test:all" )

          expect(output).to match(/Test: test_crashes/)
          expect(output).to match(/TESTED:\s+3/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+2/)
        end
      end

      it "runs a test under `test/#{directory}/` with gcov" do
        in_project do
          @c.merge_project_yml_for_test( {:plugins => {:enabled => ['gcov']}} )

          output = @c.ceedling_build_exec( "gcov:all" )

          expect(output).to_not match(/crashed/i)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+1/)
        end
      end
    end
  end
end
