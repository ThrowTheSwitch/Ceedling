# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## What a Partial Carries Through Real Builds
## ==========================================
##
## A Partial's implementation source carries what the module's code relies on beyond the
## selected functions. That is prototypes of functions defined elsewhere, prototypes of
## functions the test left out, and the header helpers kept code uses. These builds run
## unoptimized, where an inline function's call needs a real external definition to link
## against. A call to an undeclared function fails on every compiler, GCC before 14 included,
## so a prototype left behind can't pass as a warning.
##

PARTIALS_CARRY_PREAMBLE = "#include \"unity.h\"\n#include \"ceedling.h\"\n"

# An inline function lives in a header that isn't the module's. The module's source declares it
# `extern inline`, which makes that source's object hold the external definition.
PARTIALS_CARRY_API_HEADER = <<~C
  #ifndef ENGINE_API_H
  #define ENGINE_API_H
  int engine_get(void);
  inline int engine_get_twice(void)
  {
      return 2 * engine_get();
  }
  #endif
C

PARTIALS_CARRY_PORT_HEADER = <<~C
  #ifndef PORT_H
  #define PORT_H
  static int port_read(void);
  #endif
C

PARTIALS_CARRY_INLINE_SOURCE = <<~C
  #include "engine_api.h"
  #include "port.h"

  extern inline int engine_get_twice(void);

  int engine_get(void)
  {
      return port_read() + 1;
  }
C

PARTIALS_CARRY_INLINE_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(engine)
  #include MOCK_PARTIAL_PRIVATE_MODULE(port)
  #include "engine_api.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_engine_get_adds_one(void)
  {
      port_read_ExpectAndReturn(41);
      TEST_ASSERT_EQUAL_INT(42, engine_get());
  }

  void test_engine_get_twice_doubles(void)
  {
      port_read_ExpectAndReturn(20);
      TEST_ASSERT_EQUAL_INT(42, engine_get_twice());
  }
C

# A header helper, a prototype defined elsewhere, a subtracted function the test stubs, and an
# extern variable the test defines
PARTIALS_CARRY_HELPER_HEADER = <<~C
  #ifndef BOARD_ENGINE_H
  #define BOARD_ENGINE_H
  extern int board_count;
  int board_tick(void);
  static inline int clamp(int v) { return v > 9 ? 9 : v; }
  int board_engine_get(void);
  int board_engine_poll(void);
  int board_engine_report(void);
  int board_engine_count(void);
  #endif
C

PARTIALS_CARRY_HELPER_SOURCE = <<~C
  #include "board_engine.h"
  int board_engine_get(void) { return clamp(board_tick()); }
  int board_engine_poll(void) { return board_engine_get(); }
  int board_engine_report(void) { return board_engine_poll() + 1; }
  int board_engine_count(void) { return board_count + 1; }
C

PARTIALS_CARRY_HELPER_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(board_engine)
  TEST_PARTIAL_CONFIG(board_engine, -board_engine_poll)

  int board_count = 41;
  int board_tick(void) { return 12; }
  int board_engine_poll(void) { return 7; }

  void setUp(void) {}
  void tearDown(void) {}

  void test_get_clamps_the_tick(void) { TEST_ASSERT_EQUAL_INT(9, board_engine_get()); }
  void test_report_uses_the_stubbed_poll(void) { TEST_ASSERT_EQUAL_INT(8, board_engine_report()); }
  void test_count_reads_the_extern_variable(void) { TEST_ASSERT_EQUAL_INT(42, board_engine_count()); }
C

# A guardless module header that another header pulls in again, helpers and all
PARTIALS_CARRY_ONCE_HEADER = <<~C
  #pragma once
  static inline int clamp(int v) { return v > 9 ? 9 : v; }
  int once_get(int v);
C

PARTIALS_CARRY_ONCE_CONFIG = <<~C
  #ifndef ONCE_CFG_H
  #define ONCE_CFG_H
  #include "once.h"
  #define ONCE_BIAS 0
  #endif
C

PARTIALS_CARRY_ONCE_SOURCE = <<~C
  #include "once.h"
  #include "once_cfg.h"
  int once_get(int v) { return clamp(v) + ONCE_BIAS; }
