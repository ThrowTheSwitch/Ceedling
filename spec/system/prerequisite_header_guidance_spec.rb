# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Guidance for a Mocked Header That Requires a Prerequisite Header
## ================================================================
##
## FreeRTOS guards nearly every public header, such as task.h, against inclusion before
## FreeRTOS.h. With :use_test_preprocessor set to :mocks, Ceedling preprocesses the header to
## be mocked by itself, so the guard fires and the build stops. Including FreeRTOS.h in the
## test file doesn't help, since neither the header's preprocessing nor the generated mock's
## compilation sees the test file's #include directives.
##
## Two settings together resolve it. A preprocessor flag, `-include FreeRTOS.h`, lets the
## header's preprocessing see the prerequisite first. :cmock ↳ :includes_h_pre_orig_header
## lets the generated mock include it before the header. The build step doctor explains each
## failure and names the settings that fix it.
##

PREREQUISITE_RTOS_HEADER = <<~C
  #ifndef INC_FREERTOS_H
  #define INC_FREERTOS_H

  #define configTICK_RATE_HZ 1000

  #endif
C

PREREQUISITE_TASK_HEADER = <<~C
  /* task.h */
  #ifndef INC_TASK_H
  #define INC_TASK_H

  #ifndef INC_FREERTOS_H
      #error "include FreeRTOS.h must appear in source files before include task.h"
  #endif

  void vTaskDelay(unsigned int ticks);

  #endif
C

PREREQUISITE_TASK_TEST = <<~C
  #include "unity.h"
  #include "FreeRTOS.h"
  #include "mock_task.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_delay_is_mocked(void)
  {
    vTaskDelay_Expect(10);
    vTaskDelay(10);
  }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "prerequisite_header"

  before do
    in_project do
      FileUtils.mkdir_p( 'rtos/include' )
      File.write( 'rtos/include/FreeRTOS.h', PREREQUISITE_RTOS_HEADER )
      File.write( 'rtos/include/task.h', PREREQUISITE_TASK_HEADER )
      File.write( 'test/test_task.c', PREREQUISITE_TASK_TEST )

      @c.remove_project_yml_option_for_test( :paths, :include )
      @c.merge_project_yml_for_test( {
        :project => { :use_mocks => true, :use_test_preprocessor => :mocks },
        :paths   => { :include => ['rtos/include'] }
      } )
    end
  end

  def build
    return @c.ceedling_build_exec( "test:all" )
  end

  it "explains the guard that stops a mocked header's preprocessing and names both settings" do
    in_project do
      output = build()

      expect(@c.last_exit_status).not_to eq(0), output
      expect(output).to include( "an #error directive in 'rtos/include/task.h'" )
      expect(output).to include( "so the header's preprocessing sees 'FreeRTOS.h' first." )
      expect(output).to match( /Add 'FreeRTOS\.h' to :cmock\s*\S*\s*:includes_h_pre_orig_header, so the generated mock includes it before the header\./ )
    end
  end

  it "explains the guard that stops a generated mock's compilation and names the :cmock setting" do
    in_project do
      @c.merge_project_yml_for_test( { :flags => { :test => { :preprocess => ['-include FreeRTOS.h'] } } } )

      output = build()

      expect(@c.last_exit_status).not_to eq(0), output
      expect(output).to include( "while compiling the generated mock 'mock_task.c'" )
      expect(output).to match( /Add 'FreeRTOS\.h' to :cmock\s*\S*\s*:includes_h_pre_orig_header, so the generated mock includes it before the header\./ )
    end
  end

  it "builds a mocked header that requires a prerequisite header once both settings are given" do
    in_project do
      @c.merge_project_yml_for_test( {
        :flags => { :test => { :preprocess => ['-include FreeRTOS.h'] } },
        :cmock => { :includes_h_pre_orig_header => ['FreeRTOS.h'] }
      } )

      output = build()

      expect(@c.last_exit_status).to eq(0), output
      expect(output).to match(/PASSED:\s+1/)
      expect(output).not_to include( 'appears to report an #error directive' )
    end
  end
end
