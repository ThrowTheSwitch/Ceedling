# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/missing_symbol_specialist'

describe MissingSymbolSpecialist do
  before(:each) do
    @configurator = double( 'configurator' )
    allow( @configurator ).to receive( :project_use_mocks ).and_return( false )
    allow( @configurator ).to receive( :project_use_partials ).and_return( false )
    allow( @configurator ).to receive( :project_use_test_preprocessor_tests ).and_return( false )

    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    nobody = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: nobody,
      missing_symbol_specialist: described_class.new( configurator: @configurator ), duplicate_symbol_specialist: nobody
    ).tap( &:setup )
  end

  def prescriptions(output, step: :link)
    @doctor.diagnose( step: step, output: output, inputs: {} )
  end

  it 'prescribes missing-symbols guidance for an undefined reference' do
    notices = prescriptions( "undefined reference to `foo'" )

    expect( notices.size ).to eq( 1 )
    expect( notices.first ).to match( /missing symbols/i )
  end

  it 'prescribes nothing for an unrelated linker failure' do
    expect( prescriptions( 'some unrelated linker failure' ) ).to eq( [] )
  end

  {
    'GNU ld and Microchip XC16/XC32' => "/usr/bin/ld: build/a_test.o: in function `test_f':\na_test.c:(.text+0x9): undefined reference to `gpio_init'\n",
    'LLD'                            => "ld.lld: error: undefined symbol: gpio_init\n>>> referenced by a_test.c\n",
    'Apple ld'                       => "Undefined symbols for architecture arm64:\n  \"_gpio_init\", referenced from:\nld: symbol(s) not found for architecture arm64\n",
    'MSVC'                           => "a_test.obj : error LNK2019: unresolved external symbol gpio_init referenced in function test_f\n",
    'MSVC, unreferenced by function' => "a_test.obj : error LNK2001: unresolved external symbol gpio_state\n",
    'IAR ILINK'                      => "Error[Li005]: no definition for \"gpio_init\" [referenced from a_test.o]\n",
    'Arm armlink'                    => "Error: L6218E: Undefined symbol gpio_init (referred from a_test.o).\n",
    'TI'                             => " undefined   first referenced\n  symbol         in file\n gpio_init     a_test.obj\nerror #10234-D: unresolved symbols remain\n",
    'other linkers, generically'     => "?ASlink-Warning-Undefined Global '_gpio_init' referenced by module 'a_test'\n"
  }.each do |family, output|
    it "recognizes #{family}" do
      expect( prescriptions( output ).size ).to eq( 1 )
    end
  end

  {
    'GNU ld'   => "a.o: in function `f': multiple definition of `f'; b.o:(.text+0x0): first defined here\n",
    'Apple ld' => "duplicate symbol '_f' in:\n    a.o\n    b.o\nld: 1 duplicate symbol for architecture arm64\n",
    'Arm armlink' => "Error: L6200E: Symbol f multiply defined (by a.o and b.o).\n"
  }.each do |family, output|
    it "leaves duplicate symbols reported by #{family} to their own diagnosis" do
      expect( prescriptions( output ) ).to eq( [] )
    end
  end

  it 'covers only linking' do
    expect( prescriptions( "undefined reference to `foo'", step: :compile ) ).to eq( [] )
  end

  it 'includes mock-specific guidance only when the project uses mocks' do
    expect( prescriptions( "undefined reference to `foo'" ).first ).not_to match( /needed mocks/i )

    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )

    expect( prescriptions( "undefined reference to `foo'" ).first ).to match( /needed mocks/i )
  end

  it 'logs at ERRORS as a notice' do
    prescriptions( "undefined reference to `foo'" )

    expect( @loginator ).to have_received( :log ).with( a_string_matching( /missing symbols/i ), Verbosity::ERRORS, LogLabels::NOTICE )
  end

  def notice
    prescriptions( "undefined reference to `foo'" ).first
  end

  it 'opens tentatively, then gives causes, education, and options in left-justified blocks' do
    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )

    expect( notice ).to start_with(
      "The linker output appears to report missing symbols. If so, the following may be to blame:\n" \
      "1. This test lacks #include statements corresponding to needed source files (see note below).\n"
    )
    expect( notice ).to include(
      "4. This test does not #include needed mocks (that triggers their generation).\n\n" \
      "NOTE: A test file directs the build of a test executable with #include statements:\n" \
      "• By convention, Ceedling assumes header filenames correspond to source filenames.\n",
      "\n\nOPTIONS:\n1. Doublecheck this test's #include statements.\n",
      "4. If no header file corresponds to the needed source file, use the TEST_SOURCE_FILE() build directive macro in this test to inject a source file into the build.\n",
      "5. Mock the header that declares a missing function, so the mock supplies it.\n"
    )
    expect( notice.lines.grep( /\A\s/ ) ).to all( eq( "\n" ) )
  end

  it 'no longer blames mixed C and C++ file extensions' do
    expect( notice ).not_to include( 'C++' )
  end

  context 'without test preprocessing' do
    it 'blames macros obscuring #include statements read as text, and offers to enable preprocessing' do
      expect( notice ).to include(
        "3. Complex macros, #ifdefs, etc. have obscured correct #include statements in this test.\n",
        "3. Enable test preprocessing with :project ↳ :use_test_preprocessor, so macros and #ifdefs decide which #include statements count.\n"
      )
    end
  end

  context 'with test preprocessing' do
    before(:each) { allow( @configurator ).to receive( :project_use_test_preprocessor_tests ).and_return( true ) }

    it 'blames macros as the preprocessor evaluates them, and offers no preprocessing option' do
      expect( notice ).to include( "3. Macros or #ifdefs, evaluated with this test's defines, leave out an #include statement the test needs.\n" )
      expect( notice ).not_to include( 'Enable test preprocessing' )
    end
  end

  it 'offers a mock as a remedy, naming the setting when mocks are off' do
    expect( notice ).to include( "Mock the header that declares a missing function, so the mock supplies it. Mocking requires :project ↳ :use_mocks.\n" )
  end

  context 'with Partials enabled' do
    before(:each) { allow( @configurator ).to receive( :project_use_partials ).and_return( true ) }

    it 'blames a function a Partial left out, and offers to select it' do
      expect( notice ).to include(
        "4. A Partial in this test leaves out a function the test or the Partial's code calls. A Partial carries only the functions its directive selects.\n",
        "6. Select a function a Partial left out with +name in its directive, or select the whole module with TEST_PARTIAL_ALL_MODULE.\n"
      )
    end
  end

  it 'says nothing of Partials when they are off' do
    expect( notice ).not_to include( 'Partial' )
  end
end
