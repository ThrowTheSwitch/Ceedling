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

  # A pathless #include and one naming a folder reach two headers of one name. The header
  # prepared for CMock keeps both, in either order.
  [:mocks, :all].product( [%w[config.h app/config.h], %w[app/config.h config.h]] ).each do |preprocessor, order|
    it "keeps both same-named #includes of a mocked header, #{order.join(' then ')}, under :use_test_preprocessor #{preprocessor}" do
      in_project do
        FileUtils.mkdir_p( ['src/hw', 'lib/app'] )
        File.write( 'src/hw/config.h', "#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\ntypedef int hw_t;\n#endif\n" )
        File.write( 'lib/app/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\ntypedef int app_t;\n#endif\n" )
        File.write( 'lib/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n" + order.map { |text| "#include \"#{text}\"\n" }.join +
                                   "static inline int motor_peek(void) { return 0; }\nhw_t motor_run(app_t a);\n#endif\n" )
        File.write( 'test/test_motor.c', "#include \"unity.h\"\n#include \"mock_motor.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n" \
                                         "void test_run(void) { motor_run_ExpectAndReturn(1, 9); TEST_ASSERT_EQUAL_INT(9, motor_run(1)); }\n" )
        @c.remove_project_yml_option_for_test( :paths, :include )
        @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => preprocessor }, :paths => { :include => ['src/hw/', 'lib/', 'test/stubs'] } } )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+3/)
      end
    end
  end

  # An #include names a header beside its includer, which an earlier search path shadows with a
  # header of the same name. No search path reaches the one beside it, so the copy writes it by
  # its absolute path.
  [:mocks, :all].each do |preprocessor|
    it "mocks a header whose #include names a header beside it that an earlier search path shadows, under :use_test_preprocessor #{preprocessor}" do
      in_project do
        FileUtils.mkdir_p( ['src/hw', 'lib'] )
        File.write( 'src/hw/config.h', "#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\ntypedef int hw_t;\n#endif\n" )
        File.write( 'lib/config.h', "#ifndef LIB_CONFIG_H\n#define LIB_CONFIG_H\n#define LIB_K 1\n#endif\n" )
        File.write( 'lib/util.h', "#ifndef UTIL_H\n#define UTIL_H\n#include \"config.h\"\nint util_k(void);\n#endif\n" )
        File.write( 'lib/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n#include \"config.h\"\n#include \"hw/config.h\"\n#include \"util.h\"\n" \
                                   "static inline int motor_peek(void) { return 0; }\nhw_t motor_run(int a);\n#endif\n" )
        File.write( 'test/test_motor.c', "#include \"unity.h\"\n#include \"mock_motor.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n" \
                                         "void test_run(void) { motor_run_ExpectAndReturn(1, 9); TEST_ASSERT_EQUAL_INT(9, motor_run(1)); }\n" )
        @c.remove_project_yml_option_for_test( :paths, :include )
        @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => preprocessor }, :paths => { :include => ['src/hw/', 'src/', 'lib/', 'test/stubs'] },
                                         :cmock => { :treat_inlines => :include } } )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+3/)
      end
    end
  end

  # Under fallback the copy's #includes are read as written, not resolved by the compiler. The one
  # beside its includer is still written by its absolute path, never the shadowing header's name.
  [:mocks, :all].each do |preprocessor|
    it "writes the copy's #include of a header beside it that an earlier search path shadows by its absolute path under fallback, under :use_test_preprocessor #{preprocessor}" do
      in_project do
        FileUtils.mkdir_p( ['src/hw', 'lib'] )
        File.write( 'src/hw/config.h', "#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\ntypedef int hw_t;\n#endif\n" )
        File.write( 'lib/config.h', "#ifndef LIB_CONFIG_H\n#define LIB_CONFIG_H\n#define LIB_K 1\n#endif\n" )
        File.write( 'lib/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n#include \"config.h\"\n" \
                                   "static inline int motor_peek(void) { return 0; }\nint motor_run(int a);\n#endif\n" )
        File.write( 'test/test_motor.c', "#include \"unity.h\"\n#include \"mock_motor.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n" \
                                         "void test_run(void) { motor_run_ExpectAndReturn(1, 9); TEST_ASSERT_EQUAL_INT(9, motor_run(1)); }\n" )
        @c.remove_project_yml_option_for_test( :paths, :include )
        @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => preprocessor }, :paths => { :include => ['src/hw/', 'lib/', 'test/stubs'] },
                                         :cmock => { :treat_inlines => :include }, :test_build => { :preprocess_force_fallback => true } } )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+3/)

        copies = Dir.glob( 'build/test/preprocess/files/**/motor.h' ).reject { |path| path.include?( '/directives_only/' ) or path.include?( '/full_expansion/' ) }
        expect(copies.size).to eq(1), copies.inspect
        expect(File.readlines( copies.first ).grep( /config\.h/ )).to eq( ["#include \"#{File.join( File.realpath( '.' ), 'lib/config.h' )}\"\n"] )
      end
    end
  end
end
