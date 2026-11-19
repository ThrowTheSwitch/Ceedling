# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## Headers Found Through Search Paths as the Compiler Finds Them
## =============================================================
##
## A test's #include names a header by its path below a search path, and the compiler
## joins each search path with that path in turn. Ceedling finds a mock's header, and
## checks a test's plain #includes, the same way, so a search path need not list every
## directory below it.
##

HEADER_SEARCH_PREAMBLE = "#include \"unity.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\n"

# A header below a search path that doesn't list its directory
HEADER_SEARCH_DRIVERS_FOO = "#ifndef FOO_H\n#define FOO_H\ntypedef int foo_t;\nint foo_read(void);\n#endif\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "header_search"

  def write(path, content)
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, content )
  end

  # Merging adds to a list, so the new project's own include paths are removed first
  def configure(include_paths, preprocessor, extra = {})
    @c.remove_project_yml_option_for_test( :paths, :include )
    @c.merge_project_yml_for_test( { :project => { :use_test_preprocessor => preprocessor }, :paths => { :include => include_paths } }.merge( extra ) )
  end

  def build_passes
    output = @c.ceedling_build_exec( "test:all" )

    expect(@c.last_exit_status).to eq(0), output
    expect(output).to match(/PASSED:\s+1/)
    return output
  end

  [:none, :mocks, :all].each do |preprocessor|
    context "with :use_test_preprocessor #{preprocessor}" do
      it "mocks a header named by its directory below a search path that doesn't list that directory" do
        in_project do
          write( 'src/drivers/foo.h', "int foo_read(void);\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

          configure( ['src'], preprocessor )
          build_passes
        end
      end

      it "includes a header named by its directory below a search path that doesn't list that directory" do
        in_project do
          write( 'src/drivers/foo.h', "#define FOO_MAGIC 7\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n" \
                                  "void test_magic(void) { TEST_ASSERT_EQUAL_INT(7, FOO_MAGIC); }\n" )

          configure( ['src'], preprocessor )
          build_passes
        end
      end

      it "includes the header below the first search path holding the path, as the compiler does" do
        in_project do
          write( 'a/drivers/foo.h', "#define FOO_MAGIC 1\n" )
          write( 'b/drivers/foo.h', "#define FOO_MAGIC 2\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n" \
                                  "void test_magic(void) { TEST_ASSERT_EQUAL_INT(1, FOO_MAGIC); }\n" )

          configure( ['a', 'b'], preprocessor )
          output = build_passes

          # A preprocessed test file's #include names the header GCC already chose
          expect(output).to include( "Multiple files matched 'drivers/foo.h' but chose 'a/drivers/foo.h'" ) unless preprocessor == :all
        end
      end

      it "mocks the header below the search path TEST_INCLUDE_PATH() puts first" do
        in_project do
          write( 'a/drivers/foo.h', "int a_read(void);\n" )
          write( 'b/drivers/foo.h', "int b_read(void);\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "TEST_INCLUDE_PATH(\"b\")\n#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { b_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, b_read()); }\n" )

          configure( ['a', 'b'], preprocessor )
          build_passes
        end
      end
    end
  end

  # A preprocessed test's mock keeps the #include the test wrote. A header of the path its
  # mirrored place would name, below an earlier search path, is a different header.
  it "mocks and includes the header a preprocessed test's #include names, not one of its mirrored path in an earlier search path" do
    in_project do
      write( 'test/support/hal/foo.h', "int fake_read(void);\n" )
      write( 'inc/hal/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_foo.h\"\n" \
                              "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )
      configure( ['inc/**'], :all, { :paths => { :include => ['inc/**'], :support => ['test/support'] } } )

      build_passes
      expect(File.read( 'build/test/mocks/test/test_c/hal/mock_foo.h' )).to include( 'foo_read' )
    end
  end

  # The compiler joins a mock's #include with each search path in order, under test
  # preprocessing as without it
  [:none, :all].each do |preprocessor|
    it "mocks the header a mock's folder joins to first under :use_test_preprocessor #{preprocessor}" do
      in_project do
        write( 'test/support/hal/foo.h', "int fake_read(void);\n" )
        write( 'inc/hal/foo.h', "int foo_read(void);\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"hal/mock_foo.h\"\n" \
                                "void test_reads(void) { fake_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, fake_read()); }\n" )
        configure( ['inc/**'], preprocessor, { :paths => { :include => ['inc/**'], :support => ['test/support'] } } )

        build_passes
      end
    end
  end

  it "mocks a header by a folder below a search path without naming the mock by it" do
    in_project do
      write( 'src/drivers/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                              "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

      configure( ['src'], :none, { :cmock => { :mock_name_include_folder => false } } )
      expect(build_passes).to include( "Added search path 'src/drivers'" )
    end
  end

  # A header only :files ↳ :include supplies sits in no search path's directory. The
  # directory a test's #include implies for it joins that test's search paths, last.
  describe "a header only :files supplies" do
    SENSOR_TEST = "void test_reads(void) { sensor_read_ExpectAndReturn(42); TEST_ASSERT_EQUAL_INT(42, sensor_read()); }\n"

    def sensor_project(include_line, include_paths: ['.'], files: ['+:src/**/*.h'], preprocessor: :none, treat_inlines: :exclude)
      write( 'src/path/to/sensor.h', "int sensor_read(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + include_line + "\n" + SENSOR_TEST )
      configure( include_paths, preprocessor, { :files => { :include => files }, :cmock => { :treat_inlines => treat_inlines } } )
    end

    [:none, :mocks, :all].each do |preprocessor|
      [:exclude, :include].each do |treat_inlines|
        context "with :use_test_preprocessor #{preprocessor} and :treat_inlines #{treat_inlines}" do
          it "mocks it through the folder its #include names below a search path" do
            in_project do
              sensor_project( '#include "src/path/to/mock_sensor.h"', preprocessor: preprocessor, treat_inlines: treat_inlines )
              expect(build_passes).to_not include( 'Added search path' )
            end
          end

          it "mocks it by its bare name through the directory its #include implies" do
            in_project do
              sensor_project( '#include "mock_sensor.h"', preprocessor: preprocessor, treat_inlines: treat_inlines )
              expect(build_passes).to include(
                "Added search path 'src/path/to' for test/test_c.c after every configured search path, so \"sensor.h\" reaches src/path/to/sensor.h."
              )
            end
          end
        end
      end
    end

    it "mocks it through its folder when no search path reaches that folder, through the directory it is measured from" do
      in_project do
        write( 'inc/other.h', "int other(void);\n" )
        sensor_project( '#include "src/path/to/mock_sensor.h"', include_paths: ['inc'] )
        expect(build_passes).to include( "Added search path '.' for test/test_c.c" )
      end
    end

    it "mocks it through a folder that starts at a search path, through the directory that folder is measured from" do
      in_project do
        sensor_project( '#include "src/path/to/mock_sensor.h"', include_paths: ['src'] )
        expect(build_passes).to include( "Added search path '.' for test/test_c.c" )
      end
    end

    it "includes it in the runner through the directory its #include implies" do
      in_project do
        write( 'src/path/to/sensor_types.h', "typedef int sensor_value_t;\n" )
        sensor_project( "#include \"sensor_types.h\"\n#include \"mock_sensor.h\"\nvoid test_type(void) { sensor_value_t v = 3; TEST_ASSERT_EQUAL_INT(3, v); }",
                        files: ['+:src/**/*.h'] )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+2/)
      end
    end

    it "never lets the directory it adds shadow a configured header" do
      in_project do
        write( 'inc/config.h', "#define CONFIG_MAGIC 1\n" )
        write( 'src/path/to/config.h', "#define CONFIG_MAGIC 2\n" )
        sensor_project( "#include \"config.h\"\n#include \"mock_sensor.h\"\nvoid test_config(void) { TEST_ASSERT_EQUAL_INT(1, CONFIG_MAGIC); }",
                        include_paths: ['inc'], files: ['+:src/path/to/sensor.h'] )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+2/)
      end
    end

    it "can't be mocked once a subtractive entry removes it" do
      in_project do
        sensor_project( '#include "mock_sensor.h"', files: ['+:src/**/*.h', '-:src/path/to/sensor.h'] )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to_not eq(0)
        expect(output).to include( 'Found no file `sensor.h` in search paths.' )
      end
    end

    # The compiler rejects such an #include, and so does the build
    it "adds no search path for an #include that spells a search path's own directory into it" do
      in_project do
        write( 'src/x.h', "#define X_MAGIC 3\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"src/x.h\"\nvoid test_x(void) { TEST_ASSERT_EQUAL_INT(3, X_MAGIC); }\n" )
        configure( ['src'], :none )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to_not eq(0)
        expect(output).to_not include( 'Added search path' )
      end
    end
  end

  # glibc's socket.h sits in a multiarch directory of forwarding headers that GCC searches
  # on its own
  describe "a system header below a multiarch directory" do
    before(:each) do
      multiarch = `gcc -print-multiarch 2>#{File::NULL}`.strip
      @multiarch_dir = "/usr/include/#{multiarch}"
      skip "no glibc sys/socket.h below a multiarch directory" if multiarch.empty? or !File.exist?( File.join( @multiarch_dir, 'sys/socket.h' ) )
    end

    SOCKET_TEST = "void test_socket(void) { socket_ExpectAndReturn(1, 2, 3, 4); TEST_ASSERT_EQUAL_INT(4, socket(1, 2, 3)); }\n"

    def socket_project(include_line, include_paths:, files: [], preprocessor: :all, cmock: {})
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include <errno.h>\n" + include_line + "\n" + SOCKET_TEST )
      configure( include_paths, preprocessor, { :files => { :include => files }, :cmock => { :treat_externs => :include }.merge( cmock ) } )
    end

    def socket_header
      return File.join( @multiarch_dir, 'sys/socket.h' )
    end

    it "mocks it by its subdirectory below the multiarch directory a search path lists" do
      in_project do
        socket_project( '#include "sys/mock_socket.h"', include_paths: [@multiarch_dir] )
        build_passes
      end
    end

    it "mocks it by its subdirectory through the directory its #include implies, when only :files lists it" do
      in_project do
        socket_project( '#include "sys/mock_socket.h"', include_paths: ['test'], files: [File.join( @multiarch_dir, 'sys/socket.h' )] )
        # Ceedling spells a path outside the project from the working directory
        expect(build_passes).to match( /Added search path '[^']*#{Regexp.escape( @multiarch_dir )}' for test\/test_c\.c/ )
      end
    end

    # A failed lookup stops the build in stage 2 without test preprocessing, and later with it
    [:none, :all].each do |preprocessor|
      it "adds no search path for its bare name, and its error at :use_test_preprocessor #{preprocessor} names the #include that reaches it" do
        in_project do
          socket_project( '#include "mock_socket.h"', include_paths: ['test'], files: [socket_header], preprocessor: preprocessor )

          output = @c.ceedling_build_exec( "test:all" )
          expect(@c.last_exit_status).to_not eq(0)
          expect(output).to include(
            "Found no file `socket.h` in search paths. `#include \"mock_socket.h\"` in test/test_c.c needs search path '#{@multiarch_dir}/sys'. " \
            "Because this search path is outside the working directory and could cause shadowing of other headers, " \
            "Ceedling won't add the full search path. Instead, reference the parent folder, as in `#include \"sys/mock_socket.h\"`."
          )
          expect(output).to_not include( 'Added search path' )
        end
      end
    end

    # Captured output loses the option's arrow under a locale without UTF-8
    def naming_option(text)
      return Regexp.new( Regexp.escape( text ).gsub( Regexp.escape( ':cmock ↳ ' ) ) { ':cmock\s*\S*\s*' } )
    end

    it "names the option a mock without its folder needs in its error" do
      in_project do
        socket_project( '#include "sys/mock_socket.h"', include_paths: ['test'], files: [socket_header], cmock: { :mock_name_include_folder => false } )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to_not eq(0)
        expect(output).to match( naming_option(
          "Found no file `sys/socket.h` in search paths. `#include \"sys/mock_socket.h\"` in test/test_c.c needs search path '#{@multiarch_dir}/sys', " \
          "since its mock writes `#include \"socket.h\"` with :cmock ↳ :mock_name_include_folder disabled."
        ) )
        expect(output).to match( naming_option( 'Instead, enable :cmock ↳ :mock_name_include_folder and reference the parent folder' ) )
      end
    end

    # The lookup tries each header extension, and its error names the last
    it "explains a plain #include's bare name in its error with more than one header extension" do
      in_project do
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"socket.h\"\nvoid test_nothing(void) { TEST_ASSERT_EQUAL_INT(1, 1); }\n" )
        configure( ['test'], :none, { :files => { :include => [socket_header] }, :extension => { :header => ['.h', '.hpp'] } } )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to_not eq(0)
        expect(output).to include(
          "Found no file `socket.hpp` in search paths. `#include \"socket.h\"` in test/test_c.c needs search path '#{@multiarch_dir}/sys'."
        )
      end
    end

    # Stage 2 reads the #include from the file's text, and only a failed lookup reports it
    it "says nothing of a bare name test preprocessing removes" do
      in_project do
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#ifdef NEVER_DEFINED\n#include \"mock_socket.h\"\n#endif\n" \
                                "void test_nothing(void) { TEST_ASSERT_EQUAL_INT(1, 1); }\n" )
        configure( ['test'], :all, { :files => { :include => [socket_header] } } )

        expect(build_passes).to_not include( 'needs search path' )
      end
    end

    it "can't mock it by its subdirectory through /usr/include alone" do
      skip "this system links sys/socket.h into /usr/include itself" if File.exist?( '/usr/include/sys/socket.h' )

      in_project do
        socket_project( '#include "sys/mock_socket.h"', include_paths: ['/usr/include'] )

        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to_not eq(0)
        expect(output).to include( 'Found no file `sys/socket.h` in search paths.' )
      end
    end
  end

  # A generated file carries a header's #includes. Each names the header as the test's search
  # paths reach it, so a header below a non-recursive search path is found from there too.
  describe "a generated file's #includes" do
    [:none, :mocks, :all].each do |preprocessor|
      it "reach a header below the search path from a Partial under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
          write( 'src/sensor.h', "#ifndef SENSOR_H\n#define SENSOR_H\n#include \"drivers/foo.h\"\nfoo_t sensor_get(void);\n#endif\n" )
          write( 'src/sensor.c', "#include \"sensor.h\"\n#include \"drivers/foo.h\"\nfoo_t sensor_get(void) { return 3; }\n" )
          write( 'test/test_sensor.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                       "#include TEST_PARTIAL_ALL_MODULE(sensor)\nvoid test_get(void) { TEST_ASSERT_EQUAL_INT(3, sensor_get()); }\n" )

          configure( ['src'], preprocessor, { :project => { :use_test_preprocessor => preprocessor, :use_partials => true } } )
          build_passes
        end
      end

      it "reach a header below the search path from a mocked Partial under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
          write( 'src/sensor.h', "#ifndef SENSOR_H\n#define SENSOR_H\n#include \"drivers/foo.h\"\nfoo_t sensor_get(void);\n#endif\n" )
          write( 'test/test_sensor.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                       "#include MOCK_PARTIAL_PUBLIC_MODULE(sensor)\n" \
                                       "void test_get(void) { sensor_get_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(3, sensor_get()); }\n" )

          configure( ['src'], preprocessor, { :project => { :use_test_preprocessor => preprocessor, :use_partials => true } } )
          build_passes
        end
      end
    end

    [:mocks, :all].each do |preprocessor|
      it "reach a header below the search path from CMock's copy under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
          write( 'src/sensor.h', "#ifndef SENSOR_H\n#define SENSOR_H\n#include \"drivers/foo.h\"\nfoo_t sensor_get(void);\n#endif\n" )
          write( 'test/test_sensor.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_sensor.h\"\n" \
                                       "void test_get(void) { sensor_get_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(3, sensor_get()); }\n" )

          configure( ['src'], preprocessor, { :cmock => { :treat_inlines => :include } } )
          build_passes
        end
      end
    end

    # A Partial's module includes a header beside it, which an earlier search path shadows with a
    # header of the same name. The generated Partial's #include reaches the one beside the module.
    [:mocks, :all].product( [false, true] ).each do |preprocessor, fallback|
      it "reach a header beside a Partial's module that an earlier search path shadows, under :use_test_preprocessor #{preprocessor}#{fallback ? ' with fallback' : ''}" do
        in_project do
          write( 'src/hw/config.h', "#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\ntypedef int hw_t;\n#endif\n" )
          write( 'lib/config.h', "#ifndef LIB_CONFIG_H\n#define LIB_CONFIG_H\n#define LIB_K 1\ntypedef int lib_t;\n#endif\n" )
          write( 'lib/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n#include \"config.h\"\nint motor_run(int a);\n#endif\n" )
          write( 'lib/motor.c', "#include \"motor.h\"\nstatic int twice(int a) { return 2 * a + LIB_K; }\nint motor_run(int a) { return twice( a ); }\n" )
          write( 'lib/port.h', "#ifndef PORT_H\n#define PORT_H\n#include \"config.h\"\nlib_t port_read(void);\n#endif\n" )
          write( 'lib/port.c', "#include \"port.h\"\nlib_t port_read(void) { return 0; }\n" )
          write( 'test/test_motor.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                      "#include TEST_PARTIAL_ALL_MODULE(motor)\nvoid test_twice(void) { TEST_ASSERT_EQUAL_INT(7, twice( 3 )); }\n" )
          write( 'test/test_port.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                     "#include MOCK_PARTIAL_PUBLIC_MODULE(port)\n" \
                                     "void test_read(void) { port_read_ExpectAndReturn( 3 ); TEST_ASSERT_EQUAL_INT(3, port_read()); }\n" )

          configure( ['src/hw/', 'lib/'], preprocessor, { :project => { :use_test_preprocessor => preprocessor, :use_partials => true } } )
          @c.merge_project_yml_for_test( { :paths => { :source => ['lib/'] } } )
          @c.merge_project_yml_for_test( { :test_build => { :preprocess_force_fallback => true } } ) if fallback

          output = @c.ceedling_build_exec( "test:all" )
          expect(@c.last_exit_status).to eq(0), output
          expect(output).to match(/PASSED:\s+2/)
        end
      end
    end

    # A preprocessor names each #include by the path it found the header by. A later search path
    # joined with that path can name another header, which must never take its place.
    it "include the header the compiler found, never one a later search path joins its path to" do
      in_project do
        write( 'include/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define GAIN 3\n#endif\n" )
        write( 'third_party/mylib/include/config.h', "#ifndef MYLIB_CONFIG_H\n#define MYLIB_CONFIG_H\n#define GAIN 99\n#endif\n" )
        write( 'include/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n#include \"config.h\"\nint motor_run(void);\n" \
                                  "static inline int motor_peek(void) { return GAIN; }\n#endif\n" )
        write( 'src/motor.c', "#include \"motor.h\"\nint motor_run(void) { return GAIN; }\n" )
        write( 'test/test_motor.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                    "#include TEST_PARTIAL_PUBLIC_MODULE(motor)\nvoid test_run(void) { TEST_ASSERT_EQUAL_INT(3, motor_run()); }\n" )
        write( 'test/test_cm.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_motor.h\"\nvoid test_gain(void) { TEST_ASSERT_EQUAL_INT(3, GAIN); }\n" )

        configure( ['include/**', 'third_party/**'], :all, { :project => { :use_test_preprocessor => :all, :use_partials => true },
                                                             :cmock => { :treat_inlines => :include } } )
        output = @c.ceedling_build_exec( "test:all" )

        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+2/)
      end
    end

    it "include in the runner the header the compiler found, never one a later search path joins its path to" do
      in_project do
        write( 'include/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define GAIN 3\n#endif\n" )
        write( 'third_party/mylib/include/config.h', "#error The library's config.h reached the runner\n" )
        write( 'test/test_gain.c', HEADER_SEARCH_PREAMBLE + "#include \"config.h\"\nvoid test_gain(void) { TEST_ASSERT_EQUAL_INT(3, GAIN); }\n" )

        configure( ['include/**', 'third_party/**'], :all )
        build_passes
      end
    end

    # The compiler joins an #include with each search path. A header directly in a search path
    # isn't reached through the directory that path names.
    it "include in the runner by a text the compiler joins, never one only a header's trailing path matches" do
      in_project do
        write( 'test/hw/config.h', "#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\n#define HW_GAIN 3\n#endif\n" )
        write( 'lib/app/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define APP_GAIN 5\n#endif\n" )
        write( 'test/test_gain.c', HEADER_SEARCH_PREAMBLE + "#include \"hw/config.h\"\n#include \"app/config.h\"\n" \
                                   "void test_gain(void) { TEST_ASSERT_EQUAL_INT(15, HW_GAIN * APP_GAIN); }\n" )

        configure( ['lib/'], :all )
        build_passes
      end
    end

    # A quoted #include looks beside the test file first, and the test's own compile finds that
    # header. A header there that no search path reaches is another header than the search paths'
    # of the same name, so the runner includes it by its absolute path.
    it "include in the runner the header beside the test, never one of its name a search path finds" do
      in_project do
        write( 'test/drivers/foo.h', "#ifndef TFOO_H\n#define TFOO_H\n#define WHICH 1\n#endif\n" )
        write( 'src/drivers/foo.h', "#ifndef SFOO_H\n#define SFOO_H\n#define WHICH 2\n#endif\n" )
        write( 'src/other.h', "int other_read(void);\n" )
        write( 'test/test_b.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n#include \"mock_other.h\"\n" \
                                "void test_b(void) { TEST_ASSERT_EQUAL_INT(1, WHICH); }\n" )

        configure( ['src/'], :none )
        @c.remove_project_yml_option_for_test( :paths, :test )
        @c.merge_project_yml_for_test( { :paths => { :test => ['test/'] } } )
        build_passes

        runner = File.readlines( Dir.glob( 'build/test/runners/**/test_b_runner.c' ).first ).select { |line| line.include?( 'foo.h' ) }
        expect(runner).to eq( ["#include \"#{File.expand_path( 'test/drivers/foo.h' )}\"\n"] )
      end
    end

    # Ceedling generates a Partial's header into the build root, where the compiler's -I reaches
    # it by its filename. The runner names it so, never by its absolute path.
    [:none, :mocks, :all].each do |preprocessor|
      it "include in the runner a Partial's generated header by its filename under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/calc.h', "#ifndef CALC_H\n#define CALC_H\nint calc(int a);\n#endif\n" )
          write( 'src/calc.c', "#include \"calc.h\"\nstatic int twice(int a) { return 2 * a; }\nint calc(int a) { return twice( a ) + 1; }\n" )
          write( 'test/test_calc.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                     "#include TEST_PARTIAL_ALL_MODULE(calc)\nvoid test_twice(void) { TEST_ASSERT_EQUAL_INT(6, twice( 3 )); }\n" )

          configure( ['src'], preprocessor, { :project => { :use_test_preprocessor => preprocessor, :use_partials => true } } )
          build_passes

          runner = File.readlines( Dir.glob( 'build/test/runners/**/test_calc_runner.c' ).first ).select { |line| line.include?( 'ceedling_partial_calc_impl.h' ) }
          expect(runner).to eq( ["#include \"ceedling_partial_calc_impl.h\"\n"] )
        end
      end
    end

    # Reconciliation spells two same-named headers apart. A directory searched ahead of the
    # project's, such as the one holding CMock's copy of one of them, must never capture the other.
    it "keep the paths that tell two same-named headers apart" do
      in_project do
        write( 'src/hw/config.h', "#ifndef HW_CONFIG_H\n#define HW_CONFIG_H\ntypedef int hw_t;\n" \
                                  "static inline int hw_peek(void) { return -1; }\nint hw_read(void);\n#endif\n" )
        write( 'src/app/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define APP_GAIN 5\ntypedef int app_t;\n#endif\n" )
        write( 'src/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n#include \"hw/config.h\"\n#include \"app/config.h\"\nhw_t motor_run(app_t a);\n#endif\n" )
        write( 'src/motor.c', "#include \"motor.h\"\n#include \"hw/config.h\"\n#include \"app/config.h\"\n" \
                              "hw_t motor_run(app_t a) { return APP_GAIN * a * hw_read(); }\n" )
        write( 'test/test_motor.c', HEADER_SEARCH_PREAMBLE.sub( "\n", "\n#include \"ceedling.h\"\n" ) +
                                    "#include TEST_PARTIAL_PUBLIC_MODULE(motor)\n#include \"hw/mock_config.h\"\n" \
                                    "void test_run(void) { hw_read_ExpectAndReturn(1); TEST_ASSERT_EQUAL_INT(5, motor_run(1)); }\n" )

        configure( ['src/**'], :all, { :project => { :use_test_preprocessor => :all, :use_partials => true },
                                       :cmock => { :treat_inlines => :include } } )
        build_passes
      end
    end

    # A mock includes its header through the folder the test named it by. A search path listing
    # only the header's own directory joins no such folder.
    [[:none, ['fff']], [:all, ['fff']], [:none, []]].each do |preprocessor, plugins|
      kind = plugins.empty? ? 'a mock' : 'an FFF fake'

      it "reach a header from #{kind} through its folder where a search path lists only the header's own directory under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
          body = plugins.empty? ? 'foo_read_ExpectAndReturn(5);' : 'foo_read_fake.return_val = 5;'
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { #{body} TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

          configure( ['src/drivers/**'], preprocessor, { :plugins => { :enabled => plugins } } )
          build_passes
        end
      end
    end

    # A mock includes its header by the text the listed directory reaches it by. A directory
    # added for the folder's parent would hold the project's string.h, shadowing the system's.
    [[:mocks, [], :include], [:all, [], :include], [:none, ['fff'], :exclude]].each do |preprocessor, plugins, treat_inlines|
      kind = plugins.empty? ? "a mock under :treat_inlines #{treat_inlines}" : 'an FFF fake'

      it "keep a project header named like a system one out of reach of #{kind} through its folder under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', "#ifndef FOO_H\n#define FOO_H\ntypedef int foo_t;\n" \
                                      "static inline foo_t foo_peek(void) { return -1000; }\nfoo_t foo_read(void);\n#endif\n" )
          write( 'src/string.h', "#error \"src/string.h shadowed <string.h>\"\n" )
          body = plugins.empty? ? 'foo_read_ExpectAndReturn(5);' : 'foo_read_fake.return_val = 5;'
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include <string.h>\n#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { #{body} TEST_ASSERT_EQUAL_INT(5, foo_read()); " \
                                  "TEST_ASSERT_EQUAL_INT(0, (int)strlen(\"\")); }\n" )

          configure( [plugins.empty? ? 'src/drivers/**' : 'src/drivers/'], preprocessor,
                     { :plugins => { :enabled => plugins }, :cmock => { :treat_inlines => treat_inlines } } )
          build_passes
        end
      end
    end

    # The compiler includes the header a mock's own #include reaches, even where the mock was
    # located by a same-named header's trailing path
    [:tests, :all].each do |preprocessor|
      it "include in a mock the same-named header its folder reaches under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', "#ifndef SDFOO_H\n#define SDFOO_H\ntypedef int foo_t;\n#define FOO_WHICH 1\nfoo_t foo_read(void);\n#endif\n" )
          write( 'src/app/drivers/foo.h', "#ifndef ADFOO_H\n#define ADFOO_H\ntypedef int foo_t;\n#define FOO_WHICH 2\nfoo_t foo_read(void);\n#endif\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); " \
                                  "TEST_ASSERT_EQUAL_INT(1, FOO_WHICH); }\n" )

          configure( ['src/', 'src/app/drivers/'], preprocessor )
          build_passes
        end
      end
    end

    # A format writing more than the text between quotes keeps the text CMock gives it
    it "include in a mock its header through a project's :orig_header_include_fmt around the folder" do
      in_project do
        write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

        configure( ['src/drivers/'], :none, { :cmock => { :orig_header_include_fmt => '#include "../%s"' } } )
        build_passes
      end
    end

    # A fake writes no format, so the text a format keeps for CMock never reaches it
    [:none, :all].each do |preprocessor|
      it "reach a header through its search path from an FFF fake under a project's :orig_header_include_fmt around the folder, under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { foo_read_fake.return_val = 5; TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

          configure( ['src/drivers/'], preprocessor, { :cmock => { :orig_header_include_fmt => '#include "../%s"' }, :plugins => { :enabled => ['fff'] } } )
          build_passes
        end
      end
    end

    [:none, :all].each do |preprocessor|
      it "reach a header below the search path from an FFF fake under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', HEADER_SEARCH_DRIVERS_FOO )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
                                  "void test_reads(void) { foo_read_fake.return_val = 5; TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

          configure( ['src'], preprocessor, { :plugins => { :enabled => ['fff'] } } )
          build_passes
        end
      end
    end
  end

  # CMock writes its copy of a header beside the mock with :treat_inlines :include. The mock
  # directory is a search path, but never one a real header is found through.
  it "mocks a header from the project, never from CMock's copy of it, on later builds" do
    in_project do
      write( 'src/foo.h', "int foo_read(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_foo.h\"\n" \
                              "void test_reads(void) { foo_read_ExpectAndReturn(5); TEST_ASSERT_EQUAL_INT(5, foo_read()); }\n" )

      configure( ['src'], :none, { :cmock => { :treat_inlines => :include } } )
      build_passes
      expect(build_passes).to_not include( 'Multiple files matched' )

      write( 'src/foo.h', "int foo_read(void);\nint foo_more(void);\n" )
      write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_foo.h\"\n" \
                              "void test_reads(void) { foo_more_ExpectAndReturn(6); TEST_ASSERT_EQUAL_INT(6, foo_more()); }\n" )
      build_passes
    end
  end

  # CMock's copy of a header outlives a switch to :exclude unless it is removed
  it "sees an edit to a mocked header after :treat_inlines changes from :include to :exclude" do
    in_project do
      header = ->(k) { "#ifndef FOO_H\n#define FOO_H\n#define FOO_K #{k}\nstatic inline int foo_peek(void) { return FOO_K; }\nint foo_read(void);\n#endif\n" }
      test   = ->(k) { HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\nvoid test_k(void) { TEST_ASSERT_EQUAL_INT(#{k}, FOO_K); }\n" }

      write( 'src/drivers/foo.h', header.( 1 ) )
      write( 'test/test_c.c', test.( 1 ) )
      configure( ['src/**'], :mocks, { :cmock => { :treat_inlines => :include } } )
      build_passes

      configure( ['src/**'], :mocks, { :cmock => { :treat_inlines => :exclude } } )
      build_passes
      expect(Dir.glob( 'build/test/mocks/**/foo.h' )).to be_empty

      write( 'src/drivers/foo.h', header.( 2 ) )
      write( 'test/test_c.c', test.( 2 ) )
      build_passes
    end
  end

  # A fake of a header's inline function would collide with the header's own definition. Under
  # :treat_inlines :include a fake includes the header's inline-free copy beside it, as a mock does.
  describe "an FFF fake under :treat_inlines :include" do
    header = "#ifndef FOO_H\n#define FOO_H\nstatic inline int foo_peek(void) { return 7; }\nint foo_read(void);\n#endif\n"
    test   = HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n" \
             "void test_reads(void) { foo_read_fake.return_val = 3; foo_peek_fake.return_val = 9; " \
             "TEST_ASSERT_EQUAL_INT(3, foo_read()); TEST_ASSERT_EQUAL_INT(9, foo_peek()); }\n"

    [:none, :mocks].each do |preprocessor|
      it "fakes a header's inline function under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', header )
          write( 'test/test_c.c', test )

          configure( ['src/**'], preprocessor, { :cmock => { :treat_inlines => :include }, :plugins => { :enabled => ['fff'] } } )
          build_passes
        end
      end

      # A search path listing only the header's own directory reaches it by its filename alone
      it "fakes the inline function of a header its search path reaches by its filename under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', header )
          write( 'test/test_c.c', test )

          configure( ['src/drivers/**'], preprocessor, { :cmock => { :treat_inlines => :include }, :plugins => { :enabled => ['fff'] } } )
          build_passes
        end
      end
    end
  end

  # A test's mock root stays on its search path. A copy of a header the test no longer mocks
  # would shadow the header from there.
  describe "a header a test stops mocking under :treat_inlines :include" do
    header = ->(k) { "#ifndef FOO_H\n#define FOO_H\n#define FOO_K #{k}\nint foo_read(void);\n#endif\n" }
    test   = ->(k, includes) { HEADER_SEARCH_PREAMBLE + includes.map { |name| "#include \"#{name}\"\n" }.join +
                                "void test_k(void) { TEST_ASSERT_EQUAL_INT(#{k}, FOO_K); }\n" }

    [[:none, [], ['drivers/mock_bar.h']], [:mocks, [], ['drivers/mock_bar.h']], [:tests, [], ['drivers/mock_bar.h']],
     [:all, [], ['drivers/mock_bar.h']], [:none, [], []], [:all, [], []],
     [:none, ['fff'], ['drivers/mock_bar.h']], [:all, ['fff'], ['drivers/mock_bar.h']]].each do |preprocessor, plugins, kept|
      remaining = kept.empty? ? 'no mock' : (plugins.empty? ? 'another mock' : 'another FFF fake')

      it "sees an edit to the header beside #{remaining} under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', header.( 1 ) )
          write( 'src/drivers/bar.h', "int bar_read(void);\n" )
          write( 'test/test_c.c', test.( 1, ['drivers/mock_foo.h', 'drivers/mock_bar.h'] ) )
          configure( ['src/**'], preprocessor, { :cmock => { :treat_inlines => :include }, :plugins => { :enabled => plugins } } )
          build_passes

          write( 'src/drivers/foo.h', header.( 2 ) )
          write( 'test/test_c.c', test.( 2, ['drivers/foo.h'] + kept ) )
          build_passes
        end
      end
    end

    # CMock names a mock and its copy with the header's own extension
    [:none, :all].each do |preprocessor|
      it "sees an edit to a header with another extension under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foox.hpp', header.( 1 ) )
          write( 'src/drivers/bar.h', "int bar_read(void);\n" )
          write( 'test/test_c.c', test.( 1, ['drivers/mock_foox.hpp', 'drivers/mock_bar.h'] ) )
          configure( ['src/**'], preprocessor, { :cmock => { :treat_inlines => :include }, :extension => { :header => ['.h', '.hpp'] } } )
          build_passes
          expect(build_passes).to_not include( 'Generating mock for' )

          write( 'src/drivers/foox.hpp', header.( 2 ) )
          write( 'test/test_c.c', test.( 2, ['drivers/foox.hpp', 'drivers/mock_bar.h'] ) )
          build_passes
        end
      end
    end

    # An FFF fake names its files as CMock names a mock's, with the header's own extension
    [:none, :all].each do |preprocessor|
      it "sees an edit to a header with another extension beside an FFF fake under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foox.hpp', header.( 1 ) )
          write( 'src/drivers/bar.h', "int bar_read(void);\n" )
          write( 'test/test_c.c', test.( 1, ['drivers/mock_foox.hpp', 'drivers/mock_bar.h'] ) )
          configure( ['src/**'], preprocessor, { :cmock => { :treat_inlines => :include }, :extension => { :header => ['.h', '.hpp'] }, :plugins => { :enabled => ['fff'] } } )
          build_passes
          expect(build_passes).to_not include( 'Generating mock for' )

          write( 'src/drivers/foox.hpp', header.( 2 ) )
          write( 'test/test_c.c', test.( 2, ['drivers/foox.hpp', 'drivers/mock_bar.h'] ) )
          build_passes
        end
      end
    end

    # A mock of foox.hpp stands in for that header only. The source of foox.h still links.
    [:none, :tests].each do |preprocessor|
      it "links the source of a header the test includes beside a mock of a header with another extension under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foox.hpp', "#ifndef FOOX_H\n#define FOOX_H\n#define FOOX_K 1\nint foox_read(void);\n#endif\n" )
          write( 'src/drivers/foox.h', "#ifndef FOOX_C_H\n#define FOOX_C_H\nint foox_c_api(void);\n#endif\n" )
          write( 'src/drivers/foox.c', "#include \"foox.h\"\nint foox_c_api(void) { return 5; }\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foox.h\"\n#include \"drivers/mock_foox.hpp\"\n" \
                                  "void test_k(void) { TEST_ASSERT_EQUAL_INT(1, FOOX_K); TEST_ASSERT_EQUAL_INT(5, foox_c_api()); }\n" )
          configure( ['src/**'], preprocessor, { :extension => { :header => ['.h', '.hpp'] } } )
          build_passes
        end
      end
    end

    # A mock of foox.h stands in for the header foox.c implements, though the test includes foox.hpp
    [:none, :tests].each do |preprocessor|
      it "links no source for a mocked header beside a real header with another extension under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foox.hpp', "#ifndef FOOX_HPP\n#define FOOX_HPP\n#define FOOX_K 1\n#endif\n" )
          write( 'src/drivers/foox.h', "#ifndef FOOX_H\n#define FOOX_H\nint foox_c_api(void);\n#endif\n" )
          write( 'src/drivers/foox.c', "#include \"foox.h\"\nint foox_c_api(void) { return 5; }\n" )
          write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foox.hpp\"\n#include \"drivers/mock_foox.h\"\n" \
                                  "void test_k(void) { foox_c_api_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(1, FOOX_K); TEST_ASSERT_EQUAL_INT(3, foox_c_api()); }\n" )
          configure( ['src/**'], preprocessor, { :extension => { :header => ['.h', '.hpp'] } } )
          build_passes
        end
      end
    end

    # A mock of a header with another extension leaves the same-named source in place, however
    # the test reaches the .h header that source implements
    it "links a named source beside a mock of a header with another extension whose stem another header shares" do
      in_project do
        write( 'src/drivers/foox.hpp', "#ifndef FOOX_HPP\n#define FOOX_HPP\n#define FOOX_K 1\nint foox_read(void);\n#endif\n" )
        write( 'src/drivers/foox.h', "#ifndef FOOX_H\n#define FOOX_H\nint foox_c_api(void);\n#endif\n" )
        write( 'src/drivers/foox.c', "#include \"foox.h\"\nint foox_c_api(void) { return 5; }\n" )
        write( 'src/drivers/bar.h', "#ifndef BAR_H\n#define BAR_H\n#include \"foox.h\"\n#endif\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/bar.h\"\n#include \"drivers/mock_foox.hpp\"\n" \
                                "TEST_SOURCE_FILE(\"src/drivers/foox.c\")\n" \
                                "void test_k(void) { TEST_ASSERT_EQUAL_INT(1, FOOX_K); TEST_ASSERT_EQUAL_INT(5, foox_c_api()); }\n" )
        configure( ['src/**'], :none, { :extension => { :header => ['.h', '.hpp'] } } )
        build_passes
      end
    end

    # The source of a header the test both includes and mocks stays out of the link
    it "links no source for a header the test includes and mocks under :use_test_preprocessor none" do
      in_project do
        write( 'src/drivers/foo.h', "int foo_read(void);\n" )
        write( 'src/drivers/foo.c', "#include \"foo.h\"\nint foo_read(void) { return 5; }\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n#include \"drivers/mock_foo.h\"\n" \
                                "void test_k(void) { foo_read_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(3, foo_read()); }\n" )
        configure( ['src/**'], :none )
        build_passes
      end
    end

    # Stage 4 places a stand-in for the mock under the extension the test's #include names
    it "places a stand-in for a mock of a header with another extension that the preprocessor reads under :use_test_preprocessor tests" do
      in_project do
        write( 'src/drivers/foox.hpp', header.( 1 ) )
        write( 'test/test_c.c', test.( 1, ['drivers/mock_foox.hpp'] ) )
        configure( ['src/**'], :tests, { :extension => { :header => ['.h', '.hpp'] } } )
        expect(build_passes).to_not include( 'Failed to generate directive-only' )

        write( 'test/test_c.c', test.( 1, ['drivers/mock_foox.hpp'] ) + "// edited\n" )
        expect(build_passes).to_not include( 'Failed to generate directive-only' )
      end
    end

    # Stage 4 sees the test's #includes before any mock is planned. A rebuild generates nothing.
    it "generates no mock again on a rebuild after the test stops mocking a header under :use_test_preprocessor all" do
      in_project do
        write( 'src/drivers/foo.h', header.( 1 ) )
        write( 'src/drivers/bar.h', "int bar_read(void);\n" )
        write( 'test/test_c.c', test.( 1, ['drivers/mock_foo.h', 'drivers/mock_bar.h'] ) )
        configure( ['src/**'], :all, { :cmock => { :treat_inlines => :include } } )
        build_passes

        write( 'test/test_c.c', test.( 1, ['drivers/foo.h', 'drivers/mock_bar.h'] ) )
        build_passes
        expect(build_passes).to_not include( 'Generating mock for' )
      end
    end

    # Only the preprocessor names a mock whose #include a macro computes
    it "generates no mock again on a rebuild for a mock only the preprocessor names under :use_test_preprocessor all" do
      in_project do
        write( 'src/drivers/widget.h', "#ifndef WIDGET_H\n#define WIDGET_H\nint widget_read(void);\n#endif\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#define WIDGET_MOCK \"drivers/mock_widget.h\"\n#include WIDGET_MOCK\n" \
                                "void test_w(void) { widget_read_ExpectAndReturn(7); TEST_ASSERT_EQUAL_INT(7, widget_read()); }\n" )
        configure( ['src/**'], :all, { :cmock => { :treat_inlines => :include } } )
        build_passes

        expect(build_passes).to_not include( 'Generating mock for' )
      end
    end

    # A same-named mock in another folder names no copy but its own
    it "sees an edit to a header the test stops mocking beside a same-named mock under :use_test_preprocessor all" do
      in_project do
        write( 'src/a/drivers/foo.h', "#ifndef AFOO_H\n#define AFOO_H\nint fa_read(void);\n#endif\n" )
        write( 'src/b/drivers/foo.h', header.( 1 ) )
        write( 'test/test_c.c', test.( 1, ['a/drivers/mock_foo.h', 'b/drivers/mock_foo.h'] ) )
        configure( ['src/**'], :all, { :cmock => { :treat_inlines => :include } } )
        build_passes

        write( 'src/b/drivers/foo.h', header.( 2 ) )
        write( 'test/test_c.c', test.( 2, ['a/drivers/mock_foo.h', 'b/drivers/foo.h'] ) )
        build_passes
      end
    end

    # The text names a mock the preprocessor no longer reaches
    it "sees an edit to a header a test's conditional #include stops mocking under :use_test_preprocessor all" do
      in_project do
        write( 'src/cfg.h', "#ifndef CFG_H\n#define CFG_H\n#define USE_MOCK 1\n#endif\n" )
        write( 'src/drivers/foo.h', header.( 1 ) )
        write( 'src/drivers/bar.h', "int bar_read(void);\n" )
        conditional = ->(k) { HEADER_SEARCH_PREAMBLE + "#include \"cfg.h\"\n#include \"drivers/mock_bar.h\"\n#if USE_MOCK\n" \
                                "#include \"drivers/mock_foo.h\"\n#else\n#include \"drivers/foo.h\"\n#endif\n" \
                                "void test_k(void) { TEST_ASSERT_EQUAL_INT(#{k}, FOO_K); }\n" }
        write( 'test/test_c.c', conditional.( 1 ) )
        configure( ['src/**'], :all, { :cmock => { :treat_inlines => :include } } )
        build_passes

        write( 'src/cfg.h', "#ifndef CFG_H\n#define CFG_H\n#define USE_MOCK 0\n#endif\n" )
        write( 'src/drivers/foo.h', header.( 2 ) )
        write( 'test/test_c.c', conditional.( 2 ) )
        build_passes
      end
    end

    # CMock's own #include text reaches only its copy where a search path lists only the header's
    # own directory. Stage 4 reads a stand-in for the mock while its copy is set aside.
    [:tests, :all].each do |preprocessor|
      it "collects a rebuilt test's #includes through a mock whose header only its copy reaches by CMock's text under :use_test_preprocessor #{preprocessor}" do
        in_project do
          write( 'src/drivers/foo.h', "#ifndef FOO_H\n#define FOO_H\n#define FOO_K 1\nstatic inline int foo_peek(void) { return 7; }\nint foo_read(void);\n#endif\n" )
          test_file = HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n#if FOO_K == 2\nTEST_SOURCE_FILE(\"nothere.c\")\n#endif\n" \
                      "void test_r(void) { foo_read_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(3, foo_read()); }\n"
          write( 'test/test_c.c', test_file )
          configure( ['src/drivers/**'], preprocessor, { :cmock => { :treat_inlines => :include } } )
          build_passes

          write( 'test/test_c.c', test_file + "// edited\n" )
          expect(build_passes).to_not include( 'Failed to generate directive-only' )
        end
      end
    end

    # A mocked header decides which other mocks the test needs, as stage 4 reads it
    it "sees an edit to a mocked header that decides the test's other mocks under :use_test_preprocessor all" do
      in_project do
        cfg  = ->(on) { "#ifndef CFG_H\n#define CFG_H\n#{on ? '' : '//'}#define TWO_ON\nint cfg_read(void);\n#endif\n" }
        write( 'src/cfg.h', cfg.( false ) )
        write( 'src/two.h', "int two_read(void);\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"mock_cfg.h\"\n#ifdef TWO_ON\n#include \"mock_two.h\"\n#endif\n" \
                                "void test_t(void) {\n#ifdef TWO_ON\n  two_read_ExpectAndReturn(4); TEST_ASSERT_EQUAL_INT(4, two_read());\n#endif\n}\n" )
        configure( ['src/**'], :all, { :cmock => { :treat_inlines => :include } } )
        build_passes

        write( 'src/cfg.h', cfg.( true ) )
        build_passes
      end
    end

    # A header named with the mock prefix is reached through another header, since the test's
    # own #include of it would name a mock
    it "sees an edit to a header whose name starts with the mock prefix" do
      in_project do
        motor = ->(k) { "#ifndef MOTOR_H\n#define MOTOR_H\n#define MOTOR_K #{k}\nint motor_read(void);\n#endif\n" }

        write( 'src/drivers/motor.h', motor.( 1 ) )
        write( 'src/drivers/bar.h', "int bar_read(void);\n" )
        write( 'src/app/wrap.h', "#include \"drivers/motor.h\"\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mmotor.h\"\n#include \"drivers/mbar.h\"\n" \
                                "void test_k(void) { TEST_ASSERT_EQUAL_INT(1, MOTOR_K); }\n" )
        configure( ['src/**'], :none, { :cmock => { :mock_prefix => 'm', :treat_inlines => :include } } )
        build_passes

        write( 'src/drivers/motor.h', motor.( 2 ) )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"app/wrap.h\"\n#include \"drivers/mbar.h\"\n" \
                                "void test_k(void) { TEST_ASSERT_EQUAL_INT(2, MOTOR_K); }\n" )
        build_passes
      end
    end

    # Mock preprocessing reaches the header through the mock root too
    it "preprocesses a remaining mock's header with the edited header it includes under :use_test_preprocessor mocks" do
      in_project do
        bar  = "#ifndef BAR_H\n#define BAR_H\n#include \"drivers/foo.h\"\n#if FOO_K == 1\nint bar_one(void);\n#else\nint bar_two(void);\n#endif\n"
        call = ->(fn, k) { "void test_k(void) { #{fn}_ExpectAndReturn(#{k}); TEST_ASSERT_EQUAL_INT(#{k}, #{fn}()); }\n" }

        write( 'src/drivers/foo.h', header.( 1 ) )
        write( 'src/drivers/bar.h', bar + "#endif\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/mock_foo.h\"\n#include \"drivers/mock_bar.h\"\n" + call.( 'bar_one', 1 ) )
        configure( ['src/**'], :mocks, { :cmock => { :treat_inlines => :include } } )
        build_passes

        write( 'src/drivers/foo.h', header.( 2 ) )
        write( 'src/drivers/bar.h', bar + "int bar_more(void);\n#endif\n" )
        write( 'test/test_c.c', HEADER_SEARCH_PREAMBLE + "#include \"drivers/foo.h\"\n#include \"drivers/mock_bar.h\"\n" + call.( 'bar_two', 2 ) )
        build_passes
      end
    end
  end

  # FFF replaces CMock, writing a different file from the same configuration
  it "regenerates a mock when the FFF plugin is turned on or off" do
    in_project do
      cmock_test = HEADER_SEARCH_PREAMBLE + "#include \"mock_led.h\"\nvoid test_level(void) { led_level_ExpectAndReturn(3); TEST_ASSERT_EQUAL_INT(3, led_level()); }\n"
      fff_test   = HEADER_SEARCH_PREAMBLE + "#include \"mock_led.h\"\nvoid test_level(void) { led_level_fake.return_val = 3; TEST_ASSERT_EQUAL_INT(3, led_level()); }\n"

      write( 'src/led.h', "int led_level(void);\n" )
      write( 'test/test_c.c', cmock_test )
      configure( ['src'], :none )
      build_passes
      without_fff = File.read( 'project.yml' )

      write( 'test/test_c.c', fff_test )
      @c.merge_project_yml_for_test( { :plugins => { :enabled => ['fff'] } } )
      build_passes

      write( 'test/test_c.c', cmock_test )
      File.write( 'project.yml', without_fff )
      build_passes
    end
  end
end
