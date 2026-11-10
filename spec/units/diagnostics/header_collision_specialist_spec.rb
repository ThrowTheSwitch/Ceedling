# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/header_collision_specialist'

describe HeaderCollisionSpecialist do
  before(:each) do
    @testable = TestInvokerTypes::Testable.new( name: 'a_test', paths: {} )

    @test_substitutions = double( 'test_substitutions' )
    allow( @test_substitutions ).to receive( :real_headers ).with( @testable ).and_return( { 'gpio.h' => '/project/library/gpio.h' } )

    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    specialist = described_class.new( test_substitutions: @test_substitutions )
    nobody     = double( 'specialist', diagnoses: [] )

    @doctor = BuildStepDoctor.new(
      loginator: @loginator, header_collision_specialist: specialist,
      missing_symbol_specialist: nobody, duplicate_symbol_specialist: nobody
    ).tap( &:setup )
  end

  def prescriptions(output)
    @doctor.diagnose( step: :compile, output: output, inputs: { testable: @testable } )
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
      expect( notices.first ).to include( "'gpio.h'", "'/project/library/gpio.h'" )
    end

    {
      'GCC conflicting types'           => "/project/library/gpio.h:12:8: error: conflicting types for 'gpio_init'\n",
      'GCC previous definition'         => "/project/library/gpio.h:12:8: note: previous definition of 'gpio_init' was here\n",
      'Clang redefinition'              => "/project/library/gpio.h:8:5: error: redefinition of enumerator 'GPIO_DIR_MODE_IN'\n",
      'Clang previous definition'       => "/project/library/gpio.h:8:5: note: previous definition is here\n",
      'conflicting types with a reason' => "/project/library/gpio.h:8:5: error: conflicting types for 'gpio_init', different types\n"
    }.each do |wording, output|
      it "recognizes #{wording}" do
        expect( prescriptions( output ).size ).to eq( 1 )
      end
    end

    it 'does not match a header of the same basename at a different real path' do
      expect( prescriptions( "/some/other/place/gpio.h:12:8: error: redeclaration of 'struct gpio'\n" ) ).to eq( [] )
    end

    it 'covers only compilation' do
      output = "/project/library/gpio.h:12:8: error: redeclaration of 'struct gpio'\n"

      expect( @doctor.diagnose( step: :link, output: output, inputs: { testable: @testable } ) ).to eq( [] )
    end
  end
end
