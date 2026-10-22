# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Rake Test Task Path Disambiguation
## ===================================
##
## A project may have two test files with the same basename in different test
## directories (e.g. test/unit/test_foo.c and test/integration/test_foo.c). These
## tests confirm that invoking `test:test_foo.c` (bare name) is a hard error naming
## both candidates, while invoking `test:unit/test_foo.c` or `test:integration/test_foo.c`
## (enough trailing path to identify one of them) runs exactly that one test. The same
## disambiguating path also combines with Ceedling's longstanding convention of invoking
## a test by its module name alone, no test file prefix required (`test:unit/foo.c`
## resolving the same as `test:unit/test_foo.c`).
##
## Test assets: assets/fixtures/tests_with_duplicate_test_names/
##   - unit/test_foo.c: one passing test case
##   - integration/test_foo.c: a different passing test case, same filename
##
## A separate test below runs both same-named tests together via test:all, confirming
## their build-output directories (runners, objects, results) are each mirrored beneath
## the test's own identity rather than colliding on one flat, basename-keyed path.
##

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "dup_test_name"

  describe "Deployed as a gem" do

    # =========================================================================
    describe "A project with two same-named test files in different directories" do
    # =========================================================================

      before do
        in_project do
          copy_fixture("tests_with_duplicate_test_names/unit/test_foo.c", 'test/unit')
          copy_fixture("tests_with_duplicate_test_names/integration/test_foo.c", 'test/integration')
        end
      end

      it "hard-errors naming both candidates when invoked by bare basename" do
        in_project do
          output = @c.ceedling_build_exec("test:test_foo.c")
          expect(@c.last_exit_status).not_to eq(0)
          expect(output).to match(/Ambiguous/)
          expect(output).to match(/unit[\/\\]test_foo\.c/)
          expect(output).to match(/integration[\/\\]test_foo\.c/)
        end
      end

      it "runs exactly the unit test when disambiguated by path" do
        in_project do
          output = @c.ceedling_build_exec("test:unit/test_foo.c")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/test_this_is_the_unit_directory_test_foo/)
        end
      end

      it "runs exactly the integration test when disambiguated by path" do
        in_project do
          output = @c.ceedling_build_exec("test:integration/test_foo.c")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/test_this_is_the_integration_directory_test_foo/)
        end
      end

      it "runs exactly the unit test when disambiguated by path and invoked by bare module name (no test file prefix)" do
        in_project do
          output = @c.ceedling_build_exec("test:unit/foo.c")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/test_this_is_the_unit_directory_test_foo/)
        end
      end

      it "runs exactly the integration test when disambiguated by path and invoked by bare module name (no test file prefix)" do
        in_project do
          output = @c.ceedling_build_exec("test:integration/foo.c")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/test_this_is_the_integration_directory_test_foo/)
        end
      end

      it "runs both same-named tests together under test:all, each with its own correctly mirrored build output" do
        in_project do
          output = @c.ceedling_build_exec("test:all")
          expect(@c.last_exit_status).to eq(0)
          expect(output).to_not match(/Ambiguous/)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/test_this_is_the_unit_directory_test_foo/)
          expect(output).to match(/test_this_is_the_integration_directory_test_foo/)

          summary = @c.ceedling_build_exec("summary")
          expect(summary).to match(/TESTED:\s+2/)
          expect(summary).to match(/PASSED:\s+2/)
        end
      end

    end

  end

end
