# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Sibling-Header Isolation and Reactive Collision Guidance (issues #1240, #1247)
## =================================================================================
##
## A mock or Partial substitutes a header only by way of search-path order, but C's
## own quote-include rule checks a file's own directory before ever consulting a
## search path -- an unrelated, unmocked header sharing a directory with the real
## header a mock/Partial substitutes can reach it directly, silently bypassing the
## substitution with no error at all. TestBuildExecutor#isolate_sibling_headers
## closes this by staging any such sibling, alone, into an isolated directory right
## after a test file's own compile, forcing its own #include of the real header
## through search paths instead.
##
## A Partial's own generated content, unlike a CMock mock, never produces a
## same-basename replacement for a search path to fall through to -- isolation
## structurally cannot resolve a collision there. GeneratorHelper's reactive
## guidance is the deliberate fallback: a compile failure surviving every
## isolation attempt gets a plain-language explanation logged alongside the raw
## redeclaration/conflicting-types error.
##
## Every fixture below shares one real, crash-on-purpose implementation
## (library/gpio.h's own gpio_read dereferences a null pointer) so a scenario's
## outcome is a genuine signal, not just "the build didn't error": if the real,
## unmocked header's content ever actually reaches a test's own translation unit
## in place of the mock, the test crashes instead of passing.
##

GPIO_HEADER_CRASH_ON_REAL_USE = <<~C
  #ifndef GPIO_H
  #define GPIO_H

  #include <stdint.h>

  static inline int gpio_read(int pin) {
      volatile int *gpio = 0;
      *gpio = pin; // crash on purpose if the real (unmocked) implementation ever runs
      return 0;
  }

  #endif // GPIO_H
C

DRIVERLIB_HEADER_C = <<~C
  #ifndef DRIVERLIB_H
  #define DRIVERLIB_H

  // Agglomerates real driver library includes -- exactly the shape that lets an
  // unrelated header sharing gpio.h's own directory reach its real content.
  #include "gpio.h"

  #endif // DRIVERLIB_H
C

BOARD_HEADER_VIA_DRIVERLIB_C = <<~C
  #ifndef BOARD_H
  #define BOARD_H

  #include "driverlib.h"

  #define MY_PIN 9

  #endif // BOARD_H
C

MODULE_A_HEADER_C = <<~C
  #ifndef MODULEA_H
  #define MODULEA_H

  int moduleA_function(void);

  #endif // MODULEA_H
C

MODULE_A_SOURCE_VIA_BOARD_C = <<~C
  #include "moduleA.h"

  #include "board.h"
  #include "gpio.h"

  int moduleA_function(void)
  {
      return gpio_read(MY_PIN);
  }
C

TEST_MODULE_A_MOCKS_GPIO_AND_BOARD_C = <<~C
  #ifdef TEST

  #include "unity.h"
  #include "moduleA.h"
  #include "mock_gpio.h"
  #include "mock_board.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_moduleA(void)
  {
      gpio_read_ExpectAndReturn(MY_PIN, 0);
      moduleA_function();
  }

  #endif // TEST
C

READER_HEADER_C = <<~C
  #ifndef READER_H
  #define READER_H

  int reader_read(int pin);

  #endif // READER_H
C

# Sits beside gpio.h, so its own #include finds the real header before any search path.
READER_SOURCE_BESIDE_GPIO_C = <<~C
  #include "reader.h"
  #include "gpio.h"

  int reader_read(int pin)
  {
      return gpio_read(pin);
  }
C

TEST_READER_MOCKS_GPIO_C = <<~C
  #ifdef TEST

  #include "unity.h"
  #include "reader.h"
  #include "mock_gpio.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_reader_reads_through_the_mock(void)
  {
      gpio_read_ExpectAndReturn(4, 1);
      TEST_ASSERT_EQUAL_INT(1, reader_read(4));
  }

  #endif // TEST
C

# The CMock/Ceedling "shadow header" mechanism (:cmock ↳ :treat_inlines: :include)
# that makes isolation's fix effective relies on generating a same-basename,
# same-guard replacement for a header with inline functions -- gpio.h's own
# gpio_read needs that to be mockable at all.
#
# A method, not a shared constant, and a fresh hash on every call: several scenarios
# below deep_merge their own extra settings onto this, and a shared, reused literal
# risks one scenario's merge mutating nested structures (e.g. the :include array)
# that a later scenario's own call still expects untouched.
def sibling_collision_settings
  {
    :project => { :use_mocks => true },
    :paths   => { :include => ['src/**', 'library/**', 'syscfg/**'] },
    :cmock   => { :treat_inlines => :include }
  }
