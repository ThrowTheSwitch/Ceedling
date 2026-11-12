# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/dependencies/gcc_dependency_parser'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/header_collision_specialist'

describe HeaderCollisionSpecialist do
  before(:each) do
    @testable = TestInvokerTypes::Testable.new( name: 'a_test', paths: {} )

    @test_substitutions = double( 'test_substitutions' )
    allow( @test_substitutions ).to receive( :real_headers ).with( @testable ).and_return( { 'gpio.h' => '/project/library/gpio.h' } )
    allow( @test_substitutions ).to receive( :partialized? ).and_return( false )
    allow( @test_substitutions ).to receive( :generated_dirs ).with( @testable ).and_return( ['build/test/mocks/a_test', 'build/vendor/unity'] )

    # No .d file unless an example writes one
    @file_wrapper = double( 'file_wrapper' )
    allow( @file_wrapper ).to receive( :exist? ).and_return( false )
    allow( @file_wrapper ).to receive( :directory? ).and_return( false )

    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    @configurator = double( 'configurator' )
    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )
    allow( @configurator ).to receive( :project_use_partials ).and_return( true )

    specialist = described_class.new(
      configurator: @configurator, test_substitutions: @test_substitutions, gcc_dependency_parser: GccDependencyParser.new, file_wrapper: @file_wrapper
    )
    nobody = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: specialist,
      missing_symbol_specialist: nobody, duplicate_symbol_specialist: nobody, partial_name_specialist: nobody
    ).tap( &:setup )
  end

  def prescriptions(output, step: :compile)
    @doctor.diagnose( step: step, output: output, inputs: { testable: @testable, dependencies: 'build/deps' } )
  end

  # The first compilation attempt's .d file, listing what the test file reached
  def reached(*files)
    allow( @file_wrapper ).to receive( :exist? ).with( 'build/deps' ).and_return( true )
    allow( @file_wrapper ).to receive( :read ).with( 'build/deps' ).and_return( "build/a_test.o: test/a_test.c #{files.join( ' ' )}\n" )
  end

  describe 'a substituted header colliding with its real content' do
    it 'prescribes nothing for output with no redeclaration-family error' do
      expect( prescriptions( "/project/library/gpio.h:12:8: error: some unrelated compiler error\n" ) ).to eq( [] )
    end

    it 'prescribes nothing when the error names no header this test mocks or Partializes' do
      expect( prescriptions( "/project/library/other.h:10:5: error: redeclaration of 'struct other'\n" ) ).to eq( [] )
    end

    it 'names the substituted header and its real path when a redeclaration error mentions it' do
      notices = prescriptions( "/project/library/gpio.h:12:8: error: redeclaration of 'struct gpio'\n" )

      expect( notices.size ).to eq( 1 )
      expect( notices.first ).to start_with(
        "The compiler output appears to report a redeclaration or conflicting types in 'gpio.h'. If so, this test's " \
        "mock of 'gpio.h' may be colliding with its real content ('/project/library/gpio.h'), which can reach " \
        "this compilation through a second #include chain that bypasses the mock.\n\nHOW THIS HAPPENS:\n• A mock replaces"
      )
      expect( notices.first ).to include(
        "• Ceedling isolates the real header's direct neighbors, one level deep.",
        "\n\nOPTIONS:\n1. Trace the #include chain that brings in the real header.\n",
        "3. Change the source's #include so it reaches the header the way the test does.\n"
      )
      expect( notices.first.lines.grep( /\A\s/ ) ).to eq( ["\n", "\n"] )
    end

    it 'speaks of a Partial when the test Partializes the header' do
      allow( @test_substitutions ).to receive( :partialized? ).with( @testable, '/project/library/gpio.h' ).and_return( true )

      notice = prescriptions( "/project/library/gpio.h:12:8: error: redeclaration of 'struct gpio'\n" ).first

      expect( notice ).to include( "this test's Partial of 'gpio.h'", 'bypasses the Partial.', '• A Partial replaces a header' )
    end

    it 'names the setting a substitution remedy needs when that feature is off' do
      allow( @configurator ).to receive( :project_use_partials ).and_return( false )

      notice = prescriptions( "/project/library/gpio.h:12:8: error: redeclaration of 'struct gpio'\n" ).first

      expect( notice ).to include(
        "2. Mock or Partialize the intermediate header that #includes it, without necessarily using it, to break the chain. " \
        "Partializing requires :project ↳ :use_partials.\n"
      )
      expect( notice ).not_to include( 'Mocking requires' )
    end

    it 'finds the substituted header in an include chain line' do
      output = "In file included from /project/library/gpio.h:3,\n                 from test/a_test.c:1:\n" \
               "/project/library/pins.h:2:5: error: redefinition of 'pin'\n"

      expect( prescriptions( output ).first ).to include( "'/project/library/gpio.h'" )
    end

    {
      'GCC conflicting types'           => "/project/library/gpio.h:12:8: error: conflicting types for 'gpio_init'\n",
      'GCC previous definition'         => "/project/library/gpio.h:12:8: note: previous definition of 'gpio_init' was here\n",
      'Clang redefinition'              => "/project/library/gpio.h:8:5: error: redefinition of enumerator 'GPIO_DIR_MODE_IN'\n",
      'Clang previous definition'       => "/project/library/gpio.h:8:5: note: previous definition is here\n",
      'conflicting types with a reason' => "/project/library/gpio.h:8:5: error: conflicting types for 'gpio_init', different types\n",
      'GCC previous declaration'        => "/project/library/gpio.h:8:5: note: previous declaration of 'gpio_t' with type 'int'\n",
      'GCC different kind of symbol'    => "/project/library/gpio.h:8:5: error: 'gpio' redeclared as different kind of symbol\n",
      'Clang typedef redefinition'      => "/project/library/gpio.h:8:5: error: typedef redefinition with different types\n",
      'IAR'                             => "\"/project/library/gpio.h\",8  Error[Pe101]: \"GPIO_A\" has already been declared in the current scope\n",
      'IAR incompatible declaration'    => "\"/project/library/gpio.h\",8  Error[Pe147]: declaration is incompatible with \"int g(void)\"\n",
      'Arm armcc'                       => "\"/project/library/gpio.h\", line 8: Error:  #101: \"GPIO_A\" has already been declared in the current scope\n",
      'TI'                              => "\"/project/library/gpio.h\", line 8: error #256: invalid redeclaration of type name \"gpio_t\"\n",
      'MSVC'                            => "/project/library/gpio.h(8): error C2011: 'gpio': 'struct' type redefinition\n",
      'MSVC different basic types'      => "/project/library/gpio.h(8): error C2371: 'gpio_t': redefinition; different basic types\n",
      'other compilers, generically'    => "E 249: [\"/project/library/gpio.h\" 8] duplicate declaration of \"gpio_t\"\n"
    }.each do |wording, output|
      it "recognizes #{wording}" do
        expect( prescriptions( output ).size ).to eq( 1 )
      end
    end

    it 'does not match a header of the same basename at a different real path' do
      expect( prescriptions( "/some/other/place/gpio.h:12:8: error: redeclaration of 'struct gpio'\n" ) ).to eq( [] )
    end

    it 'covers only compilation' do
      expect( prescriptions( "/project/library/gpio.h:12:8: error: redeclaration of 'struct gpio'\n", step: :link ) ).to eq( [] )
    end
  end

  describe 'a header colliding in a directory it shares with unsubstituted headers' do
    let(:collision) do
      "In file included from test/a_test.c:3:\n" \
      "/project/include/ifx_core.h:20:16: error: conflicting types for 'ifx_t'\n" \
      "/project/include/tle9974.h:11:16: note: previous declaration of 'ifx_t' with type 'int'\n"
    end

    it 'prescribes once for the directory, naming only the headers the output names' do
      reached( '/project/include/ifx_core.h', '/project/include/tle9974.h', '/project/include/ifx_mem.h' )

      notices = prescriptions( collision )

      expect( notices.size ).to eq( 1 )
      expect( notices.first ).to start_with(
        "The compiler output appears to report a redeclaration or conflicting types involving 'ifx_core.h' and 'tle9974.h'. " \
        "If so, the cause may lie in how headers reach this compilation. Each of these headers shares the directory " \
        "'/project/include' with other headers this test's compilation reaches.\n\n"
      )
      expect( notices.first ).not_to include( 'ifx_mem.h' )
    end

    it 'gives every block of guidance, left-justified' do
      reached( '/project/include/ifx_core.h', '/project/include/tle9974.h' )

      notice = prescriptions( collision ).first

      expect( notice ).to include(
        "\n\nHOW THIS HAPPENS:\n" \
        "• One translation unit may define a type, a tag, or an enum value only once, and every declaration of a name must agree.\n",
        "• Isolation reaches only one level: a neighbor that #includes a substituted header directly. " \
        "A chain that passes through further headers or directories is beyond this isolation.\n",
        "\n\nOPTIONS:\n1. Trace the #include chains into this directory",
        "2. Mock or Partialize the header whose content should be substituted so that Ceedling isolates its neighbors.\n",
        "4. Add or fix the include guard of a header that arrives twice.\n"
      )
      expect( notice.lines.grep( /\A\s/ ) ).to eq( ["\n", "\n"] )
    end

    it 'names both settings when the project neither mocks nor Partializes' do
      allow( @configurator ).to receive( :project_use_mocks ).and_return( false )
      allow( @configurator ).to receive( :project_use_partials ).and_return( false )
      reached( '/project/include/ifx_core.h', '/project/include/tle9974.h' )

      expect( prescriptions( collision ).first ).to include(
        "neighbors. Mocking requires :project ↳ :use_mocks. Partializing requires :project ↳ :use_partials.\n"
      )
    end

    it 'prescribes once for each directory that holds a named header' do
      reached( '/project/include/a.h', '/project/include/b.h', '/project/ip/c.h', '/project/ip/d.h' )

      notices = prescriptions( "/project/include/a.h:1:1: error: redefinition of 'x'\n/project/ip/c.h:2:2: note: previous definition is here\n" )

      expect( notices.size ).to eq( 2 )
      expect( notices[0] ).to include( "involving 'a.h'.", "This header shares the directory '/project/include'" )
      expect( notices[1] ).to include( "involving 'c.h'.", "'/project/ip'" )
    end

    it 'prescribes nothing when the named header has no neighbor this test reaches' do
      reached( '/project/include/ifx_core.h', '/project/other/x.h' )

      expect( prescriptions( "/project/include/ifx_core.h:20:16: error: conflicting types for 'ifx_t'\n" ) ).to eq( [] )
    end

    it 'counts only headers among a directory\'s reached files' do
      reached( '/project/test/support/helper.c', '/project/test/support/helper.h' )

      expect( prescriptions( "/project/test/support/helper.h:3:3: error: redefinition of 'h'\n" ) ).to eq( [] )
    end

    it 'leaves a substituted header\'s directory to the substituted-header diagnosis and to isolation' do
      reached( '/project/library/gpio.h', '/project/library/driverlib.h' )

      expect( prescriptions( "/project/library/driverlib.h:4:4: error: redefinition of 'pin'\n" ) ).to eq( [] )
    end

    it 'leaves out Ceedling\'s generated directories' do
      reached(
        'build/test/mocks/a_test/mock_a.h', 'build/test/mocks/a_test/mock_b.h',
        'build/vendor/unity/src/unity.h', 'build/vendor/unity/src/unity_internals.h'
      )

      output = "build/test/mocks/a_test/mock_a.h:1:1: error: redefinition of 'x'\n" \
               "build/vendor/unity/src/unity.h:2:2: error: redefinition of 'y'\n"

      expect( prescriptions( output ) ).to eq( [] )
    end

    it 'prescribes nothing for output with no collision wording' do
      reached( '/project/include/ifx_core.h', '/project/include/tle9974.h' )

      expect( prescriptions( "/project/include/ifx_core.h:20:16: error: unknown type name 'ifx_t'\n" ) ).to eq( [] )
    end

    context 'without a .d file' do
      before(:each) do
        allow( @file_wrapper ).to receive( :directory? ).with( File.expand_path( '/project/include' ) ).and_return( true )
      end

      it 'falls back to the named header\'s own directory listing' do
        allow( @file_wrapper ).to receive( :directory_entries ).with( File.expand_path( '/project/include' ) ).and_return( ['ifx_core.h', 'notes.txt', 'tle9974.h'] )

        notices = prescriptions( "/project/include/ifx_core.h:20:16: error: redefinition of 'ifx_t'\n" )

        expect( notices.size ).to eq( 1 )
        expect( notices.first ).to include( "This header shares the directory '/project/include' with other headers.\n" )
      end

      it 'prescribes nothing when the listing holds no other header' do
        allow( @file_wrapper ).to receive( :directory_entries ).with( File.expand_path( '/project/include' ) ).and_return( ['ifx_core.h', 'ifx_core.c'] )

        expect( prescriptions( "/project/include/ifx_core.h:20:16: error: redefinition of 'ifx_t'\n" ) ).to eq( [] )
      end
    end

    it 'prescribes beside the substituted-header diagnosis when one failure shows both' do
      reached( '/project/library/gpio.h', '/project/include/a.h', '/project/include/b.h' )

      notices = prescriptions( "/project/library/gpio.h:1:1: error: redefinition of 'g'\n/project/include/a.h:2:2: note: previous definition is here\n" )

      expect( notices.size ).to eq( 2 )
      expect( notices[0] ).to include( "'/project/library/gpio.h'" )
      expect( notices[1] ).to include( "'/project/include'" )
    end
  end
end
