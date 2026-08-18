# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# End-to-end coverage of the gen: namespace's pipeline stop-point tasks
# (TestPipelineManager) against a real example project on disk -- proving each
# task halts the test-build pipeline at its named stage rather than merely
# succeeding.
ceedling_system_tests do
  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  describe "Pipeline stop points (temp_sensor)" do
    before do
      @c.with_context do
        output = @c.ceedling_appcmd_exec("example temp_sensor")
        expect(output).to match(/created/)

        # `example` only deploys src/test/project.yml -- a build/ directory left
        # over from a prior example in this same shared context would make this
        # test's targets look already fresh. Clobber guarantees an empty cache.
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("clobber")
        end
      end
    end

    it "gen:mocks generates mocks but compiles, links, and runs nothing, announcing a mocks-only run" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("gen:mocks")

          expect(output).to match(/Generating mock for adc\/TestAdcModel::TaskScheduler\.h/)
          expect(output).to_not match(/Generating runner for/)
          expect(output).to_not match(/^Compiling /)
          expect(output).to_not match(/^Linking /)
          expect(output).to_not match(/^Running /)
          expect(output).to match(/Generating mocks only -- no test runners, compiling, linking, or running\./)

          # Regression guard: gen: tasks must be recognized as build tasks (see
          # tasks_tests_generate.rake/rules_tests_generate.rake's own namespace-nesting
          # comments) so timing/completion logging isn't silently suppressed.
          expect(output).to match(/Ceedling operations completed/)
          expect(output).to match(/-+\n\s*MOCKS GENERATED\n-+/)
        end
      end
    end

    it "gen:test_runner generates mocks and runners but compiles, links, and runs nothing, announcing a mocks-and-runners-only run" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("gen:test_runner")

          expect(output).to match(/Generating mock for adc\/TestAdcModel::TaskScheduler\.h/)
          expect(output).to match(/Generating runner for TestAdcModel\.c/)
          expect(output).to_not match(/^Compiling /)
          expect(output).to_not match(/^Linking /)
          expect(output).to_not match(/^Running /)
          expect(output).to match(/Generating mocks and test runners only -- no compiling, linking, or running\./)

          expect(output).to match(/Ceedling operations completed/)
          expect(output).to match(/-+\n\s*MOCKS & TEST RUNNERS GENERATED\n-+/)
        end
      end
    end

    it "gen:mocks:<file> generates only that one test's mocks, not every test's" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("gen:mocks:TestAdcModel.c")

          expect(output).to match(/Generating mock for adc\/TestAdcModel::TaskScheduler\.h/)
          # TestAdcModel.c mocks TaskScheduler, TemperatureCalculator, and TemperatureFilter --
          # exactly its own 3 mocks, none belonging to any other test.
          expect(output.to_s.scan(/Generating mock for /).length).to eq(3)
          expect(output).to_not match(/Generating runner for/)
          expect(output).to_not match(/^Compiling /)
          expect(output).to_not match(/^Linking /)
          expect(output).to_not match(/^Running /)
          expect(output).to match(/Generating mocks only -- no test runners, compiling, linking, or running\./)

          expect(output).to match(/Ceedling operations completed/)
          expect(output).to match(/-+\n\s*MOCKS GENERATED\n-+/)
        end
      end
    end

    it "gen:test_runner:<file> generates only that one test's mock(s) and runner, not every test's" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("gen:test_runner:TestAdcModel.c")

          expect(output).to match(/Generating mock for adc\/TestAdcModel::TaskScheduler\.h/)
          # TestAdcModel.c mocks TaskScheduler, TemperatureCalculator, and TemperatureFilter --
          # exactly its own 3 mocks, none belonging to any other test.
          expect(output.to_s.scan(/Generating mock for /).length).to eq(3)
          expect(output).to match(/Generating runner for TestAdcModel\.c/)
          expect(output.to_s.scan(/Generating runner for /).length).to eq(1)
          expect(output).to_not match(/^Compiling /)
          expect(output).to_not match(/^Linking /)
          expect(output).to_not match(/^Running /)
          expect(output).to match(/Generating mocks and test runners only -- no compiling, linking, or running\./)

          expect(output).to match(/Ceedling operations completed/)
          expect(output).to match(/-+\n\s*MOCKS & TEST RUNNERS GENERATED\n-+/)
        end
      end
    end

    it "test:build_only builds test executables but does not run them, ending with its own completed-operations line and BUILT banner" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("test:build_only")

          expect(output).to match(/^Compiling /)
          expect(output).to match(/^Linking /)
          expect(output).to_not match(/^Running /)
          expect(output).to match(/Building test executables only -- not running them\./)
          expect(output).to match(/Ceedling operations completed/)
          expect(output).to match(/-+\n\s*TEST EXECUTABLES BUILT\n-+/)
        end
      end
    end

    it "does not interfere with a subsequent test:all run's own dependency cache, and a full run announces no partial run scope or BUILT banner" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("gen:test_runner")

          rebuild = @c.ceedling_build_exec("test:all")
          expect(rebuild).to match(/^Compiling /)
          expect(rebuild).to match(/^Linking /)
          expect(rebuild).to match(/^Running /)
          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)
          expect(rebuild).to_not match(/Generating mocks only/)
          expect(rebuild).to_not match(/Generating mocks and test runners only/)
          expect(rebuild).to_not match(/Building test executables only/)
          expect(rebuild).to_not match(/Determining test sources only/)
          expect(rebuild).to match(/Ceedling operations completed/)
          expect(rebuild).to_not match(/MOCKS GENERATED/)
          expect(rebuild).to_not match(/MOCKS & TEST RUNNERS GENERATED/)
          expect(rebuild).to_not match(/TEST EXECUTABLES BUILT/)
          expect(rebuild).to_not match(/TEST SOURCES DETERMINED/)
        end
      end
    end
  end
end