end

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "sibling_collision"

  describe "Deployed as a gem" do

    # =========================================================================
    describe "a mocked header sharing a directory with a reachable, unmocked sibling" do
    # =========================================================================

      before do
        in_project do
          FileUtils.mkdir_p('library')
          FileUtils.mkdir_p('syscfg')
          File.write('library/gpio.h', GPIO_HEADER_CRASH_ON_REAL_USE)
          File.write('library/driverlib.h', DRIVERLIB_HEADER_C)
          File.write('syscfg/board.h', BOARD_HEADER_VIA_DRIVERLIB_C)
          File.write('src/moduleA.h', MODULE_A_HEADER_C)
          File.write('src/moduleA.c', MODULE_A_SOURCE_VIA_BOARD_C)
          File.write('test/test_moduleA.c', TEST_MODULE_A_MOCKS_GPIO_AND_BOARD_C)

          @c.merge_project_yml_for_test(sibling_collision_settings)
        end
      end

      it "silently isolates the sibling and passes, instead of running the real, crashing header content" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)

          expect(output).to match(/Isolated '.*driverlib\.h'.*shares a directory with '.*gpio\.h'/)
        end
      end
    end

    # =========================================================================
    describe "a source under test sharing a directory with the header its test mocks" do
    # =========================================================================

      # The source itself, not a sibling header, quote-includes the real header beside it.
      # Only compiling it from an isolated copy lets that #include reach the mock's shadow.
      before do
        in_project do
          # The shared settings name these include roots, which must exist
          FileUtils.mkdir_p('library')
          FileUtils.mkdir_p('syscfg')
          File.write('src/gpio.h', GPIO_HEADER_CRASH_ON_REAL_USE)
          File.write('src/reader.h', READER_HEADER_C)
          File.write('src/reader.c', READER_SOURCE_BESIDE_GPIO_C)
          File.write('test/test_reader.c', TEST_READER_MOCKS_GPIO_C)

          @c.merge_project_yml_for_test(sibling_collision_settings)
        end
      end

      it "compiles the source from an isolated copy and passes, instead of running the real inline" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/Compiling an isolated copy of '.*reader\.c'.*mocked header '.*gpio\.h'/)
        end
      end

      # The copy is gone after the build, so a dependency record still naming it would
      # make the object stale on every run. A clean second build compiles nothing again.
      it "leaves the object fresh for the next build" do
        in_project do
          @c.ceedling_build_exec("test:all")
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to_not match(/Compiling an isolated copy/)
        end
      end
    end

    # =========================================================================
    describe "a mocked header reached only through a deeper, multi-hop #include chain" do
    # =========================================================================

      before do
        in_project do
          FileUtils.mkdir_p('library')
          FileUtils.mkdir_p('syscfg')
          File.write('library/gpio.h', GPIO_HEADER_CRASH_ON_REAL_USE)
          File.write('library/driverlib.h', DRIVERLIB_HEADER_C)

          # Several plain wrapper hops between the module under test and the
          # sibling collision -- isolation still only needs a directory match at
          # the actual point of collision, so chain depth on the way there
          # shouldn't matter.
          File.write('syscfg/wrapper_a.h', <<~C)
            #ifndef WRAPPER_A_H
            #define WRAPPER_A_H
            #include "wrapper_b.h"
            #endif // WRAPPER_A_H
          C
          File.write('syscfg/wrapper_b.h', <<~C)
            #ifndef WRAPPER_B_H
            #define WRAPPER_B_H
            #include "wrapper_c.h"
            #endif // WRAPPER_B_H
          C
          File.write('syscfg/wrapper_c.h', <<~C)
            #ifndef WRAPPER_C_H
            #define WRAPPER_C_H
            #include "driverlib.h"
            #endif // WRAPPER_C_H
          C
          File.write('syscfg/board.h', <<~C)
            #ifndef BOARD_H
            #define BOARD_H
            #include "wrapper_a.h"
            #define MY_PIN 9
            #endif // BOARD_H
          C

          File.write('src/moduleA.h', MODULE_A_HEADER_C)
          File.write('src/moduleA.c', MODULE_A_SOURCE_VIA_BOARD_C)
          File.write('test/test_moduleA.c', TEST_MODULE_A_MOCKS_GPIO_AND_BOARD_C)

          @c.merge_project_yml_for_test(sibling_collision_settings)
        end
      end

      it "still isolates the sibling and passes, regardless of how many hops away it's reached" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)

          expect(output).to match(/Isolated '.*driverlib\.h'.*shares a directory with '.*gpio\.h'/)
        end
      end
    end

    # =========================================================================
    describe "a mocked header with no reachable sibling at all" do
    # =========================================================================

      before do
        in_project do
          FileUtils.mkdir_p('library')
          FileUtils.mkdir_p('syscfg')
          File.write('library/gpio.h', GPIO_HEADER_CRASH_ON_REAL_USE)
          # No driverlib.h at all in this scenario -- board.h defines MY_PIN
          # directly rather than agglomerating another real header, so nothing
          # ever shares gpio.h's own directory in this test's dependency closure.
          File.write('syscfg/board.h', <<~C)
            #ifndef BOARD_H
            #define BOARD_H
            #define MY_PIN 9
            #endif // BOARD_H
          C
          File.write('src/moduleA.h', MODULE_A_HEADER_C)
          File.write('src/moduleA.c', MODULE_A_SOURCE_VIA_BOARD_C)
          File.write('test/test_moduleA.c', TEST_MODULE_A_MOCKS_GPIO_AND_BOARD_C)

          @c.merge_project_yml_for_test(sibling_collision_settings)
        end
      end

      it "passes silently, with no isolation logging at all -- nothing was ever at risk" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)

          expect(output).to_not match(/Isolated '/)
          expect(output).to_not match(/NOTICE:.*nesting depth/)
        end
      end
    end

    # =========================================================================
    describe "a genuine collision alongside an unrelated pair of headers sharing a directory" do
    # =========================================================================

      before do
        in_project do
          FileUtils.mkdir_p('library')
          FileUtils.mkdir_p('library2')
          FileUtils.mkdir_p('syscfg')
          File.write('library/gpio.h', GPIO_HEADER_CRASH_ON_REAL_USE)
          File.write('library/driverlib.h', DRIVERLIB_HEADER_C)

          # Neither of these is mocked or Partialized -- nothing designates which of
          # the two should win, so isolation has nothing safe to act on here, unlike
          # the genuine gpio.h/driverlib.h collision this same build still resolves.
          File.write('library2/extra_a.h', <<~C)
            #ifndef EXTRA_A_H
            #define EXTRA_A_H
            #endif // EXTRA_A_H
          C
          File.write('library2/extra_b.h', <<~C)
            #ifndef EXTRA_B_H
            #define EXTRA_B_H
            #endif // EXTRA_B_H
          C
          File.write('syscfg/board.h', <<~C)
            #ifndef BOARD_H
            #define BOARD_H
            #include "driverlib.h"
            #include "extra_a.h"
            #include "extra_b.h"
            #define MY_PIN 9
            #endif // BOARD_H
          C

          File.write('src/moduleA.h', MODULE_A_HEADER_C)
          File.write('src/moduleA.c', MODULE_A_SOURCE_VIA_BOARD_C)
          File.write('test/test_moduleA.c', TEST_MODULE_A_MOCKS_GPIO_AND_BOARD_C)

          settings = sibling_collision_settings.deep_merge(
            :paths => { :include => ['src/**', 'library/**', 'library2/**', 'syscfg/**'] }
          )
          @c.merge_project_yml_for_test(settings)
        end
      end

      it "still resolves the genuine collision, but only reports -- never isolates -- the unrelated pair" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)

          expect(output).to match(/Isolated '.*driverlib\.h'.*shares a directory with '.*gpio\.h'/)

          expect(output).to match(/NOTICE:.*extra_a\.h.*extra_b\.h.*nesting depth/).or(
            match(/NOTICE:.*extra_b\.h.*extra_a\.h.*nesting depth/)
          )
          expect(output).to_not match(/Isolated '.*extra_[ab]\.h'/)
        end
      end
    end

    # =========================================================================
    describe "a Partial's own generated content colliding with its module's real header" do
    # =========================================================================

      # A Partial generates distinctly-named content rather than a same-basename
      # replacement -- isolation has no alternative for a search path to fall
      # through to here, so this collision structurally survives every attempt,
      # and reactive guidance is the deliberate fallback.
      before do
        in_project do
          FileUtils.mkdir_p('library')
          FileUtils.mkdir_p('syscfg')
          File.write('library/gpio.h', <<~C)
            #ifndef GPIO_H
            #define GPIO_H

            #include <stdint.h>

            typedef enum
            {
                GPIO_DIR_MODE_IN,
                GPIO_DIR_MODE_OUT
            } GPIO_Direction;

            void gpio_set_direction(uint32_t pin, GPIO_Direction direction);

            static inline int gpio_read(uint32_t pin)
            {
                volatile int *gpio = 0;
                *gpio = (int)pin; // crash on purpose if the real (unmocked) implementation ever runs
                return 0;
            }

            #endif // GPIO_H
          C
          File.write('library/driverlib.h', DRIVERLIB_HEADER_C)
          File.write('syscfg/board.h', BOARD_HEADER_VIA_DRIVERLIB_C)
          File.write('src/moduleA.h', <<~C)
            #ifndef MODULEA_H
            #define MODULEA_H
            int moduleA_function(void);
            #endif // MODULEA_H
          C
          File.write('src/moduleA.c', <<~C)
            #include "moduleA.h"

            #include "gpio.h"
            #include "board.h"

            int moduleA_function(void)
            {
                gpio_set_direction(MY_PIN, GPIO_DIR_MODE_IN);
                return gpio_read(MY_PIN);
            }
          C
          File.write('test/test_moduleA.c', <<~C)
            #ifdef TEST

            #include "unity.h"
            #include "ceedling.h"

            #include TEST_PARTIAL_ALL_MODULE(moduleA)
            #include MOCK_PARTIAL_ALL_MODULE(gpio)
            #include "board.h"

            void setUp(void) {}
            void tearDown(void) {}

            void test_moduleA(void)
            {
                gpio_set_direction_Expect(MY_PIN, GPIO_DIR_MODE_IN);
                gpio_read_ExpectAndReturn(MY_PIN, 0);
                moduleA_function();
            }

            #endif // TEST
          C

          settings = sibling_collision_settings.deep_merge( :project => { :use_partials => true } )
          @c.merge_project_yml_for_test(settings)
        end
      end

      it "fails to compile, with the raw redeclaration/conflicting-types error explained alongside it" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to_not eq(0)
          # The compiler's own wording varies (clang: "redefinition of"/"previous
          # definition is here"; gcc: "conflicting types for"/"previous definition
          # of") -- either is the real, raw error this guidance explains, not a
          # bare, unexplained failure.
          expect(output).to match(/redeclaration of|redefinition of|conflicting types|previous definition/)
          expect(output).to match(/mocked or Partialized for this test/)
          expect(output).to match(/transitive #include chain/)
        end
      end
    end

    # =========================================================================
    describe "a Partial's extracted types depending on another header (issue #1319)" do
    # =========================================================================

      # A module's own header declares a type in terms of one another header supplies. Partials
      # lifts that type into a shared types header, which lands in the test's include list where
      # the module's own header used to sit -- ahead of nothing that supplies the name it needs.
      # The generated file therefore has to carry the dependency itself.
      before do
        in_project do
          File.write('src/units.h', <<~C)
            #ifndef UNITS_H
            #define UNITS_H

            typedef signed short Celsius;

            #endif // UNITS_H
          C
          File.write('src/sensor.h', <<~C)
            #ifndef SENSOR_H
            #define SENSOR_H

            #include "units.h"

            typedef struct
            {
                Celsius limit;
            } SensorConfig;

            int sensor_over_limit(Celsius reading);

            #endif // SENSOR_H
          C
          File.write('src/sensor.c', <<~C)
            #include "sensor.h"

            static SensorConfig config = { .limit = 30 };

            static Celsius sensor_limit(void)
            {
                return config.limit;
            }

            int sensor_over_limit(Celsius reading)
            {
                return reading > sensor_limit();
            }
          C
          File.write('test/test_sensor.c', <<~C)
            #ifdef TEST

            #include "unity.h"
            #include "ceedling.h"

            #include TEST_PARTIAL_ALL_MODULE(sensor)

            void setUp(void) {}
            void tearDown(void) {}

            void test_sensor_reads_its_own_file_scope_config(void)
            {
                TEST_ASSERT_EQUAL_INT(30, sensor_limit());
            }

            void test_sensor_over_limit_uses_the_exposed_limit(void)
            {
                config.limit = 10;
                TEST_ASSERT_TRUE(sensor_over_limit(11));
                TEST_ASSERT_FALSE(sensor_over_limit(9));
            }

            #endif // TEST
          C

          @c.merge_project_yml_for_test(
            :project => { :use_partials => true },
            :paths   => { :include => ['src/**'] }
          )
        end
      end

      # Exercises the whole chain at once: the carried dependency makes the types header
      # compile, the stripped `static` on a file-scope variable makes it reachable from the
      # test, and the stripped `static` on a function makes it callable.
      it "builds and passes, reaching the module's exposed statics" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0), "build failed:\n#{output}"
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end

  end

end
