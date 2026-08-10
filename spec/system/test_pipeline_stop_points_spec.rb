# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

# End-to-end coverage of the generate: namespace's pipeline stop-point tasks
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

    it "generate:mocks generates mocks but compiles, links, and runs nothing" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("generate:mocks")

          expect(output).to match(/Generating mock for adc\/TestAdcModel::TaskScheduler\.h/)
          expect(output).to_not match(/Generating runner for/)
          expect(output).to_not match(/^Compiling /)
          expect(output).to_not match(/^Linking /)
          expect(output).to_not match(/^Running /)
        end
      end
    end

    it "generate:test_runners generates mocks and runners but compiles, links, and runs nothing" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          output = @c.ceedling_build_exec("generate:test_runners")

          expect(output).to match(/Generating mock for adc\/TestAdcModel::TaskScheduler\.h/)
          expect(output).to match(/Generating runner for TestAdcModel\.c/)
          expect(output).to_not match(/^Compiling /)
          expect(output).to_not match(/^Linking /)
          expect(output).to_not match(/^Running /)
        end
      end
    end

    it "does not interfere with a subsequent test:all run's own dependency cache" do
      @c.with_context do
        Dir.chdir "temp_sensor" do
          @c.ceedling_build_exec("generate:test_runners")

          rebuild = @c.ceedling_build_exec("test:all")
          expect(rebuild).to match(/^Compiling /)
          expect(rebuild).to match(/^Linking /)
          expect(rebuild).to match(/^Running /)
          expect(rebuild).to match(/TESTED:\s+86/)
          expect(rebuild).to match(/PASSED:\s+86/)
        end
      end
    end
  end
end
