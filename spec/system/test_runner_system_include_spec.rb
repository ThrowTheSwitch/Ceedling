# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Generated Runner Preserves System #include Directory/Brackets (issue #1236)
## =============================================================================
##
## A test file directly #include-ing a system header with a directory component
## (e.g. `#include <sys/stat.h>`) previously produced a generated runner containing
## `#include "stat.h"` -- the directory component and the system-include `<>`
## delimiters were both lost, since GeneratorTestRunner#generate rendered every
## include (mocks aside) down to its bare basename with no `<>` for system headers.
## The test file itself compiled fine; only the separately generated runner file
## failed, with a "No such file or directory" error on the mangled include.
##

TEST_RUNNER_SYSTEM_INCLUDE_C = <<~C
  #include <sys/stat.h>

  #include "unity.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_runner_preserves_system_include_path(void)
  {
    struct stat value;
    TEST_ASSERT_EQUAL_UINT(sizeof(value), sizeof(struct stat));
  }
C

ceedling_system_tests do

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("runner_sys_inc") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    before do
      @c.with_context do
        Dir.chdir @proj_name do
          File.write('test/test_runner_system_include.c', TEST_RUNNER_SYSTEM_INCLUDE_C)
        end
      end
    end

    it "preserves a system include's directory component and angle brackets in the generated runner" do
      @c.with_context do
        Dir.chdir @proj_name do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)

          # The generated runner is what actually failed to compile in the reported
          # issue -- assert on its content directly rather than just overall build
          # success, since only the runner (not the test file itself) was affected.
          runner_path = Dir.glob('build/test/runners/*_runner.c').first
          expect(runner_path).not_to be_nil

          runner_contents = File.read(runner_path)
          expect(runner_contents).to include('#include <sys/stat.h>')
          expect(runner_contents).not_to include('#include "stat.h"')
        end
      end
    end
  end

end
