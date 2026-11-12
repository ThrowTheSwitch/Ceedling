# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for the build step doctor against a real compiler's output.
#
# A diagnosis rests on two facts no double can supply: the words a real toolchain uses
# for an error, and the paths its output and its .d file name. Each case here compiles
# real C in a temporary directory, then hands the real output and .d file to the real
# doctor and specialists. The unit specs under spec/units/diagnostics/ own everything
# observable from fixed strings.

require 'spec_helper'
require 'spec_integration_helper'
require 'fileutils'
require 'tmpdir'
require 'open3'
require 'ceedling/constants'
require 'ceedling/filename_extension'
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/dependencies/gcc_dependency_parser'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_substitutions'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/header_collision_specialist'
require 'ceedling/diagnostics/missing_symbol_specialist'
require 'ceedling/diagnostics/duplicate_symbol_specialist'
require 'ceedling/diagnostics/partial_name_specialist'

PROJECT_BUILD_VENDOR_UNITY_PATH      = 'build/vendor/unity'      unless defined?( PROJECT_BUILD_VENDOR_UNITY_PATH )
PROJECT_BUILD_VENDOR_CMOCK_PATH      = 'build/vendor/cmock'      unless defined?( PROJECT_BUILD_VENDOR_CMOCK_PATH )
PROJECT_BUILD_VENDOR_CEXCEPTION_PATH = 'build/vendor/cexception' unless defined?( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH )

