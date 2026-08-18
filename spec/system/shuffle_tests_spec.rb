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
## Test content is trivial (ten independent, empty-bodied passing tests with
## alphabetically distinct names) so it's inlined here as a heredoc rather
## than a checked-in assets/fixtures file. Ten test cases (10! = 3,628,800
## possible orderings) keeps the odds of a fixed seed's shuffle coincidentally
## landing back on declared order effectively negligible -- a C library's
## rand() sequence for a given seed is implementation-defined and differs
## across platforms, so a small test count risks exactly that coincidence on
## some platform even though shuffling is working correctly.
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
  void test_F(void) { TEST_ASSERT_TRUE(1); }
  void test_G(void) { TEST_ASSERT_TRUE(1); }
  void test_H(void) { TEST_ASSERT_TRUE(1); }
  void test_I(void) { TEST_ASSERT_TRUE(1); }
  void test_J(void) { TEST_ASSERT_TRUE(1); }
C

# Source declaration order -- the order a non-shuffled runner always executes
# these tests in.
DECLARED_ORDER = %w[test_A test_B test_C test_D test_E test_F test_G test_H test_I test_J]

# Several successive, fixed seeds rather than one -- asserting that shuffled
# order varies *somewhere* across these runs (rather than requiring every
# adjacent pair to differ) confirms seeding actually changes execution order
# without a single unlucky seed/platform combination failing the whole test.
SHUFFLE_SEEDS = [42, 43, 44, 45]

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
          expect(output).to match(/TESTED:\s+10/)
          expect(output).to match(/PASSED:\s+10/)
          expect(output).to match(/FAILED:\s+0/)

          expect(executed_order(output)).to eq(DECLARED_ORDER)
        end
      end
    end

    it "runs tests in a randomized order when :shuffle_tests is enabled with fixed :rng_seed values" do
      @c.with_context do
        Dir.chdir @proj_name do
          orders = SHUFFLE_SEEDS.map do |seed|
            settings = {
              :unity       => { :shuffle_tests => true },
              :test_runner => { :rng_seed => seed },
            }
            @c.merge_project_yml_for_test(settings)

            output = @c.ceedling_build_exec

            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+10/)
            expect(output).to match(/PASSED:\s+10/)
            expect(output).to match(/FAILED:\s+0/)

            order = executed_order(output)
            expect(order.sort).to eq(DECLARED_ORDER.sort) # same ten tests, all present

            order
          end

          expect(orders.uniq.size).to be > 1 # shuffling varied order somewhere across these seeds
        end
      end
    end

  end

end
