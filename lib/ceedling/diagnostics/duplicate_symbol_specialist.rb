# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/toolchain_output'

# Explains linker errors for symbols more than one linked object defines.
#
# Most duplicates come from C itself: a definition in a header, or a test redefining a
# function its source under test defines. One comes from Ceedling's conventions: a mock
# defines every function its header declares, so a test that links a mock beside the
# source it stands in for defines each of them twice. The pair is named when the linked
# objects hold one, among the objects the output names if it names any.
class DuplicateSymbolSpecialist

  # Each family's wording for a symbol defined twice, ending in a generic net
  DUPLICATE_SYMBOL_SYMPTOMS = [
    # GNU ld
    /multiple definition of|first defined here/i,
    # LLD and Apple ld
    /duplicate symbol/i,
    # MSVC
    /\bLNK(?:2005|1169)\b|already defined in/i,
    # IAR ILINK
    /\bLi006\b|duplicate definitions for/i,
    # Arm armlink
    /\bL6200E\b|multiply defined/i,
    # TI
    /symbol .* redefined|first defined in/i,
    # Green Hills, TASKING, SDCC, and other linkers
    /multipl(?:e|y) defin|duplicate (?:symbol|definition)|already defined/i
  ].freeze

  GUIDANCE = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • A program may define each function and each global variable only once across all its object files.
    • A definition in a header, a function body or a variable without extern, is repeated in every source that #includes the header. Since GCC 10, tentative definitions of a header variable are errors too (-fno-common).
    • A test file that defines a function the source under test also defines puts two definitions in one executable.
    • A mock defines every function its header declares, so linking a mock and the source it stands in for duplicates them.

    OPTIONS:
    1. Declare header variables extern, and define each one in a single source file.
    2. Make functions defined in headers static inline, or move their bodies into one source file.
    3. Remove a test's own definition of a function the linked source already provides, or mock the source's header instead.
    4. Don't #include both a mock and its real header in one test, and don't name a mocked module's source in TEST_SOURCE_FILE().
  GUIDANCE

  constructor :configurator

  def diagnoses()
    return [
      BuildStepDoctor::Diagnosis.new(
        name:        :duplicate_symbols,
        steps:       [:link],
        symptoms:    DUPLICATE_SYMBOL_SYMPTOMS,
        examination: method( :examine )
      )
    ]
  end

  ### Private ###

  private

  def examine(kase)
    lead = 'The linker output appears to report a symbol defined more than once.'
    pair = mock_and_source( kase.output, kase.inputs[:objects] || [] )
    lead += " This test links both '#{pair[0]}' and '#{pair[1]}', which may define the same functions." if pair

    return "#{lead}\n\n#{GUIDANCE}"
  end

  # A mock object and its source's object, by basename, or nil
  def mock_and_source(output, objects)
    return nil unless @configurator.project_use_mocks

    candidates = candidate_objects( output, objects.map { |object| File.basename( object ) } )
    prefix     = @configurator.cmock_mock_prefix

    mock = candidates.find { |object| object.start_with?( prefix ) && candidates.include?( object.delete_prefix( prefix ) ) }
    return mock && [mock, mock.delete_prefix( prefix )]
  end

  # The linked objects the output names, or every linked object when it names none
  def candidate_objects(output, linked)
    named = ToolchainOutput.objects( output, extension: @configurator.extension_object.primary ).map { |object| File.basename( object ) }
    return (named & linked).then { |both| both.empty? ? linked : both }
  end
end
