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

  it 'prescribes missing-symbols guidance when the output mentions a symbol' do
    notices = prescriptions( 'undefined reference to symbol foo' )

    expect( notices.size ).to eq( 1 )
    expect( notices.first ).to match( /missing symbols/i )
  end

  it 'prescribes nothing when the output does not mention a symbol' do
    expect( prescriptions( 'some unrelated linker failure' ) ).to eq( [] )
  end

  it 'covers only linking' do
    expect( prescriptions( 'undefined reference to symbol foo', step: :compile ) ).to eq( [] )
  end

  it 'includes mock-specific guidance only when the project uses mocks' do
    expect( prescriptions( 'missing symbol foo' ).first ).not_to match( /needed mocks/i )

    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )

    expect( prescriptions( 'missing symbol foo' ).first ).to match( /needed mocks/i )
  end

  it 'logs at ERRORS as a notice' do
    prescriptions( 'missing symbol foo' )

    expect( @loginator ).to have_received( :log ).with( a_string_matching( /missing symbols/i ), Verbosity::ERRORS, LogLabels::NOTICE )
  end

  it 'opens tentatively, then gives causes, education, and options in left-justified blocks' do
    allow( @configurator ).to receive( :project_use_mocks ).and_return( true )

    notice = prescriptions( 'missing symbol foo' ).first

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
