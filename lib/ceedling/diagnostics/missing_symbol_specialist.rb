# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'

# Explains linker errors for symbols no linked object defines.
#
# A test executable links only the sources its #include directives name by Ceedling's
# convention, plus any TEST_SOURCE_FILE() adds. A missing symbol most often means that
# convention left out a source the test needs.
class MissingSymbolSpecialist

  MISSING_SYMBOL_SYMPTOMS = /symbol/i

  constructor :configurator

  def diagnoses()
    return [
      BuildStepDoctor::Diagnosis.new(
        name:        :missing_symbols,
        steps:       [:link],
        symptoms:    MISSING_SYMBOL_SYMPTOMS,
        examination: ->(_case) { prescription( mocks: @configurator.project_use_mocks ) }
      )
    ]
  end

  ### Private ###

  private

  def prescription(mocks:)
    return causes( mocks ) + "\n" + note( mocks ) + "\n" + options()
  end

  def causes(mocks)
    notice =  "The linker output appears to report missing symbols. If so, the following may be to blame:\n" \
              "1. This test lacks #include statements corresponding to needed source files (see note below).\n" \
              "2. Project file paths omit source files corresponding to #include statements in this test.\n" \
              "3. Complex macros, #ifdefs, etc. have obscured correct #include statements in this test.\n" \
              "4. Your project is attempting to mix C++ and C file extensions (not supported).\n"
    notice += "5. This test does not #include needed mocks (that triggers their generation).\n" if mocks

    return notice
  end

  def note(mocks)
    notice =  "NOTE: A test file directs the build of a test executable with #include statements:\n" \
              "• By convention, Ceedling assumes header filenames correspond to source filenames.\n" \
              "• Which code files to compile and link are determined by #include statements.\n"
    notice += "• An #include statement convention directs the generation of mocks from header files.\n" if mocks

    return notice
  end

  def options()
    return "OPTIONS:\n" \
           "1. Doublecheck this test's #include statements.\n" \
           "2. Simplify complex macros or fully specify symbols for this test in :project ↳ :defines.\n" \
           "3. If no header file corresponds to the needed source file, use the TEST_SOURCE_FILE() " \
           "build directive macro in this test to inject a source file into the build.\n" \
           "\n" \
           "See the docs on conventions, paths, preprocessing, compilation symbols, and build directive macros.\n"
  end
end