describe 'BuildStepDoctor (integration)' do
  def self.compiler_available?(compiler)
    Open3.capture2e( compiler, '--version' )[1].success?
  rescue StandardError
    false
  end

  before(:each) do
    @root = Dir.mktmpdir

    loginator    = @loginator = double( 'loginator' )
    verbosinator = double( 'verbosinator', should_output?: false )
    allow( loginator ).to receive( :log )
    @logged = []
    allow( loginator ).to receive( :log ).with( anything, Verbosity::ERRORS, LogLabels::NOTICE ) { |msg, *_| @logged << msg }

    configurator = double(
      'configurator',
      project_build_vendor_ceedling_path: 'build/vendor/ceedling', project_use_mocks: true,
      project_use_partials: false, project_use_test_preprocessor_tests: true,
      cmock_mock_prefix: 'mock_', extension_object: FilenameExtension.new( '.o' )
    )

    file_wrapper  = FileWrapper.new( loginator: loginator, verbosinator: verbosinator )
    substitutions = TestSubstitutions.new( configurator: configurator )

    @doctor = BuildStepDoctor.new(
      loginator:                   loginator,
      header_collision_specialist: HeaderCollisionSpecialist.new(
        configurator: configurator, test_substitutions: substitutions, gcc_dependency_parser: GccDependencyParser.new, file_wrapper: file_wrapper
      ),
      missing_symbol_specialist:   MissingSymbolSpecialist.new( configurator: configurator ),
      duplicate_symbol_specialist: DuplicateSymbolSpecialist.new( configurator: configurator ),
      partial_name_specialist:     PartialNameSpecialist.new( configurator: configurator, file_wrapper: file_wrapper )
    ).tap( &:setup )

    @testable = TestInvokerTypes::Testable.new( name: 'a_test', paths: { build: File.join( @root, 'build' ) } )
  end

  after(:each) do
    FileUtils.rm_rf( @root )
  end

  def write(relative, text)
    path = File.join( @root, relative )
    FileUtils.mkdir_p( File.dirname( path ) )
    File.write( path, text )
    path
  end

  # Compiles `source` with `-MMD`, as Ceedling's default test compiler does, and returns
  # the output of a compilation that must fail
  def compile_failing(compiler, source, includes:)
    deps   = File.join( @root, 'a_test.d' )
    args   = includes.map { |dir| "-I#{File.join( @root, dir )}" }
    output, status = Open3.capture2e( compiler, *args, '-MMD', '-MF', deps, '-c', source, '-o', File.join( @root, 'a_test.o' ) )

    expect( status.success? ).to be( false ), "expected #{compiler} to fail on #{source}, but it compiled:\n#{output}"
    [output, deps]
  end

  # Compiles each source to an object, then links them, returning the output of a link
  # that must fail and the objects it linked
  def link_failing(compiler, *sources)
    objects = sources.map do |source|
      object = source.sub( /\.c\z/, '.o' )
      output, status = Open3.capture2e( compiler, '-c', source, '-o', object )
      expect( status.success? ).to be( true ), "#{compiler} failed to compile #{source}:\n#{output}"
      object
    end

    output, status = Open3.capture2e( compiler, *objects, '-o', File.join( @root, 'a_test.out' ) )
    expect( status.success? ).to be( false ), "expected #{compiler} to fail linking, but it linked:\n#{output}"
    [output, objects]
  end

  def diagnose_link(output, objects)
    @doctor.diagnose( step: :link, output: output, inputs: { testable: @testable, objects: objects } )
  end

  def diagnose_compile(output, deps)
    @doctor.diagnose( step: :compile, output: output, inputs: { testable: @testable, dependencies: deps } )
  end

  %w[gcc clang].each do |compiler|
    context "compiling with #{compiler}" do
      before(:each) do
        skip "#{compiler} is not installed or not in PATH" unless self.class.compiler_available?( compiler )
      end

      it 'explains two neighboring headers that define one struct' do
        write( 'include/a.h', "struct shared { int a; };\n" )
        write( 'include/b.h', "struct shared { int b; };\n" )
        write( 'include/c.h', "int unrelated;\n" )
        source = write( 'test/a_test.c', "#include \"a.h\"\n#include \"b.h\"\n#include \"c.h\"\n" )

        diagnose_compile( *compile_failing( compiler, source, includes: ['include'] ) )

        expect( @logged.size ).to eq( 1 )
        expect( @logged.first ).to include( "involving 'b.h' and 'a.h'.", "the directory '#{File.join( @root, 'include' )}'" )
        expect( @logged.first ).not_to include( 'c.h' )
      end

      it 'explains a mocked header whose real content also reaches the compilation' do
        gpio = write( 'library/gpio.h', "struct gpio { int pin; };\n" )
        # The definitions differ, since C23 lets an identical struct be redefined
        write( 'mocks/mock_gpio.h', "struct gpio { int line; };\n" )
        write( 'library/driverlib.h', "#include \"gpio.h\"\n" )
        source = write( 'test/a_test.c', "#include \"mock_gpio.h\"\n#include \"driverlib.h\"\n" )

        @testable.mocks = { gpio: TestInvokerTypes::MockDetails.new( name: 'gpio', source: gpio, partial: false ) }

        diagnose_compile( *compile_failing( compiler, source, includes: ['mocks', 'library'] ) )

        expect( @logged ).to include( a_string_including( "'gpio.h'", "'#{gpio}'" ) )
        expect( @logged ).not_to include( a_string_including( 'shares the directory' ) )
      end

      it 'explains a symbol no linked object defines' do
        test = write( 'build/a_test.c', "int gpio_init(void);\nint main(void) { return gpio_init(); }\n" )

        diagnose_link( *link_failing( compiler, test ) )

        expect( @logged.size ).to eq( 1 )
        expect( @logged.first ).to start_with( 'The linker output appears to report missing symbols.' )
      end

      it 'gives no missing-symbols guidance for a symbol defined twice' do
        test  = write( 'build/a_test.c', "int gpio_init(void) { return 0; }\nint main(void) { return gpio_init(); }\n" )
        other = write( 'build/gpio.c', "int gpio_init(void) { return 1; }\n" )

        diagnose_link( *link_failing( compiler, test, other ) )

        expect( @logged ).not_to include( a_string_including( 'missing symbols' ) )
        expect( @logged.size ).to eq( 1 )
        expect( @logged.first ).to start_with( 'The linker output appears to report a symbol defined more than once.' )
        expect( @logged.first ).not_to include( 'links both' )
      end

      it 'names a mock linked beside the source it stands in for' do
        test   = write( 'build/a_test.c', "int gpio_init(void);\nint main(void) { return gpio_init(); }\n" )
        mock   = write( 'build/mock_gpio.c', "int gpio_init(void) { return 0; }\n" )
        source = write( 'build/gpio.c', "int gpio_init(void) { return 1; }\n" )

        diagnose_link( *link_failing( compiler, test, mock, source ) )

        expect( @logged.size ).to eq( 1 )
        expect( @logged.first ).to include( "This test links both 'mock_gpio.o' and 'gpio.o'" )
      end

      it 'prescribes nothing for an error that is no collision' do
        write( 'include/a.h', "int a;\n" )
        write( 'include/b.h', "int b;\n" )
        source = write( 'test/a_test.c', "#include \"a.h\"\n#include \"b.h\"\nint f(void) { return undeclared; }\n" )

        diagnose_compile( *compile_failing( compiler, source, includes: ['include'] ) )

        expect( @logged ).to eq( [] )
      end
    end
  end

  # A test file whose Partials macro builds a name nothing declares, compiled against the real
  # ceedling.h. The compiler reports the built name, which the specialist recognizes.
  context "a Partials macro naming nothing, with Partials enabled" do
    before(:each) do
      configurator = double( 'configurator', project_use_partials: true )
      nobody       = double( 'specialist', diagnoses: [] )
      file_wrapper = FileWrapper.new( loginator: double( 'loginator' ).as_null_object, verbosinator: double( 'verbosinator', should_output?: false ) )

      @doctor = BuildStepDoctor.new(
        loginator: @loginator, header_collision_specialist: nobody, missing_symbol_specialist: nobody,
        duplicate_symbol_specialist: nobody, partial_name_specialist: PartialNameSpecialist.new( configurator: configurator, file_wrapper: file_wrapper )
      ).tap( &:setup )
    end

    def compile_test(compiler, body)
      source = write( 'test/a_test.c', "#include \"ceedling.h\"\n#{body}" )
      output, status = Open3.capture2e(
        compiler, "-I#{File.expand_path( '../../lib/ceedling', __dir__ )}", '-DCEEDLING_PARTIALS_PREFIX=ceedling_partial_', '-c', source, '-o', File.join( @root, 'a_test.o' )
      )
      expect( status.success? ).to be( false ), "expected #{compiler} to fail on #{source}, but it compiled:\n#{output}"

      @doctor.diagnose( step: :compile, output: output, inputs: { testable: @testable, source: source } )
    end

    before(:each) { @testable = TestInvokerTypes::Testable.new( name: 'a_test', filepath: File.join( @root, 'test', 'a_test.c' ), paths: {} ) }

    %w[gcc clang].each do |compiler|
      context "compiling with #{compiler}" do
        before(:each) do
          skip "#{compiler} is not installed or not in PATH" unless self.class.compiler_available?( compiler )
        end

        it 'explains a promoted variable PARTIAL_LOCAL_VAR() misspells' do
          compile_test( compiler, "int f(void) { return PARTIAL_LOCAL_VAR(tick, cnt); }\n" )

          expect( @logged.size ).to eq( 1 )
          expect( @logged.first ).to include( 'PARTIAL_LOCAL_VAR() builds' )
        end

        it 'explains a type PARTIAL_TYPE() misspells' do
          compile_test( compiler, "int f(void) { PARTIAL_TYPE(ticker, ctx) copy; return sizeof( copy ); }\n" )

          expect( @logged.size ).to eq( 1 )
          expect( @logged.first ).to include( 'PARTIAL_TYPE() or PARTIAL_LOCAL_TYPE() names' )
        end

        it 'prescribes nothing for an ordinary undeclared name' do
          compile_test( compiler, "int f(void) { return undeclared; }\n" )

          expect( @logged ).to eq( [] )
        end
      end
    end
  end
end
