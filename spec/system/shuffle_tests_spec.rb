# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Randomized Test Execution Order (:unity ↳ :shuffle_tests)
## ==========================================================
##
## Unity's runner generator can shuffle the order test cases run in, seeded by
## :test_runner ↳ :rng_seed. Unity always prints each test's name as it runs
## (`<file>:<line>:<test name>:PASS`, regardless of verbosity), so the order
## tests actually ran in is recoverable straight from build console output --
## no need to inspect the generated runner file itself.
##
## Test content is trivial (five independent, empty-bodied passing tests with
## alphabetically distinct names) so it's inlined here as a heredoc rather
## than a checked-in assets/fixtures file.
##

SHUFFLE_TEST_C = <<~C
  #include "unity.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_A(void) { TEST_ASSERT_TRUE(1); }
  void test_B(void) { TEST_ASSERT_TRUE(1); }
  void test_C(void) { TEST_ASSERT_TRUE(1); }
  void test_D(void) { TEST_ASSERT_TRUE(1); }
  void test_E(void) { TEST_ASSERT_TRUE(1); }
C

# Source declaration order -- the order a non-shuffled runner always executes
# these tests in.
DECLARED_ORDER = %w[test_A test_B test_C test_D test_E]

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("shuffle") }

  # Extracts the sequence of test names in the order Unity printed them
  # (each PASS line matches `<file>:<line>:<test name>:PASS`).
  def executed_order(output)
    output.to_s.scan(/test_shuffle\.c:\d+:(test_\w+):PASS/)
          .flatten
          .select { |name| DECLARED_ORDER.include?( name ) }
  end

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    before do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('test/test_shuffle.c', SHUFFLE_TEST_C)
        end
      end
    end

    it "runs tests in declared order by default (:shuffle_tests disabled)" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+5/)
          expect(output).to match(/PASSED:\s+5/)
          expect(output).to match(/FAILED:\s+0/)

          expect(executed_order(output)).to eq(DECLARED_ORDER)
        end
      end
    end

    it "runs tests in a randomized order when :shuffle_tests is enabled with a fixed :rng_seed" do
      @c.with_context do
        Dir.chdir @proj_name do
          settings = {
            :unity       => { :shuffle_tests => true },
            :test_runner => { :rng_seed => 42 },
          }
          @c.merge_project_yml_for_test(settings)

          output = @c.ceedling_build_exec

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+5/)
          expect(output).to match(/PASSED:\s+5/)
          expect(output).to match(/FAILED:\s+0/)

          order = executed_order(output)
          expect(order.sort).to eq(DECLARED_ORDER.sort) # same five tests, all present
          expect(order).to_not eq(DECLARED_ORDER)        # but not in declared order
        end
      end
    end

  end

end
