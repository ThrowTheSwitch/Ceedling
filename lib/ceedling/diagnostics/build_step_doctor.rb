# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Explains a failed build step from its output and inputs (see DOCTOR.md).
#
# Specialists teach the doctor diagnoses. A diagnosis names the steps and outcomes it
# covers, the symptoms its output must show, and an examination that decides whether
# the case is really its own. Every diagnosis that applies writes a prescription, so
# one failure can draw several. The doctor logs each one as a notice. The caller still
# raises the failure itself, so guidance never takes the place of the tool's own error.
#
# The doctor gathers its diagnoses once, in setup, and only reads them afterward. That
# is what lets every compilation thread share one doctor without a lock. Adding a
# diagnosis after setup would break it.
class BuildStepDoctor
  # Build steps a diagnosis may cover. Compilation and linking are connected. Ceedling's
  # preprocessing runs are many, and some fail by design and fall back, so none is
  # connected yet.
  STEPS    = [:preprocess, :compile, :link].freeze
  OUTCOMES = [:failure, :warning].freeze

  # What a specialist teaches the doctor. `symptoms` is a Regexp, or several, any of
  # which marks the case as a candidate. `examination` takes a Case and returns a
  # prescription, several, or nil when the case is not this diagnosis's after all.
  # `verbosity` is the level its prescriptions log at.
  Diagnosis = Struct.new( :name, :steps, :outcomes, :symptoms, :verbosity, :examination, keyword_init: true ) do
    def initialize(outcomes: [:failure], verbosity: Verbosity::ERRORS, **fields)
      super
    end

    # The first symptom match, or nil
    def symptom_in(output)
      Array( symptoms ).each do |symptom|
        match = symptom.match( output )
        return match if match
      end
      nil
    end
  end

  # One failure as the doctor sees it. `symptoms` is the diagnosis's MatchData, and
  # `inputs` holds whatever the step ran with, such as its tool, source, and search paths.
  Case = Struct.new( :step, :outcome, :output, :symptoms, :inputs, keyword_init: true )

  constructor :loginator, :header_collision_specialist, :missing_symbol_specialist, :duplicate_symbol_specialist

  def setup()
    specialists = [@header_collision_specialist, @missing_symbol_specialist, @duplicate_symbol_specialist]

    @diagnoses = specialists.flat_map( &:diagnoses ).freeze
    @diagnoses.each { |diagnosis| check_scope( diagnosis.steps, diagnosis.outcomes, diagnosis.name ) }
  end

  # Logs every prescription the case draws, and returns them
  def diagnose(step:, output:, inputs:, outcome: :failure)
    check_scope( [step], [outcome], 'diagnosis request' )
    return [] if output.nil?

    return @diagnoses.flat_map do |diagnosis|
      next [] unless diagnosis.steps.include?( step ) && diagnosis.outcomes.include?( outcome )

      prescriptions = examine( diagnosis, output: output, step: step, outcome: outcome, inputs: inputs )
      prescriptions.each { |prescription| @loginator.log( prescription, diagnosis.verbosity, LogLabels::NOTICE ) }
    end
  end

  ### Private ###

  private

  # An examination that raises is a bug in guidance, never a reason to hide the build's
  # real failure. It is noted for debugging, and the other diagnoses still run.
  def examine(diagnosis, output:, **case_fields)
    match = diagnosis.symptom_in( output )
    return [] if match.nil?

    return Array( diagnosis.examination.call( Case.new( output: output, symptoms: match, **case_fields ) ) ).compact
  rescue StandardError => e
    @loginator.log( "Diagnosis #{diagnosis.name} failed to examine its case: #{e.class}: #{e.message}", Verbosity::DEBUG )
    return []
  end

  def check_scope(steps, outcomes, name)
    unknown = (steps - STEPS) + (outcomes - OUTCOMES)
    return if unknown.empty?

    raise ::ArgumentError, "#{name} names unknown build steps or outcomes: #{unknown.join( ', ' )}"
  end
end