C

PARTIALS_CARRY_ONCE_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(once)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get(void) { TEST_ASSERT_EQUAL_INT(9, once_get(42)); }
C

# A header-only module whose prototype uses the header's own type, and the module that calls it
PARTIALS_CARRY_GPIO_HEADER = <<~C
  #ifndef GPIO_H
  #define GPIO_H
  #include <stdint.h>
  typedef enum { GPIO_IN, GPIO_OUT } gpio_dir_t;
  void gpio_set(uint32_t pin, gpio_dir_t dir);
  #endif
C

PARTIALS_CARRY_BLINK_SOURCE = <<~C
  #include "blink.h"
  #include "gpio.h"
  int blink_on(void) { gpio_set(13, GPIO_OUT); return 1; }
C

PARTIALS_CARRY_BLINK_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(blink)
  #include MOCK_PARTIAL_PUBLIC_MODULE(gpio)
  void setUp(void) {}
  void tearDown(void) {}
  void test_on_sets_the_pin_out(void)
  {
      gpio_set_Expect(13, GPIO_OUT);
      TEST_ASSERT_EQUAL_INT(1, blink_on());
  }
C

# A dependency named by its directory, whose real inline body fails any test it runs in
PARTIALS_CARRY_HW_PORT_HEADER = <<~C
  #ifndef PORT_H
  #define PORT_H
  static inline int port_read(void) { return -1000; }
  #endif
C

PARTIALS_CARRY_HW_ENGINE_SOURCE = <<~C
  #include "engine.h"
  #include "port.h"
  int engine_get(void) { return port_read() + 1; }
C

PARTIALS_CARRY_HW_ENGINE_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(engine)
  #include MOCK_PARTIAL_PRIVATE_MODULE_AT(hw, port)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get_adds_one(void)
  {
      port_read_ExpectAndReturn(41);
      TEST_ASSERT_EQUAL_INT(42, engine_get());
  }
C

# A module tested and mocked in one test whose source never includes its own header
PARTIALS_CARRY_VALVE_SOURCE = <<~C
  static int valve_base(void) { return -1000; }
  int valve_open(void) { return valve_base() + 1; }
C

PARTIALS_CARRY_VALVE_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(valve)
  #include MOCK_PARTIAL_PRIVATE_MODULE(valve)
  void setUp(void) {}
  void tearDown(void) {}
  void test_open_adds_one(void)
  {
      valve_base_ExpectAndReturn(41);
      TEST_ASSERT_EQUAL_INT(42, valve_open());
  }
C

# A header-only module whose functions its user's port defines, as #1417's project does. The
# helper stays real, and the port's function is mocked.
PARTIALS_CARRY_SENSOR_INTERFACE_HEADER = <<~C
  #ifndef SENSOR_INTERFACE_H
  #define SENSOR_INTERFACE_H
  #define SENSOR_SCALE 2
  typedef struct { int raw; } sensor_reading_t;
  static const int sensor_table[] = { 1, 2 };
  static inline int sensor_twice(int x) { return SENSOR_SCALE * x; }
  static sensor_reading_t sensor_inf_read(void);
  #endif
C

PARTIALS_CARRY_SENSOR_MANAGER_SOURCE = <<~C
  #include "sensor_manager.h"
  #include "sensor_interface.h"
  #include SENSOR_INCLUDE_PORT
  int sensor_get(void)
  {
      sensor_reading_t reading = sensor_inf_read();
      return sensor_twice(reading.raw) * sensor_table[1];
  }
C

PARTIALS_CARRY_SENSOR_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(sensor_manager)
  #include MOCK_PARTIAL_PRIVATE_MODULE(sensor_interface)
  MOCK_PARTIAL_CONFIG(sensor_interface, -sensor_twice)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get_scales_the_reading(void)
  {
      sensor_reading_t reading = { 21 };
      sensor_inf_read_ExpectAndReturn(reading);
      TEST_ASSERT_EQUAL_INT(84, sensor_get());
  }
C

