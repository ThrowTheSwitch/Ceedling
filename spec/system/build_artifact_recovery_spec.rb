# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Recovery from a damaged build artifact
## ======================================
##
## A build directory can be damaged between runs: an interrupted write, a crash, a
## sync tool, or a person tidying up. Ceedling trusts several artifacts on later runs,
## so damage to one must cost a rebuild of the step that wrote it, never a build that
## fails every time until a clobber.
##
## Each example builds a passing project, damages exactly one artifact, then expects the
## next build to pass with the same counts. The cases come from fault-injection stress
## testing, where each one left every later build failing:
##
##   - a cached test result that is truncated or emptied
##   - a dependency file that names a directory, as a truncated one can
##   - a test's cached build directives, deleted or emptied
##   - a generated mock header that is truncated
##
## The project mocks a header and pulls a source in through TEST_SOURCE_FILE(), so a
## build directive dropped from a damaged cache shows up as a link failure.
##

ARTIFACT_ADDER_H = <<~C
  #ifndef ADDER_H
  #define ADDER_H

  int adder_add(int a, int b);

  #endif // ADDER_H
C

ARTIFACT_ADDER_C = <<~C
  #include "adder.h"
  #include "sensor.h"

  // Defined in helper_impl.c, which only TEST_SOURCE_FILE() brings into the test build
  int helper_offset(void);

  int adder_add(int a, int b)
  {
      return a + b + sensor_bias() + helper_offset();
  }
C

ARTIFACT_SENSOR_H = <<~C
  #ifndef SENSOR_H
  #define SENSOR_H

  int sensor_bias(void);

  #endif // SENSOR_H
C

ARTIFACT_HELPER_IMPL_C = <<~C
  int helper_offset(void)
  {
      return 0;
  }
C

ARTIFACT_TEST_ADDER_C = <<~C
  #include "unity.h"
  #include "adder.h"
  #include "mock_sensor.h"

  TEST_SOURCE_FILE("helper_impl.c")

  void setUp(void) {}
  void tearDown(void) {}

  void test_adds_with_bias(void)
  {
      sensor_bias_ExpectAndReturn(1);
      TEST_ASSERT_EQUAL_INT(6, adder_add(2, 3));
  }

  void test_adds_without_bias(void)
  {
      sensor_bias_ExpectAndReturn(0);
      TEST_ASSERT_EQUAL_INT(5, adder_add(2, 3));
  }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "artifact_recovery"

  describe "Deployed as a gem" do

    before do
      in_project do
        File.write('src/adder.h', ARTIFACT_ADDER_H)
        File.write('src/adder.c', ARTIFACT_ADDER_C)
        File.write('src/sensor.h', ARTIFACT_SENSOR_H)
        File.write('src/helper_impl.c', ARTIFACT_HELPER_IMPL_C)
        File.write('test/test_adder.c', ARTIFACT_TEST_ADDER_C)

        @c.merge_project_yml_for_test({ :project => { :use_mocks => true, :use_test_preprocessor => :all } })
      end
    end

    def expect_green_build
      output = @c.ceedling_build_exec("test:all")

      expect(@c.last_exit_status).to eq(0), output.to_s
      expect(output).to match(/TESTED:\s+2/)
      expect(output).to match(/PASSED:\s+2/)
    end

    # The one artifact matching `pattern`, so a damage step never silently hits nothing
    def only_file(pattern)
      matches = Dir.glob(pattern)
      expect(matches.length).to eq(1), "expected one match for #{pattern}, found #{matches}"
      matches.first
    end

    def damage_then_rebuild
      in_project do
        expect_green_build
        yield
        expect_green_build
      end
    end

    it "reruns a test whose cached result was truncated" do
      damage_then_rebuild do
        result = only_file('build/test/results/**/test_adder.pass')
        File.truncate(result, File.size(result) / 2)
      end
    end

    it "reruns a test whose cached result was emptied" do
      damage_then_rebuild do
        File.truncate(only_file('build/test/results/**/test_adder.pass'), 0)
      end
    end

    it "recompiles an object whose dependency file names a directory" do
      damage_then_rebuild do
        deps   = only_file('build/test/dependencies/**/adder.d')
        target = File.read(deps)[/\A(.*?):(?=\s)/, 1]
        File.write(deps, "#{target}: build/vendor/unity/src/\n")
      end
    end

    it "rebuilds a test's build directives when their cache directory was deleted" do
      damage_then_rebuild do
        FileUtils.rm_rf(Dir.glob('build/test/preprocess/build_directives/*/'))
      end
    end

    # An emptied cache loads as no directives at all, silently dropping helper_impl.c from
    # the object list. Nothing shows until a code change forces a relink, so this changes
    # adder.c's code too. Treating the cache as damaged rebuilds the directives instead.
    it "rebuilds a test's build directives when their cache was emptied" do
      damage_then_rebuild do
        File.truncate(only_file('build/test/preprocess/build_directives/**/*_source_files.yml'), 0)
        File.write('src/adder.c', ARTIFACT_ADDER_C.sub('return a + b', "int sum = a + b;\n    return sum"))
      end
    end

    it "regenerates a mock whose generated header was truncated" do
      damage_then_rebuild do
        header = only_file('build/test/mocks/**/mock_sensor.h')
        File.truncate(header, File.size(header) / 2)
      end
    end

  end
end
