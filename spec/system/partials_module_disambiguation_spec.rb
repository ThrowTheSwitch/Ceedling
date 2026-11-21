# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_system_helper'

##
## End-to-end builds for selecting a Partial module when more than one module
## shares its basename.
##
## The project shape is issue #1311's own: one include root, headers namespaced
## below it, and a source tree mirroring that namespace. Both config modules define
## a private `adjust` with different arithmetic, so a Partial built from the wrong
## module still compiles and links. A wrong resolution surfaces as a wrong value,
## which is the silent failure the issue warns about.
##
## Assets: assets/fixtures/same_named_modules/
##

PARTIALS_DISAMBIG_PREAMBLE = "#include \"unity.h\"\n#include \"ceedling.h\"\n"

ceedling_system_tests do
  include_context "a fresh ceedling gem project", "partial_disambig"

  describe "Deployed as a gem" do

    # One module staged, so its bare name is unambiguous project-wide. This is the
    # baseline the ambiguous cases are read against.
    context "with only one of the two same-named modules present" do
      before do
        copy_same_named_partial_modules('uart')
        in_project do
          copy_fixture("same_named_modules/test/test_uart_config_bare.c", 'test')
        end
      end

      it "builds a Partial from a bare module name and reaches that module's own functions" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end
    end

    # Issue #1311's own shape: one test file Partializing two modules that share a
    # basename, each named by its own directory.
    context "with both same-named modules Partialized in one test" do
      before do
        copy_same_named_partial_modules('uart', 'spi')
        in_project do
          copy_fixture("same_named_modules/test/test_both_configs.c", 'test')
        end
      end

      it "builds a Partial per module and reaches each module's own functions" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      # Fallback preprocessing synthesizes each generated Partial's #include from the
      # module name rather than resolving the real file, so the include carries its
      # module's directory without sitting under any build root. That directory still
      # names the module, and dropping it leaves two same-named modules indistinguishable
      # even though the test named both by directory.
      it "builds a Partial per module under fallback preprocessing" do
        in_project do
          @c.merge_project_yml_for_test({ :test_build => { :preprocess_force_fallback => true } })

          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+2/)
          expect(output).to match(/PASSED:\s+2/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      # The two Partials are distinct files only because each sits in the subdirectory
      # mirroring its own module. Sharing one directory would mean sharing one filename.
      it "generates each Partial into its own mirrored subdirectory" do
        in_project do
          @c.ceedling_build_exec("test:all")

          partials = Dir.glob('build/test/partials/**/ceedling_partial_config_impl.c')

          expect(partials.length).to eq(2)
          expect(partials.any? { |path| path.include?('drivers/uart') }).to be true
          expect(partials.any? { |path| path.include?('drivers/spi') }).to be true
        end
      end
    end

    # Mocking is the other half of the same feature. Two same-named modules each mocked as
    # a Partial must each get their own mock, which only happens if the two are held apart
    # by the directory that distinguishes them.
    context "with both same-named modules mocked as Partials in one test" do
      before do
        copy_same_named_partial_modules('uart', 'spi')
        in_project do
          copy_fixture("same_named_modules/test/test_both_configs_mocked.c", 'test')
        end
      end

      # Both mocks share a filename, so only the directory each #include names tells them
      # apart. CMock and the runner fold that directory into each mock's guard and
      # lifecycle function names.
      it "generates a mock per module and keeps their expectations separate" do
        in_project do
          output = @c.ceedling_build_exec("test:all")

          expect(@c.last_exit_status).to eq(0)
          expect(output).to match(/TESTED:\s+1/)
          expect(output).to match(/PASSED:\s+1/)
          expect(output).to match(/FAILED:\s+0/)
        end
      end

      it "generates each mock into its own mirrored subdirectory" do
        in_project do
          @c.ceedling_build_exec("test:all")

          mocks = Dir.glob('build/test/mocks/**/mock_ceedling_partial_config_interface.c')

          expect(mocks.length).to eq(2)
          expect(mocks.any? { |path| path.include?('drivers/uart') }).to be true
          expect(mocks.any? { |path| path.include?('drivers/spi') }).to be true
        end
      end
    end

    # A module named by directory claims only its own header. Another header sharing its
    # basename, partialized or not, keeps its place in every generated file.
    context "with a module named by directory beside a same-named header" do
      def include_paths(paths)
        @c.remove_project_yml_option_for_test( :paths, :include )
        @c.merge_project_yml_for_test( { :paths => { :include => paths } } )
      end

      def write(path, text)
        FileUtils.mkdir_p( File.dirname( path ) )
        File.write( path, text )
      end

      def build_passing
        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+1/)
      end

      # The mocked module's real inline body fails any test it runs in
      def same_named_configs
        write( 'include/drivers/uart/config.h', "#ifndef UART_CONFIG_H\n#define UART_CONFIG_H\nint uart_config_baud(void);\n#endif\n" )
        write( 'include/drivers/spi/config.h',
               "#ifndef SPI_CONFIG_H\n#define SPI_CONFIG_H\ntypedef struct spi_cfg { int div; } spi_cfg_t;\n" \
               "static inline int spi_read(void) { return -1000; }\nint spi_config_clock_div(void);\n#endif\n" )
        write( 'src/drivers/uart/config.c',
               "#include \"drivers/uart/config.h\"\n#include \"drivers/spi/config.h\"\n" \
               "int uart_config_baud(void) { spi_cfg_t c = { spi_read() }; return c.div + 1; }\n" )
        write( 'src/drivers/spi/config.c', "#include \"drivers/spi/config.h\"\nint spi_config_clock_div(void) { return 8; }\n" )
        write( 'test/test_uart.c', PARTIALS_DISAMBIG_PREAMBLE +
               "#include TEST_PARTIAL_PUBLIC_MODULE_AT(drivers/uart, config)\n#include MOCK_PARTIAL_PRIVATE_MODULE_AT(drivers/spi, config)\n" \
               "void setUp(void) {}\nvoid tearDown(void) {}\n" \
               "void test_baud(void) { spi_read_ExpectAndReturn(41); TEST_ASSERT_EQUAL_INT(42, uart_config_baud()); }\n" )
      end

      # An application header sharing the Partial's basename, which a tested module's header uses
      def app_config_beside(partial_macro, body)
        write( 'src/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define GAIN 3\n#endif\n" )
        write( 'include/drivers/uart/config.h', "#ifndef UART_CONFIG_H\n#define UART_CONFIG_H\nint uart_config_baud(void);\n#endif\n" )
        write( 'src/drivers/uart/config.c', "#include \"drivers/uart/config.h\"\nint uart_config_baud(void) { return 9600; }\n" )
        write( 'src/motor.h', "#ifndef MOTOR_H\n#define MOTOR_H\n#include \"config.h\"\ntypedef struct motor { int v[GAIN]; } motor_t;\nint motor_run(void);\n#endif\n" )
        write( 'src/motor.c', "#include \"motor.h\"\nint motor_run(void) { motor_t m = {{0}}; (void)m; return GAIN; }\n" )
        write( 'test/test_motor.c', PARTIALS_DISAMBIG_PREAMBLE +
               "#include TEST_PARTIAL_PUBLIC_MODULE(motor)\n#include #{partial_macro}\n" \
               "void setUp(void) {}\nvoid tearDown(void) {}\nvoid test_run(void) { TEST_ASSERT_EQUAL_INT(3, motor_run()); #{body} }\n" )
      end

      # Fallback reads an #include as written, which the compiler looks for beside the file
      # holding it before any search path
      [false, true].each do |fallback|
        it "takes a module's own header from beside its source#{' under fallback preprocessing' if fallback}" do
          in_project do
            include_paths( ['src/**'] )
            @c.merge_project_yml_for_test( { :project => { :use_partials => true }, :test_build => { :preprocess_force_fallback => fallback } } )
            write( 'src/config.h', "#ifndef APP_CONFIG_H\n#define APP_CONFIG_H\n#define GAIN 3\n#endif\n" )
            write( 'src/drivers/uart/config.h', "#ifndef UART_CONFIG_H\n#define UART_CONFIG_H\n" \
                                                "typedef struct uart_cfg { int baud; } uart_cfg_t;\nint uart_config_baud(void);\n#endif\n" )
            write( 'src/drivers/uart/uses.h', "#ifndef UART_USES_H\n#define UART_USES_H\nint uart_use(uart_cfg_t *c);\n#endif\n" )
            write( 'src/drivers/uart/config.c', "#include \"config.h\"\n#include \"uses.h\"\nint uart_use(uart_cfg_t *c) { return c->baud; }\n" \
                                                "int uart_config_baud(void) { uart_cfg_t c = { 11 }; return uart_use(&c); }\n" )
            write( 'test/test_uart.c', PARTIALS_DISAMBIG_PREAMBLE + "#include TEST_PARTIAL_PUBLIC_MODULE_AT(drivers/uart, config)\n" \
                                       "void setUp(void) {}\nvoid tearDown(void) {}\nvoid test_baud(void) { TEST_ASSERT_EQUAL_INT(11, uart_config_baud()); }\n" )

            build_passing
          end
        end
      end

      [false, true].each do |fallback|
        it "mocks a same-named module a tested Partial includes by its path#{' under fallback preprocessing' if fallback}" do
          in_project do
            include_paths( ['src/**', 'include/**'] )
            @c.merge_project_yml_for_test( { :project => { :use_partials => true }, :test_build => { :preprocess_force_fallback => fallback } } )
            same_named_configs

            build_passing
          end
        end
      end

      # A bare #include under fallback names the header the test's search paths reach first
      [false, true].each do |fallback|
        mode = fallback ? ' under fallback preprocessing' : ''

        it "keeps an application header sharing the basename of a mocked Partial#{mode}" do
          in_project do
            include_paths( ['src/**', 'include/**'] )
            @c.merge_project_yml_for_test( { :project => { :use_partials => true }, :test_build => { :preprocess_force_fallback => fallback } } )
            app_config_beside( 'MOCK_PARTIAL_PUBLIC_MODULE_AT(drivers/uart, config)',
                               'uart_config_baud_ExpectAndReturn(2); TEST_ASSERT_EQUAL_INT(2, uart_config_baud());' )

            build_passing
          end
        end

        it "keeps an application header sharing the basename of a tested Partial#{mode}" do
          in_project do
            include_paths( ['src/**', 'include/**'] )
            @c.merge_project_yml_for_test( { :project => { :use_partials => true }, :test_build => { :preprocess_force_fallback => fallback } } )
            app_config_beside( 'TEST_PARTIAL_PUBLIC_MODULE_AT(drivers/uart, config)', 'TEST_ASSERT_EQUAL_INT(9600, uart_config_baud());' )

            build_passing
          end
        end
      end

      # Fallback anchors a `..` #include to its file's own directory, which may name no file at
      # all when the compiler finds the header through a search path
      it "takes a `..` #include fallback can't anchor for a module's own header" do
        in_project do
          include_paths( ['include/**'] )
          @c.merge_project_yml_for_test( { :project => { :use_partials => true }, :test_build => { :preprocess_force_fallback => true } } )
          write( 'include/hw/port.h', "#ifndef PORT_H\n#define PORT_H\ntypedef struct port_cfg { int pin; } port_cfg_t;\nint port_open(void);\n#endif\n" )
          write( 'include/hw/sub/placeholder.h', "#ifndef PLACEHOLDER_H\n#define PLACEHOLDER_H\n#endif\n" )
          write( 'src/hw/port.c', "#include \"../port.h\"\nint port_open(void) { port_cfg_t c = { 7 }; return c.pin; }\n" )
          write( 'test/test_port.c', PARTIALS_DISAMBIG_PREAMBLE + "#include TEST_PARTIAL_PUBLIC_MODULE_AT(hw, port)\n" \
                                     "void setUp(void) {}\nvoid tearDown(void) {}\nvoid test_open(void) { TEST_ASSERT_EQUAL_INT(7, port_open()); }\n" )

          build_passing
        end
      end
    end


    # A module is a source, a header, or both. A module with only a source is named the same
    # way as any other, by its bare name or by directory.
    context "with a module that has a source and no header" do
      def write_module_and_test(name, includes, body)
        FileUtils.mkdir_p( 'src/drivers' )
        File.write( 'src/drivers/calc.c', "static int twice(int x) { return 2 * x; }\n\nint calc_quad(int x) { return twice(twice(x)); }\n" )
        File.write( "test/#{name}.c", PARTIALS_DISAMBIG_PREAMBLE + includes +
                    "\nvoid setUp(void) {}\nvoid tearDown(void) {}\nvoid test_it(void) { #{body} }\n" )
        @c.merge_project_yml_for_test( { :project => { :use_partials => true } } )
      end

      def build_passing
        output = @c.ceedling_build_exec( "test:all" )
        expect(@c.last_exit_status).to eq(0), output
        expect(output).to match(/PASSED:\s+1/)
      end

      it "builds a Partial of the module named by directory" do
        in_project do
          write_module_and_test( 'test_calc', "#include TEST_PARTIAL_MODULE_AT(drivers, calc)\nTEST_PARTIAL_CONFIG_AT(drivers, calc, twice, )\n",
                                 'TEST_ASSERT_EQUAL_INT(42, twice(21));' )
          build_passing
        end
      end

      it "mocks the module's public functions, named by directory" do
        in_project do
          write_module_and_test( 'test_calc_mock', "#include MOCK_PARTIAL_PUBLIC_MODULE_AT(drivers, calc)\n",
                                 'calc_quad_ExpectAndReturn(1, 4); TEST_ASSERT_EQUAL_INT(4, calc_quad(1));' )
          build_passing
        end
      end

      it "mocks the module's public functions, named bare" do
        in_project do
          write_module_and_test( 'test_calc_mock', "#include MOCK_PARTIAL_PUBLIC_MODULE(calc)\n",
                                 'calc_quad_ExpectAndReturn(1, 4); TEST_ASSERT_EQUAL_INT(4, calc_quad(1));' )
          build_passing
        end
      end
    end
  end
end
