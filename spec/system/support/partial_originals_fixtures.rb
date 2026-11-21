# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

# A project where a header declares a mocked function `static`, so the source of the module
# that calls it, compiled alone, makes GCC say the function is used but never defined. The
# module's port, which defines the function, is included by a macro that a test build sets
# to an empty file. A Partial of the module carries every function, or all but one.
module PartialOriginalsFixtures

  CALC_HEADER = <<~C
    #ifndef CALC_H
    #define CALC_H
    int calc_max(int a, int b);
    #endif
  C

  CALC_SOURCE = <<~C
    #include "calc.h"

    int calc_max(int a, int b)
    {
        if (a > b)
        {
            return a;
        }
        return b;
    }
  C

  INTERFACE_HEADER = <<~C
    #ifndef SENSOR_INTERFACE_H
    #define SENSOR_INTERFACE_H

    // The port, included by the calling source, defines this
    static int sensor_inf_read(void);

    #endif
  C

  MANAGER_HEADER = <<~C
    #ifndef SENSOR_MANAGER_H
    #define SENSOR_MANAGER_H
    int sensor_get(void);
    int sensor_clamped(int limit);
    #endif
  C

  MANAGER_SOURCE = <<~C
    #include "sensor_manager.h"
    #include "sensor_interface.h"

    // The functions of sensor_interface.h are static, so their port has to be in this translation unit.
    #include SENSOR_INCLUDE_PORT

    int sensor_get(void)
    {
        return 2 * sensor_inf_read();
    }

    int sensor_clamped(int limit)
    {
        int value = sensor_get();
        if (value > limit)
        {
            return limit;
        }
        return value;
    }
  C

  REAL_PORT = "static int sensor_inf_read(void) { return 21; }\n"

  CALC_TEST = <<~C
    #include "unity.h"
    #include "calc.h"

    void setUp(void) {}
    void tearDown(void) {}

    void test_calc_max_picks_the_first(void)
    {
        TEST_ASSERT_EQUAL_INT(3, calc_max(3, 2));
    }
  C

  MANAGER_TEST = <<~C
    #include "unity.h"
    #include "ceedling.h"
    #include TEST_PARTIAL_PUBLIC_MODULE(sensor_manager)
    #include MOCK_PARTIAL_PRIVATE_MODULE(sensor_interface)

    void setUp(void) {}
    void tearDown(void) {}

    void test_sensor_get_doubles_the_reading(void)
    {
        sensor_inf_read_ExpectAndReturn(21);
        TEST_ASSERT_EQUAL_INT(42, sensor_get());
    }

    void test_sensor_clamped_limits_a_high_reading(void)
    {
        sensor_inf_read_ExpectAndReturn(30);
        TEST_ASSERT_EQUAL_INT(50, sensor_clamped(50));
    }
  C

  # The same module with a static helper nothing calls, which no Partial carries
  MANAGER_SOURCE_WITH_UNUSED_HELPER = <<~C
    #include "sensor_manager.h"
    #include "sensor_interface.h"

    // The functions of sensor_interface.h are static, so their port has to be in this translation unit.
    #include SENSOR_INCLUDE_PORT

    // Called by nothing, so no Partial carries it
    static int sensor_scale(int value)
    {
        return value * 3;
    }

    int sensor_get(void)
    {
        return 2 * sensor_inf_read();
    }

    int sensor_clamped(int limit)
    {
        int value = sensor_get();
        if (value > limit)
        {
            return limit;
        }
        return value;
    }
  C

  # The same test, whose Partial leaves out one function
  MANAGER_TEST_WITHOUT_CLAMPED = <<~C
    #include "unity.h"
    #include "ceedling.h"
    #include TEST_PARTIAL_PUBLIC_MODULE(sensor_manager)
    #include MOCK_PARTIAL_PRIVATE_MODULE(sensor_interface)
    TEST_PARTIAL_CONFIG(sensor_manager, -sensor_clamped)

    void setUp(void) {}
    void tearDown(void) {}

    void test_sensor_get_doubles_the_reading(void)
    {
        sensor_inf_read_ExpectAndReturn(21);
        TEST_ASSERT_EQUAL_INT(42, sensor_get());
    }
  C

  # Writes the project's sources and tests below the current directory. `left_out` stages
  # the variant whose Partial leaves `sensor_clamped` out.
  def write_partial_originals_project(left_out: false)
    FileUtils.mkdir_p( ['src/ports', 'test/support'] )

    File.write( 'src/calc.h', CALC_HEADER )
    File.write( 'src/calc.c', CALC_SOURCE )
    File.write( 'src/sensor_interface.h', INTERFACE_HEADER )
    File.write( 'src/sensor_manager.h', MANAGER_HEADER )
    File.write( 'src/sensor_manager.c', left_out ? MANAGER_SOURCE_WITH_UNUSED_HELPER : MANAGER_SOURCE )
    File.write( 'src/ports/sensor_port_real.inc', REAL_PORT )
    File.write( 'test/support/sensor_port_mocked.inc', '' )
    File.write( 'test/test_calc.c', CALC_TEST )
    File.write( 'test/test_sensor_manager.c', left_out ? MANAGER_TEST_WITHOUT_CLAMPED : MANAGER_TEST )
  end

  # The project settings every build of it needs
  def partial_originals_project_settings
    return {
      :project => { :use_mocks => true, :use_partials => true, :use_test_preprocessor => :all },
      :defines => { :test => ['SENSOR_INCLUDE_PORT=<sensor_port_mocked.inc>'] }
    }
  end

end
