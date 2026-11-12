# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'

# Explains a test file's compilation error for a name one of ceedling.h's Partials macros built.
#
# PARTIAL_LOCAL_VAR(), PARTIAL_TYPE() and PARTIAL_LOCAL_TYPE() paste their arguments into one
# identifier as the test compiles. An argument that doesn't match the module builds a name
# nothing declares, and the compiler reports only that name, not the macro's arguments.
class PartialNameSpecialist

  # Each family's wording for a name nothing declares, as a variable or as a type, ending in a
  # generic net. A false match costs a hedged note, and the examination asks for a name the
  # macros build besides.
  UNDECLARED_SYMPTOMS = [
    # GCC and Clang, Microchip XC8, XC16 and XC32, and armclang
    /undeclared|unknown type name/i,
    # MSVC
    /\bC(?:2065|2061|4430|2146)\b/,
    # EDG front ends: IAR, armcc, TI and Green Hills
    /\bPe0*20\b|#20(?!\d)|identifier\s+"[^"\n]*"\s+is\s+undefined/i,
    # SDCC, TASKING and other compilers
    /undefined identifier|not declared|unknown type|is not a type/i
  ].freeze

  # An identifier, scanned whole so each token is tested once
  IDENTIFIER = /[A-Za-z_$][\w$]*/

  # The names the macros build, and the macros themselves as a note on an expansion names them
  LOCAL_VAR = /\Apartial_[\w$]+\z/
  TYPE      = /\Aceedling_partial_[\w$]+_t\z/
  LOCAL_VAR_MACRO = 'PARTIAL_LOCAL_VAR'
  TYPE_MACROS     = ['PARTIAL_TYPE', 'PARTIAL_LOCAL_TYPE'].freeze

  # How many of a test's real names a prescription lists
  NAMES_LISTED = 12

  LOCAL_VAR_GUIDANCE = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • PARTIAL_LOCAL_VAR(function, variable) pastes its arguments into one name, partial_<function>_<variable>, as the test compiles.
    • Each argument must match the module's source exactly, case included. A misspelling builds a name nothing declares.
    • Only a variable declared static inside a function is promoted. A variable at file scope keeps its own name.
    • The macro builds a name the compiler reads. It can't take a string or a runtime value.
    • A test reaches promoted variables through a TEST_PARTIAL_*_MODULE() macro. A MOCK_PARTIAL_*_MODULE() macro provides none.

    OPTIONS:
    1. Check each argument against the function and its static variable in the module's source.
    2. Name a variable at file scope directly, without the macro.
    3. Include the module with a TEST_PARTIAL_*_MODULE() macro.%{names}
  GUIDANCE

  TYPE_GUIDANCE = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • A Partial names the type of a variable declared together with its type, as in `static struct { int count; } s_ctx;`.
    • PARTIAL_TYPE(module, variable) and PARTIAL_LOCAL_TYPE(module, function, variable) paste their arguments into that name as the test compiles.
    • The module argument is the module's name alone, without a directory. A character a C identifier can't hold is written as `_`, as in my_sensor for my-sensor.
    • Variables declared in one statement share one type, named for the first of them.
    • A variable whose type is named elsewhere, as in `static struct ctx s_ctx;`, uses that name, here `struct ctx`.

    OPTIONS:
    1. Check each argument against the module's name and its declaration, case included.
    2. Use PARTIAL_LOCAL_TYPE() for a static declared inside a function, with the function's name.
    3. Write a type named elsewhere by its own name.%{names}
  GUIDANCE

  constructor :configurator, :file_wrapper

  def diagnoses()
    return [
      BuildStepDoctor::Diagnosis.new(
        name: :partial_local_var, steps: [:compile], symptoms: UNDECLARED_SYMPTOMS, examination: method( :examine_local_var )
      ),
      BuildStepDoctor::Diagnosis.new(
        name: :partial_type, steps: [:compile], symptoms: UNDECLARED_SYMPTOMS, examination: method( :examine_type )
      )
    ]
  end

  ### Private ###

  private

  def examine_local_var(kase)
    return nil unless names?( kase, LOCAL_VAR, [LOCAL_VAR_MACRO] )

    lead = 'The compiler output appears to report a name that PARTIAL_LOCAL_VAR() builds and nothing declares. ' \
           "If so, the macro's arguments may not match a static variable inside one of the module's functions."
    return "#{lead}\n\n" + format( LOCAL_VAR_GUIDANCE, names: listed( kase, LOCAL_VAR, 'Promoted variables' ) )
  end

  def examine_type(kase)
    return nil unless names?( kase, TYPE, TYPE_MACROS )

    lead = 'The compiler output appears to report a type that PARTIAL_TYPE() or PARTIAL_LOCAL_TYPE() names and nothing declares. ' \
           "If so, the macro's arguments may not match a variable declared together with its type."
    return "#{lead}\n\n" + format( TYPE_GUIDANCE, names: listed( kase, TYPE, 'Type names' ) )
  end

  # Whether the failure is the test file's own, in a build with Partials, and names something a
  # macro builds, or the macro itself
  def names?(kase, shape, macros)
    return false unless @configurator.project_use_partials and test_file?( kase )

    return kase.output.scan( IDENTIFIER ).any? { |token| token.match?( shape ) or macros.include?( token ) }
  end

  def test_file?(kase)
    testable = kase.inputs[:testable]
    return (testable and kase.inputs[:source] == testable.filepath)
  end

  # The names of a shape this test's Partials provide, as one more option, or nothing when none
  # can be read. Generation writes them into the test's own generated headers.
  def listed(kase, shape, label)
    names = provided( kase.inputs[:testable], shape )
    return '' if names.empty?

    more = names.size > NAMES_LISTED ? ', …' : ''
    return "\n4. #{label} this test's Partials provide: #{names.first( NAMES_LISTED ).join( ', ' )}#{more}"
  end

  def provided(testable, shape)
    dir = testable.paths && testable.paths[:partials]
    return [] unless dir

    headers = @file_wrapper.directory_listing( File.join( dir, '**', '*.h' ) )
    return headers.flat_map { |header| @file_wrapper.read( header ).scan( IDENTIFIER ) }.select { |token| token.match?( shape ) }.uniq.sort
  end
end
