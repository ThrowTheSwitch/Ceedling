# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# Every other system test either leaves :compile_threads/:test_threads at
# their default of 1 (fully serial, no real thread pool spun up at all) or
# relies on :auto (a worker count derived from the host machine's own CPU
# count, different on every runner). Neither setup ever deterministically
# exercises Batchinator's real multi-thread path -- a genuine concurrency
# bug (e.g. a caller forgetting to synchronize shared state under
# state.lock) could regress without any existing system test ever seeing
# more than one worker thread active, or seeing a worker count that varies
# machine to machine.
#
# This test pins both thread counts to a small, fixed value greater than
# one so real parallel compilation and real parallel test execution both
# happen on every run, everywhere, and asserts on correctness of the
# result (right pass/fail counts, right modules run) -- not just "the
# build didn't crash." wondrous_forest is reused as the multi-file fixture
# since its correct, fully-passing counts are already an established
# baseline elsewhere (see example_wondrous_forest_spec.rb).
ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  describe "Parallel work with a small, fixed thread count (wondrous_forest)" do
    before do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("example wondrous_forest")
        expect(output).to match(/created/)

        Dir.chdir "wondrous_forest" do
          @c.ceedling_build_exec("clobber")
        end
      end
    end

    it "builds and runs every test correctly with :compile_threads and :test_threads both pinned to 2" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          @c.merge_project_yml_for_test({
            :project => { :compile_threads => 2, :test_threads => 2 }
          })

          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+68/)
          expect(output).to match(/PASSED:\s+68/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end

    it "builds and runs every test correctly with asymmetric small :compile_threads and :test_threads values" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          @c.merge_project_yml_for_test({
            :project => { :compile_threads => 3, :test_threads => 2 }
          })

          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+68/)
          expect(output).to match(/PASSED:\s+68/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end

    it "attributes results to the correct module when testing a pattern subset under pinned threads" do
      @c.with_context do
        Dir.chdir "wondrous_forest" do
          @c.merge_project_yml_for_test({
            :project => { :compile_threads => 2, :test_threads => 2 }
          })

          output = @c.ceedling_build_exec("test:pattern[Sensor]")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/PASSED/)
          expect(output).to match(/FAILED:\s+0/)
          expect(output).to match(/TemperatureSensor\.out/i)
          expect(output).to match(/HumiditySensor\.out/i)
          expect(output).to match(/LightSensor\.out/i)
        end
      end
    end
  end
end