# A mocked module's private helper, which the public mock leaves to its user
PARTIALS_CARRY_PINS_HEADER = <<~C
  #ifndef PINS_H
  #define PINS_H
  #include <stdint.h>
  static inline uint32_t pins_mask(uint32_t pin) { return 1u << pin; }
  void pins_write(uint32_t mask);
  #endif
C

PARTIALS_CARRY_LED_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(led)
  #include MOCK_PARTIAL_PUBLIC_MODULE(pins)
  void setUp(void) {}
  void tearDown(void) {}
  void test_on_writes_the_pin_mask(void)
  {
      pins_write_Expect(8);
      led_on();
  }
C

# A mocked module whose header has no include guard
PARTIALS_CARRY_ONCE_PORT_HEADER = <<~C
  #pragma once
  static inline int oport_twice(int x) { return 2 * x; }
  int oport_read(void);
C

PARTIALS_CARRY_ONCE_PORT_TEST = PARTIALS_CARRY_PREAMBLE + <<~C
  #include TEST_PARTIAL_PUBLIC_MODULE(oengine)
  #include MOCK_PARTIAL_PUBLIC_MODULE(oport)
  void setUp(void) {}
  void tearDown(void) {}
  void test_get_reads_the_port(void) { oport_read_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, oengine_get()); }
C

