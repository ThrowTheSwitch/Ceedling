# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/filename_extension'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/duplicate_symbol_specialist'

describe DuplicateSymbolSpecialist do
  before(:each) do
    @configurator = double( 'configurator', cmock_mock_prefix: 'mock_', extension_object: FilenameExtension.new( '.o' ) )
    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )

    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    nobody = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: nobody, missing_symbol_specialist: nobody,
      duplicate_symbol_specialist: described_class.new( configurator: @configurator ), partial_name_specialist: nobody,
      include_depth_specialist: nobody
    ).tap( &:setup )
  end

  def prescriptions(output, objects: ['build/out/a_test.o', 'build/out/gpio.o'], step: :link)
    @doctor.diagnose( step: step, output: output, inputs: { objects: objects } )
  end

  GNU_DUPLICATE = "/usr/bin/ld: build/out/gpio.o: in function `gpio_init':\n" \
                  "gpio.c:(.text+0x0): multiple definition of `gpio_init'; build/out/a_test.o:a_test.c:(.text+0x0): first defined here\n"

  {
    'GNU ld'                     => GNU_DUPLICATE,
    'LLD'                        => "ld.lld: error: duplicate symbol: gpio_init\n>>> defined at gpio.c\n",
    'Apple ld'                   => "duplicate symbol '_gpio_init' in:\n    build/out/a_test.o\n    build/out/gpio.o\n",
    'MSVC'                       => "gpio.obj : error LNK2005: gpio_init already defined in a_test.obj\n",
    'MSVC, summarized'           => "a_test.exe : fatal error LNK1169: one or more multiply defined symbols found\n",
    'IAR ILINK'                  => "Error[Li006]: duplicate definitions for \"gpio_init\"; in \"gpio.o\", and \"a_test.o\"\n",
    'Arm armlink'                => "Error: L6200E: Symbol gpio_init multiply defined (by gpio.o and a_test.o).\n",
    'TI'                         => "error #10056: symbol \"gpio_init\" redefined: first defined in \"a_test.obj\"; redefined in \"gpio.obj\"\n",
    'other linkers, generically' => "?ASlink-Error-Multiple definition of _gpio_init\n"
  }.each do |family, output|
    it "recognizes #{family}" do
      expect( prescriptions( output ).size ).to eq( 1 )
    end
  end

  context 'without mocks' do
    before(:each) { allow( @configurator ).to receive( :project_use_mocks ).and_return( false ) }

    it 'leaves out the mock cause and option, and names the setting a mock remedy needs' do
      notice = prescriptions( GNU_DUPLICATE ).first

      expect( notice ).not_to include( '• A mock defines', "4. Don't #include both" )
      expect( notice ).to include( "or mock the source's header instead. Mocking requires :project ↳ :use_mocks.\n" )
    end
  end

  it 'prescribes nothing for a missing symbol' do
    expect( prescriptions( "undefined reference to `gpio_init'\n" ) ).to eq( [] )
  end

  it 'covers only linking' do
    expect( prescriptions( GNU_DUPLICATE, step: :compile ) ).to eq( [] )
  end

  it 'opens tentatively and gives the general causes, education, and options, left-justified' do
    notice = prescriptions( GNU_DUPLICATE ).first

    expect( notice ).to start_with( "The linker output appears to report a symbol defined more than once.\n\nHOW THIS HAPPENS:\n" )
    expect( notice ).to include(
      "• A program may define each function and each global variable only once across all its object files.\n",
      "• A definition in a header, a function body or a variable without extern, is repeated in every source that #includes the header.\n",
      "\n\nOPTIONS:\n1. Declare header variables extern, and define each one in a single source file.\n",
      "4. Don't #include both a mock and its real header in one test and don't name a mocked module's source in TEST_SOURCE_FILE().\n"
    )
    expect( notice.lines.grep( /\A\s/ ) ).to eq( ["\n", "\n"] )
  end

  context 'with a mock and the source it stands in for both linked' do
    let(:objects) { ['build/out/a_test.o', 'build/out/mock_gpio.o', 'build/out/gpio.o'] }

    it 'names the pair as the likely cause' do
      output = "/usr/bin/ld: build/out/gpio.o: in function `gpio_init':\n" \
               "multiple definition of `gpio_init'; build/out/mock_gpio.o:(.text+0x0): first defined here\n"

      expect( prescriptions( output, objects: objects ).first ).to start_with(
        "The linker output appears to report a symbol defined more than once. " \
        "This test links both 'mock_gpio.o' and 'gpio.o', which may define the same functions.\n\n"
      )
    end

    it 'names the pair from the linked objects when the output names no object' do
      output = "ld.lld: error: duplicate symbol: gpio_init\n"

      expect( prescriptions( output, objects: objects ).first ).to include( "links both 'mock_gpio.o' and 'gpio.o'" )
    end

    it 'leaves the pair out when the project does not use mocks' do
      allow( @configurator ).to receive( :project_use_mocks ).and_return( false )

      expect( prescriptions( "ld.lld: error: duplicate symbol: gpio_init\n", objects: objects ).first ).not_to include( 'links both' )
    end

    it 'leaves the pair out when the output names other objects' do
      output = "multiple definition of `helper'; build/out/a_test.o:(.text+0x0): first defined here; build/out/util.o\n"

      expect( prescriptions( output, objects: objects + ['build/out/util.o'] ).first ).not_to include( 'links both' )
    end
  end
end
