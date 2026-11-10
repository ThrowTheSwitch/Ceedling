# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/guidance_phrases'

# Explains linker errors for symbols no linked object defines.
#
# A test executable links only the sources its #include directives name by Ceedling's
# convention, plus any TEST_SOURCE_FILE() adds. A missing symbol most often means that
# convention left out a source the test needs.
class MissingSymbolSpecialist

  # Each family's wording for a symbol no object defines, ending in a generic net. A
  # duplicate symbol is left to DuplicateSymbolSpecialist, whose advice differs.
  MISSING_SYMBOL_SYMPTOMS = [
    # GNU ld, and Microchip XC16 and XC32
    /undefined reference to/i,
    # LLD, Apple ld, and Arm armlink (L6218E)
    /undefined symbol|symbol\(s\) not found|\bL6218E\b/i,
    # MSVC
    /\bLNK20(?:19|01)\b|unresolved external symbol/i,
    # IAR ILINK
    /\bLi005\b|no definition for/i,
    # TI
    /undefined\s+first referenced|unresolved symbols remain/i,
    # Green Hills, TASKING, SDCC, and other linkers
    /undefined (?:global|external)|unresolved (?:external|symbol)/i
  ].freeze

  constructor :configurator

  def diagnoses()
    return [
      BuildStepDoctor::Diagnosis.new(
        name:        :missing_symbols,
        steps:       [:link],
        symptoms:    MISSING_SYMBOL_SYMPTOMS,
        examination: ->(_case) { prescription() }
      )
    ]
  end

  ### Private ###

  private

  def prescription()
    return causes() + "\n" + note() + "\n" + options()
  end

  def causes()
    return "The linker output appears to report missing symbols. If so, the following may be to blame:\n" + numbered( [
      'This test lacks #include statements corresponding to needed source files (see note below).',
      'Project file paths omit source files corresponding to #include statements in this test.',
      macro_cause(),
      ('This test does not #include needed mocks (that triggers their generation).' if mocks?),
      ("A Partial in this test leaves out a function the test or the Partial's code calls. " \
       'A Partial carries only the functions its directive selects.' if partials?)
    ] )
  end

  # Without test preprocessing, #include statements are read as text, so a macro or
  # #ifdef can hide or invent one. With it, the preprocessor evaluates them.
  def macro_cause()
    return 'Complex macros, #ifdefs, etc. have obscured correct #include statements in this test.' unless preprocessing?

    return "Macros or #ifdefs, evaluated with this test's defines, leave out an #include statement the test needs."
  end

  def note()
    notice =  "NOTE: A test file directs the build of a test executable with #include statements:\n" \
              "• By convention, Ceedling assumes header filenames correspond to source filenames.\n" \
              "• Which code files to compile and link are determined by #include statements.\n"
    notice += "• An #include statement convention directs the generation of mocks from header files.\n" if mocks?

    return notice
  end

  def options()
    return "OPTIONS:\n" + numbered( [
      "Doublecheck this test's #include statements.",
      'Simplify complex macros or fully specify symbols for this test in :project ↳ :defines.',
      ('Enable test preprocessing with :project ↳ :use_test_preprocessor, so macros and #ifdefs decide which #include statements count.' unless preprocessing?),
      'If no header file corresponds to the needed source file, use the TEST_SOURCE_FILE() build directive macro in this test to inject a source file into the build.',
      "Mock the header that declares a missing function, so the mock supplies it.#{GuidancePhrases.requirements( mocks: mocks? )}",
      ("Select a function a Partial left out with +name in its directive, or select the whole module with TEST_PARTIAL_ALL_MODULE." if partials?)
    ] ) + "\nSee the docs on conventions, paths, preprocessing, compilation symbols, and build directive macros.\n"
  end

  # Numbers the items present, one per line
  def numbered(items)
    return items.compact.each_with_index.map { |item, index| "#{index + 1}. #{item}\n" }.join
  end

  def mocks?()
    return @configurator.project_use_mocks
  end

  def partials?()
    return @configurator.project_use_partials
  end

  def preprocessing?()
    return @configurator.project_use_test_preprocessor_tests
  end
end