PARTIALS_CARRY_PORT_TWICE_HEADER = "#ifndef PORT_H\n#define PORT_H\nstatic inline int port_twice(int x) { return 2 * x; }\nint port_read(void);\n#endif\n"
PARTIALS_CARRY_PORT_READ_SOURCE  = "#include \"port.h\"\nint port_read(void) { return 0; }\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partials_carry"

  before do
    in_project do
      @c.merge_project_yml_for_test( {
        :project => { :use_partials => true },
        :flags   => { :test => { :compile => { '*' => ['-Werror=implicit-function-declaration'] } } }
      } )
    end
  end

  def build_passing(tests)
    output = @c.ceedling_build_exec( "test:all" )
    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+#{tests}/)

    return output
  end

  it "links a test calling an inline function the module defines externally" do
    in_project do
      File.write( 'src/engine_api.h', PARTIALS_CARRY_API_HEADER )
      File.write( 'src/port.h', PARTIALS_CARRY_PORT_HEADER )
      File.write( 'src/engine.c', PARTIALS_CARRY_INLINE_SOURCE )
      File.write( 'test/test_engine.c', PARTIALS_CARRY_INLINE_TEST )

      build_passing( 2 )
    end
  end

  it "builds a module whose code relies on a helper, external prototypes and a test stub" do
    in_project do
      File.write( 'src/board_engine.h', PARTIALS_CARRY_HELPER_HEADER )
      File.write( 'src/board_engine.c', PARTIALS_CARRY_HELPER_SOURCE )
      File.write( 'test/test_board_engine.c', PARTIALS_CARRY_HELPER_TEST )

      build_passing( 3 )
    end
  end

  it "writes no weak definition and no pragmas when the project file turns both off" do
    in_project do
      @c.merge_project_yml_for_test( { :partials => { :extern_variables => :test, :suppress_redundant_decls => false } } )
      File.write( 'src/board_engine.h', PARTIALS_CARRY_HELPER_HEADER )
      File.write( 'src/board_engine.c', PARTIALS_CARRY_HELPER_SOURCE )
      File.write( 'test/test_board_engine.c', PARTIALS_CARRY_HELPER_TEST )

      build_passing( 3 )

      impl = File.read( Dir.glob( 'build/test/partials/**/ceedling_partial_board_engine_impl.c' ).first )
      expect( impl ).to include( 'int board_tick(void);' )
      expect( impl ).not_to include( 'int board_count;' )
      expect( impl ).not_to include( '#pragma GCC diagnostic' )
    end
  end

  [false, true].each do |fallback|
    it "mocks a header-only module whose prototype uses its own type#{' under fallback preprocessing' if fallback}" do
      in_project do
        @c.merge_project_yml_for_test( { :test_build => { :preprocess_force_fallback => fallback } } )
        File.write( 'src/gpio.h', PARTIALS_CARRY_GPIO_HEADER )
        File.write( 'src/blink.h', "#ifndef BLINK_H\n#define BLINK_H\nint blink_on(void);\n#endif\n" )
        File.write( 'src/blink.c', PARTIALS_CARRY_BLINK_SOURCE )
        File.write( 'test/test_blink.c', PARTIALS_CARRY_BLINK_TEST )

        build_passing( 1 )
      end
    end
  end

  it "mocks a dependency named by its directory in place of its real header" do
    in_project do
      FileUtils.mkdir_p( 'src/hw' )
      File.write( 'src/hw/port.h', PARTIALS_CARRY_HW_PORT_HEADER )
      File.write( 'src/engine.h', "#ifndef ENGINE_H\n#define ENGINE_H\nint engine_get(void);\n#endif\n" )
      File.write( 'src/engine.c', PARTIALS_CARRY_HW_ENGINE_SOURCE )
      File.write( 'test/test_engine.c', PARTIALS_CARRY_HW_ENGINE_TEST )

      build_passing( 1 )
    end
  end

  it "builds a module tested and mocked in one test whose source never includes its own header" do
    in_project do
      File.write( 'src/valve.h', "#ifndef VALVE_H\n#define VALVE_H\nint valve_open(void);\n#endif\n" )
      File.write( 'src/valve.c', PARTIALS_CARRY_VALVE_SOURCE )
      File.write( 'test/test_valve.c', PARTIALS_CARRY_VALVE_TEST )

      build_passing( 1 )
    end
  end

  # A mock-only Partial's interface stands in for its real header, so the rest of that header
  # comes along. CMock reads only the interface, so it mocks exactly what the test selected.
  it "mocks a header-only module's port function and keeps its helper, table and types" do
    in_project do
      @c.merge_project_yml_for_test( { :defines => { :test => ['SENSOR_INCLUDE_PORT=<sensor_port_mocked.inc>'] } } )
      FileUtils.mkdir_p( 'test/support' )
      File.write( 'test/support/sensor_port_mocked.inc', '' )
      File.write( 'src/sensor_interface.h', PARTIALS_CARRY_SENSOR_INTERFACE_HEADER )
      File.write( 'src/sensor_manager.h', "#ifndef SENSOR_MANAGER_H\n#define SENSOR_MANAGER_H\nint sensor_get(void);\n#endif\n" )
      File.write( 'src/sensor_manager.c', PARTIALS_CARRY_SENSOR_MANAGER_SOURCE )
      File.write( 'test/test_sensor_manager.c', PARTIALS_CARRY_SENSOR_TEST )
      @c.merge_project_yml_for_test( { :paths => { :support => ['test/support'] } } )

      build_passing( 1 )

      mock = File.read( Dir.glob( 'build/test/mocks/**/mock_ceedling_partial_sensor_interface_interface.h' ).first )
      expect( mock ).to include( 'sensor_inf_read_ExpectAndReturn' )
      expect( mock ).not_to include( 'sensor_twice' )
    end
  end

  it "keeps a mocked module's private helper for the module that uses it" do
    in_project do
      File.write( 'src/pins.h', PARTIALS_CARRY_PINS_HEADER )
      File.write( 'src/led.h', "#ifndef LED_H\n#define LED_H\nvoid led_on(void);\n#endif\n" )
      File.write( 'src/led.c', "#include \"led.h\"\n#include \"pins.h\"\nvoid led_on(void) { pins_write(pins_mask(3)); }\n" )
      File.write( 'test/test_led.c', PARTIALS_CARRY_LED_TEST )

      build_passing( 1 )
    end
  end

  it "leaves a mocked unguarded header's helpers behind with a notice, and still builds" do
    in_project do
      File.write( 'src/oport.h', PARTIALS_CARRY_ONCE_PORT_HEADER )
      File.write( 'src/oengine.h', "#ifndef OENGINE_H\n#define OENGINE_H\nint oengine_get(void);\n#endif\n" )
      File.write( 'src/oengine.c', "#include \"oengine.h\"\n#include \"oport.h\"\nint oengine_get(void) { return oport_read() + 1; }\n" )
      File.write( 'test/test_oengine.c', PARTIALS_CARRY_ONCE_PORT_TEST )

      output = build_passing( 1 )
      expect( output ).to include( 'Its mock leaves helper `oport_twice()` from src/oport.h behind.' )
    end
  end

  # The extras stand in for the rest of the real header in every file of the test that
  # includes a mock-only Partial's interface. These are the shapes where they must step aside.
  describe "a mocked header's extras" do
    def port_project(port_h:, port_c:, engine_c:, test:, extra: {})
      File.write( 'src/port.h', port_h )
      File.write( 'src/port.c', port_c )
      File.write( 'src/engine.h', "#ifndef ENGINE_H\n#define ENGINE_H\nint engine_get(void);\n#endif\n" )
      File.write( 'src/engine.c', engine_c )
      extra.each { |path, text| File.write( path, text ) }
      File.write( 'test/test_engine.c', PARTIALS_CARRY_PREAMBLE + test + "void setUp(void) {}\nvoid tearDown(void) {}\n" )
    end

    it "steps aside where another header brought in the real one first" do
      in_project do
        port_project(
          port_h: PARTIALS_CARRY_PORT_TWICE_HEADER, port_c: PARTIALS_CARRY_PORT_READ_SOURCE,
          extra: { 'src/board.h' => "#ifndef BOARD_H\n#define BOARD_H\n#include \"port.h\"\n#define BOARD_ID 1\n#endif\n" },
          engine_c: "#include \"engine.h\"\n#include \"board.h\"\n#include \"port.h\"\nint engine_get(void) { return port_twice(port_read()) + BOARD_ID; }\n",
          test: "#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include MOCK_PARTIAL_PUBLIC_MODULE(port)\n" \
                "void test_get(void) { port_read_ExpectAndReturn(20); TEST_ASSERT_EQUAL_INT(41, engine_get()); }\n"
        )

        build_passing( 1 )
      end
    end

    it "steps aside where the test file includes the real header first" do
      in_project do
        port_project(
          port_h: PARTIALS_CARRY_PORT_TWICE_HEADER, port_c: PARTIALS_CARRY_PORT_READ_SOURCE,
          engine_c: "#include \"engine.h\"\n#include \"port.h\"\nint engine_get(void) { return port_read() + 1; }\n",
          test: "#include \"port.h\"\n#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include MOCK_PARTIAL_PUBLIC_MODULE(port)\n" \
                "void test_get(void) { port_read_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, engine_get()); }\n"
        )

        build_passing( 1 )
      end
    end

    it "keeps neither copy of a static fallback preprocessing found twice" do
      in_project do
        @c.merge_project_yml_for_test( { :test_build => { :preprocess_force_fallback => true } } )
        port_project(
          port_h: "#ifndef PORT_H\n#define PORT_H\n#include \"rev.h\"\n#if PORT_REV > 2\nstatic const int port_gain = 1;\n#endif\n" \
                  "#if PORT_REV <= 2\nstatic const int port_gain = 2;\n#endif\nint port_read(void);\n#endif\n",
          port_c: PARTIALS_CARRY_PORT_READ_SOURCE, extra: { 'src/rev.h' => "#ifndef REV_H\n#define REV_H\n#define PORT_REV 3\n#endif\n" },
          engine_c: "#include \"engine.h\"\n#include \"port.h\"\nint engine_get(void) { return port_read() + 1; }\n",
          test: "#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include MOCK_PARTIAL_PUBLIC_MODULE(port)\n" \
                "void test_get(void) { port_read_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, engine_get()); }\n"
        )

        build_passing( 1 )
      end
    end

    it "leaves behind a table naming a function the mock leaves undefined" do
      in_project do
        port_project(
          port_h: "#ifndef PORT_H\n#define PORT_H\ntypedef int (*port_fn_t)(void);\nint port_a(void);\n" \
                  "static inline int port_raw(void) { return 0; }\nstatic const port_fn_t port_handlers[] = { port_a };\n#endif\n",
          port_c: "#include \"port.h\"\nint port_a(void) { return 5; }\n",
          engine_c: "#include \"engine.h\"\n#include \"port.h\"\nint engine_get(void) { return port_raw() + 1; }\n",
          test: "#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include MOCK_PARTIAL_PRIVATE_MODULE(port)\n" \
                "void test_get(void) { port_raw_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, engine_get()); }\n"
        )

        build_passing( 1 )
      end
    end

    it "declares an extern the way the header does, not the way the source sizes it" do
      in_project do
        port_project(
          port_h: "#ifndef PORT_H\n#define PORT_H\nextern int port_buf[];\nint port_read(void);\n#endif\n",
          port_c: "#include \"port.h\"\n#define PORT_BUF_LEN 4\nint port_buf[PORT_BUF_LEN];\nint port_read(void) { return port_buf[0]; }\n",
          engine_c: "#include \"engine.h\"\n#include \"port.h\"\nint engine_get(void) { return port_read() + 1; }\n",
          test: "#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include MOCK_PARTIAL_ALL_MODULE(port)\n" \
                "void test_get(void) { port_read_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, engine_get()); }\n"
        )

        build_passing( 1 )
      end
    end

    it "leaves behind a prototype a function-like macro of its name rewrites" do
      in_project do
        port_project(
          port_h: "#ifndef PORT_H\n#define PORT_H\nvoid *port_alloc(unsigned n);\n#define port_alloc(n) port_alloc_dbg((n), __LINE__)\n" \
                  "void *port_alloc_dbg(unsigned n, int line);\nstatic inline int port_raw(void) { return 0; }\n#endif\n",
          port_c: "#include \"port.h\"\n#undef port_alloc\nvoid *port_alloc(unsigned n) { (void)n; return 0; }\n" \
                  "void *port_alloc_dbg(unsigned n, int line) { (void)n; (void)line; return 0; }\n",
          engine_c: "#include \"engine.h\"\n#include \"port.h\"\nint engine_get(void) { return port_raw() + 1; }\n",
          test: "#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include MOCK_PARTIAL_PRIVATE_MODULE(port)\n" \
                "void test_get(void) { port_raw_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, engine_get()); }\n"
        )

        build_passing( 1 )
      end
    end

    # A module tested and mocked in one test keeps its header's content in its own implementation
    it "explains what another Partial goes without from a module the test both tests and mocks" do
      in_project do
        port_project(
          port_h: "#ifndef PORT_H\n#define PORT_H\nstatic inline int port_twice(int x) { return 2 * x; }\nstatic const int port_k = 1;\n" \
                  "int port_read(void);\nint port_scaled(void);\n#endif\n",
          port_c: "#include \"port.h\"\nint port_read(void) { return 0; }\nint port_scaled(void) { return port_twice(port_read()); }\n",
          engine_c: "#include \"engine.h\"\n#include \"port.h\"\nint engine_get(void) { return port_twice(port_read()) + port_k; }\n",
          test: "#include TEST_PARTIAL_PUBLIC_MODULE(engine)\n#include TEST_PARTIAL_MODULE(port)\nTEST_PARTIAL_CONFIG(port, port_scaled)\n" \
                "#include MOCK_PARTIAL_MODULE(port)\nMOCK_PARTIAL_CONFIG(port, port_read)\n" \
                "void test_get(void) { port_read_ExpectAndReturn(20); TEST_ASSERT_EQUAL_INT(41, engine_get()); }\n"
        )

        output = @c.ceedling_build_exec( "test:all" )
        expect( output ).to include(
          "Other Partials in this test include src/port.h's mock, which leaves helper `port_twice()`, variable `port_k` and prototype `port_scaled()` out."
        )
      end
    end
  end

  it "leaves an unguarded header's helpers behind with a notice, and still builds" do
    in_project do
      File.write( 'src/once.h', PARTIALS_CARRY_ONCE_HEADER )
      File.write( 'src/once_cfg.h', PARTIALS_CARRY_ONCE_CONFIG )
      File.write( 'src/once.c', PARTIALS_CARRY_ONCE_SOURCE )
      File.write( 'test/test_once.c', PARTIALS_CARRY_ONCE_TEST )

      output = build_passing( 1 )
      expect(output).to include( 'Not carrying helper `clamp()` from src/once.h.' )
    end
  end
end
