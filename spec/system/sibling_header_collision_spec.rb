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

  before :all do
    @c = SystemContext.new
    @c.deploy_gem
  end

  after :all do
    @c.done!
  end

  before { @proj_name = unique_proj_name("sibling_collision") }

  describe "Deployed as a gem" do
    before do
      @c.with_context do
        @c.ceedling_appcmd_exec("new #{@proj_name}")
      end
    end

    # =========================================================================
    describe "a mocked header sharing a directory with a reachable, unmocked sibling" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
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
      end

      it "silently isolates the sibling and passes, instead of running the real, crashing header content" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")

            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)

            expect(output).to match(/Isolated '.*driverlib\.h'.*shares a directory with '.*gpio\.h'/)
          end
        end
      end
    end

    # =========================================================================
    describe "a mocked header reached only through a deeper, multi-hop #include chain" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
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
      end

      it "still isolates the sibling and passes, regardless of how many hops away it's reached" do
        @c.with_context do
          Dir.chdir @proj_name do
            output = @c.ceedling_build_exec("test:all")

            expect(@c.last_exit_status).to eq(0)
            expect(output).to match(/TESTED:\s+1/)
            expect(output).to match(/PASSED:\s+1/)
            expect(output).to match(/FAILED:\s+0/)

            expect(output).to match(/Isolated '.*driverlib\.h'.*shares a directory with '.*gpio\.h'/)
          end
        end
      end
    end

    # =========================================================================
    describe "a mocked header with no reachable sibling at all" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
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
      end

      it "passes silently, with no isolation logging at all -- nothing was ever at risk" do
        @c.with_context do
          Dir.chdir @proj_name do
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
    end

    # =========================================================================
    describe "a genuine collision alongside an unrelated pair of headers sharing a directory" do
    # =========================================================================

      before do
        @c.with_context do
          Dir.chdir @proj_name do
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
      end

      it "still resolves the genuine collision, but only reports -- never isolates -- the unrelated pair" do
        @c.with_context do
          Dir.chdir @proj_name do
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
    end

    # =========================================================================
    describe "a Partial's own generated content colliding with its module's real header" do
    # =========================================================================

      # A Partial generates distinctly-named content rather than a same-basename
      # replacement -- isolation has no alternative for a search path to fall
      # through to here, so this collision structurally survives every attempt,
      # and reactive guidance is the deliberate fallback.
      before do
        @c.with_context do
          Dir.chdir @proj_name do
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
      end

      it "fails to compile, with the raw redeclaration/conflicting-types error explained alongside it" do
        @c.with_context do
          Dir.chdir @proj_name do
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
    end

  end

end
