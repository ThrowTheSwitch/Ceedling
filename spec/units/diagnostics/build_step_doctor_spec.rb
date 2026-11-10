# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/diagnostics/build_step_doctor'

describe BuildStepDoctor do

  def specialist(*diagnoses)
    double( 'specialist', diagnoses: diagnoses )
  end

  def doctor_with(*diagnoses, others: [])
    @loginator = double( 'loginator' )
    allow( @loginator ).to receive( :log )

    described_class.new(
      loginator:                   @loginator,
      header_collision_specialist: specialist( *diagnoses ),
      missing_symbol_specialist:   specialist( *others ),
      duplicate_symbol_specialist: specialist
    )
  end

  def diagnosis(name, steps: [:compile], outcomes: [:failure], symptoms: /boom/, &examination)
    BuildStepDoctor::Diagnosis.new(
      name: name, steps: steps, outcomes: outcomes, symptoms: symptoms,
      examination: examination || ->(_case) { "#{name} prescription" }
    )
  end

  it 'logs a matching diagnosis\'s prescription at ERRORS as a notice and returns it' do
    doctor = doctor_with( diagnosis( :first ) )

    expect( doctor.diagnose( step: :compile, output: 'a boom here', inputs: {} ) ).to eq( ['first prescription'] )
    expect( @loginator ).to have_received( :log ).with( 'first prescription', Verbosity::ERRORS, LogLabels::NOTICE )
  end

  it 'examines nothing when the symptoms are absent' do
    examined = false
    doctor = doctor_with( diagnosis( :quiet ) { |_case| examined = true; 'x' } )

    expect( doctor.diagnose( step: :compile, output: 'all fine', inputs: {} ) ).to eq( [] )
    expect( examined ).to be false
    expect( @loginator ).not_to have_received( :log )
  end

  it 'examines only diagnoses for the case\'s step' do
    doctor = doctor_with( diagnosis( :compiling ), diagnosis( :linking, steps: [:link] ) )

    expect( doctor.diagnose( step: :link, output: 'boom', inputs: {} ) ).to eq( ['linking prescription'] )
  end

  it 'examines only diagnoses for the case\'s outcome' do
    doctor = doctor_with( diagnosis( :failing ), diagnosis( :warning, outcomes: [:warning] ) )

    expect( doctor.diagnose( step: :compile, outcome: :warning, output: 'boom', inputs: {} ) ).to eq( ['warning prescription'] )
  end

  it 'prescribes for every matching diagnosis, across specialists, in registration order' do
    doctor = doctor_with( diagnosis( :one ), diagnosis( :two ), others: [diagnosis( :three )] )

    expect( doctor.diagnose( step: :compile, output: 'boom', inputs: {} ) ).to eq(
      ['one prescription', 'two prescription', 'three prescription']
    )
  end

  it 'matches when any of several symptoms appears' do
    doctor = doctor_with( diagnosis( :either, symptoms: [/gcc wording/, /iar wording/] ) )

    expect( doctor.diagnose( step: :compile, output: 'Error[Pe101]: iar wording', inputs: {} ) ).to eq( ['either prescription'] )
  end

  it 'hands the examination a case holding the step, outcome, output, symptom match, and inputs' do
    seen = nil
    doctor = doctor_with( diagnosis( :curious, symptoms: /b(o+)m/ ) { |kase| seen = kase; nil } )

    doctor.diagnose( step: :compile, output: 'a boom', inputs: { source: 'a.c' } )

    expect( seen.step ).to eq( :compile )
    expect( seen.outcome ).to eq( :failure )
    expect( seen.output ).to eq( 'a boom' )
    expect( seen.symptoms[1] ).to eq( 'oo' )
    expect( seen.inputs ).to eq( { source: 'a.c' } )
  end

  it 'accepts an examination that prescribes nothing, one prescription, or several' do
    doctor = doctor_with(
      diagnosis( :none ) { |_case| nil },
      diagnosis( :one ) { |_case| 'single' },
      diagnosis( :many ) { |_case| ['first', 'second'] }
    )

    expect( doctor.diagnose( step: :compile, output: 'boom', inputs: {} ) ).to eq( ['single', 'first', 'second'] )
    expect( @loginator ).to have_received( :log ).with( anything, Verbosity::ERRORS, LogLabels::NOTICE ).exactly( 3 ).times
  end

  it 'goes on to the other diagnoses when an examination raises, logging the error at DEBUG' do
    doctor = doctor_with( diagnosis( :broken ) { |_case| raise 'examination bug' }, diagnosis( :sound ) )

    expect( doctor.diagnose( step: :compile, output: 'boom', inputs: {} ) ).to eq( ['sound prescription'] )
    expect( @loginator ).to have_received( :log ).with( a_string_including( 'broken', 'examination bug' ), Verbosity::DEBUG )
  end

  it 'refuses a diagnosis for an unknown step' do
    expect { doctor_with( diagnosis( :typo, steps: [:compiel] ) ) }.to raise_error( ::ArgumentError, /compiel/ )
  end

  it 'refuses a diagnosis for an unknown outcome' do
    expect { doctor_with( diagnosis( :typo, outcomes: [:fail] ) ) }.to raise_error( ::ArgumentError, /fail/ )
  end

  it 'refuses to diagnose an unknown step or outcome' do
    doctor = doctor_with( diagnosis( :fine ) )

    expect { doctor.diagnose( step: :linking, output: 'boom', inputs: {} ) }.to raise_error( ::ArgumentError, /linking/ )
    expect { doctor.diagnose( step: :link, outcome: :error, output: 'boom', inputs: {} ) }.to raise_error( ::ArgumentError, /error/ )
  end

  it 'treats missing output as no symptoms' do
    doctor = doctor_with( diagnosis( :any ) )

    expect( doctor.diagnose( step: :compile, output: nil, inputs: {} ) ).to eq( [] )
  end
end
