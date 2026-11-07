# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Mockable Header Reassembly Through Real Builds
## ==============================================
##
## With :cmock ↳ :treat_inlines: :include, Ceedling reassembles a mocked header from its
## preprocessed copies before CMock reads it. A vendor header such as a CMSIS stub opens with
## a license comment longer than the include guard scan window, includes <stdint.h> through
## the compiler's wrapper header, and defines an empty macro just ahead of its declarations.
## The reassembled header keeps the header's own guard, writes each include once, and leaves
## every declaration on a line of its own for CMock to mock.
##

MOCKABLE_REASSEMBLY_LICENSE =
  "/*\n" +
  (" * Licensed under the Apache License, Version 2.0 (the \"License\"); you may not use\n" * 30) +
  " */\n"

MOCKABLE_REASSEMBLY_STUB = MOCKABLE_REASSEMBLY_LICENSE + <<~C
  #ifndef __CMSIS_GCC_H
  #define __CMSIS_GCC_H

  #include <stdint.h>

  // avoid warnings about deprecated APIs during unit testing
  #ifndef   CMSIS_DEPRECATED
      #define CMSIS_DEPRECATED
  #endif

  void __enable_irq(void);
  void __disable_irq(void);
  uint32_t __get_PRIMASK(void);
  void __DSB(void);

  #endif
C

MOCKABLE_REASSEMBLY_TEST = <<~C
  #include "unity.h"
  #include "mock_cmsis_gcc.h"

  void setUp(void) {}
  void tearDown(void) {}

  void test_enable_irq_is_mocked(void)
  {
    __enable_irq_Expect();
    __enable_irq();
  }

  void test_get_primask_is_mocked(void)
  {
    __get_PRIMASK_ExpectAndReturn(1);
    TEST_ASSERT_EQUAL_UINT32(1, __get_PRIMASK());
  }
C

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "mockable_reassembly"

  before do
    in_project do
      FileUtils.mkdir_p( 'test/stubs' )
      File.write( 'test/stubs/cmsis_gcc.h', MOCKABLE_REASSEMBLY_STUB )
      File.write( 'test/test_sysint.c', MOCKABLE_REASSEMBLY_TEST )

      @c.merge_project_yml_for_test( {
        :project => { :use_mocks => true, :use_test_preprocessor => :all },
        :paths   => { :include => ['src/**', 'test/stubs'] },
        :cmock   => { :treat_inlines => :include }
      } )
    end
  end

  # The reassembled header CMock read, not the preprocessor's own intermediate copies
  def reassembled_header
    found = Dir.glob( 'build/test/preprocess/files/**/cmsis_gcc.h' ).reject do |path|
      path.include?( '/directives_only/' ) or path.include?( '/full_expansion/' )
    end
    expect(found.size).to eq(1), found.inspect

    return File.read( found.first )
  end

  it "mocks every declaration of a vendor header behind a long license and an empty macro" do
    in_project do
      # Longer than the include guard scan window
      expect( MOCKABLE_REASSEMBLY_LICENSE.bytesize ).to be > 2048

      output = @c.ceedling_build_exec( "test:all" )
      expect(@c.last_exit_status).to eq(0), output
      expect(output).to match(/PASSED:\s+2/)

      header = reassembled_header()
      expect(header).to start_with( "#ifndef __CMSIS_GCC_H\n#define __CMSIS_GCC_H\n" )
      expect(header.scan(/^\s*#define __CMSIS_GCC_H\b/).size).to eq(1), header
      expect(header.scan(/^#include <stdint\.h>$/).size).to eq(1), header
      expect(header).to match(/^\s*#define CMSIS_DEPRECATED\s*$/)
      expect(header).to match(/^void __enable_irq\(void\);$/)
    end
  end
end
