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
require 'ceedling/filesystem/file_wrapper'
require 'ceedling/dependencies/gcc_dependency_parser'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_substitutions'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/header_collision_specialist'
require 'ceedling/diagnostics/missing_symbol_specialist'
require 'ceedling/diagnostics/duplicate_symbol_specialist'

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

    loginator    = double( 'loginator' )
    verbosinator = double( 'verbosinator', should_output?: false )
    allow( loginator ).to receive( :log )
    @logged = []
    allow( loginator ).to receive( :log ).with( anything, Verbosity::ERRORS, LogLabels::NOTICE ) { |msg, *_| @logged << msg }

    configurator = double( 'configurator', project_build_vendor_ceedling_path: 'build/vendor/ceedling', project_use_mocks: true )
    allow( configurator ).to receive( :extension_object ).and_return( '.o' )

    file_wrapper  = FileWrapper.new( loginator: loginator, verbosinator: verbosinator )
    substitutions = TestSubstitutions.new( configurator: configurator )

    @doctor = BuildStepDoctor.new(
      loginator:                   loginator,
      header_collision_specialist: HeaderCollisionSpecialist.new(
        test_substitutions: substitutions, gcc_dependency_parser: GccDependencyParser.new, file_wrapper: file_wrapper
      ),
      missing_symbol_specialist:   MissingSymbolSpecialist.new( configurator: configurator ),
      duplicate_symbol_specialist: DuplicateSymbolSpecialist.new
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
        write( 'mocks/mock_gpio.h', "struct gpio { int pin; };\n" )
        write( 'library/driverlib.h', "#include \"gpio.h\"\n" )
        source = write( 'test/a_test.c', "#include \"mock_gpio.h\"\n#include \"driverlib.h\"\n" )

        @testable.mocks = { gpio: TestInvokerTypes::MockDetails.new( name: 'gpio', source: gpio, partial: false ) }

        diagnose_compile( *compile_failing( compiler, source, includes: ['mocks', 'library'] ) )

        expect( @logged ).to include( a_string_including( "'gpio.h'", "'#{gpio}'" ) )
        expect( @logged ).not_to include( a_string_including( 'shares the directory' ) )
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
end
