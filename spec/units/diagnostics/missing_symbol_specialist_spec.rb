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

  it 'opens tentatively, then gives causes, education, and options in left-justified blocks' do
    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )

    notice = prescriptions( "undefined reference to `foo'" ).first

    expect( notice ).to start_with(
      "The linker output appears to report missing symbols. If so, the following may be to blame:\n" \
      "1. This test lacks #include statements corresponding to needed source files (see note below).\n"
    )
    expect( notice ).to include(
      "5. This test does not #include needed mocks (that triggers their generation).\n\n" \
      "NOTE: A test file directs the build of a test executable with #include statements:\n" \
      "• By convention, Ceedling assumes header filenames correspond to source filenames.\n",
      "\n\nOPTIONS:\n1. Doublecheck this test's #include statements.\n",
      "3. If no header file corresponds to the needed source file, use the TEST_SOURCE_FILE() build directive macro in this test to inject a source file into the build.\n"
    )
    expect( notice.lines.grep( /\A\s/ ) ).to all( eq( "\n" ) )
  end
end
