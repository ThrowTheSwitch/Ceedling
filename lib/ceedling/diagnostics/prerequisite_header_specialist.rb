# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/reportinator'

# Explains an #error directive that guards a header against inclusion without a prerequisite.
#
# Libraries such as FreeRTOS refuse to include a header unless another header came first.
# Ceedling preprocesses a header to be mocked by itself, and a generated mock includes its
# header without the test file's #include directives. Either one can fire the guard, and the
# test file's own #include of the prerequisite reaches neither.
#
# Two settings resolve it together under mock preprocessing. A preprocessor flag lets the
# header's preprocessing see the prerequisite first, and :cmock ↳ :includes_h_pre_orig_header
# lets the generated mock include it before the header. Without mock preprocessing, the
# :cmock setting alone is enough.
class PrerequisiteHeaderSpecialist

  # An #error directive's message, in each family's wording. GCC writes `error: #error text`.
  # Clang writes `error: text` and echoes the `#error` line beneath, so only that echo tells
  # it from any other error. Clang 18 opens the echo with a line-number gutter, as in `5 |`,
  # and Apple Clang writes none. Both keep the header's path and the message by name.
  ERROR_SYMPTOMS = [
    # GCC
    /^(?<file>[^\n]+?):\d+:(?:\d+:)?[ \t]+(?:fatal )?error:[ \t]+#error\b[ \t]*(?<message>[^\n]*)/,
    # Clang
    /^(?<file>[^\n]+?):\d+:(?:\d+:)?[ \t]+(?:fatal )?error:[ \t]+(?<message>[^\n]+)\n(?:[ \t]*\d+[ \t]*\|)?[ \t]*#[ \t]*error\b/
  ].freeze

  # A header named in a message
  HEADER_NAME = /\w[\w.\/-]*\.h(?:pp)?(?!\w)/

  # A file in the chain of #include directives leading to an error
  INCLUDED_FROM = /^(?:In file included from|[ \t]+from)[ \t]+(.+?):\d+[,:]/

  REFUSAL_CAUSE = 'Some headers refuse to be included on their own. An #error directive fires unless a prerequisite header was included first.'.freeze

  MOCK_PREPROCESSING_CAUSE = 'With mock preprocessing on (:project ↳ :use_test_preprocessor), Ceedling preprocesses each header to be mocked by itself.'.freeze

  constructor :configurator

  def diagnoses()
    return [
      diagnosis( :prerequisite_header_preprocess, :preprocess, method( :examine_preprocess ) ),
      diagnosis( :prerequisite_header_compile, :compile, method( :examine_compile ) )
    ]
  end

  ### Private ###

  private

  def diagnosis(name, step, examination)
    return BuildStepDoctor::Diagnosis.new( name: name, steps: [step], symptoms: ERROR_SYMPTOMS, examination: examination )
  end

  # The expansion of a header to be mocked, whose #error is in that header or one it includes
  def examine_preprocess(kase)
    guarded = guarded_header( kase )
    return nil unless kase.inputs[:role] == :mock && reaches?( kase.output, guarded, kase.inputs[:source] )

    return preprocess_guidance( guarded, prerequisite( kase.symptoms ) )
  end

  # The compilation of a generated mock, whose #error is in a header the mock includes
  def examine_compile(kase)
    source = kase.inputs[:source]
    guarded = guarded_header( kase )
    return nil unless generated_mock?( source, kase.inputs[:testable] ) && !same_file?( guarded, source )

    return compile_guidance( guarded, source, prerequisite( kase.symptoms ) )
  end

  # The header holding the #error, with forward slashes. Clang on Windows joins a search
  # path and a header name with a backslash.
  def guarded_header(kase)
    return kase.symptoms[:file].tr( '\\', '/' )
  end

  def preprocess_guidance(guarded, prerequisite)
    header = reference( prerequisite )

    return Reportinator.generate_guidance(
      lead:    "The preprocessor output appears to report an #error directive in '#{guarded}', which may guard it against being included before #{header}.",
      causes:  [REFUSAL_CAUSE, MOCK_PREPROCESSING_CAUSE, "Neither that preprocessing nor the compilation of the generated mock sees the test file's #include directives, so including #{header} in the test doesn't help."],
      notes:   ['The build needs both options below.'],
      options: [flag_option( prerequisite ), mock_option( prerequisite )]
    )
  end

  def compile_guidance(guarded, source, prerequisite)
    header = reference( prerequisite )

    return Reportinator.generate_guidance(
      lead:    "The compiler output appears to report an #error directive in '#{guarded}' while compiling the generated mock '#{File.basename( source )}'. " \
               "The directive may guard the header against being included before #{header}.",
      causes:  [REFUSAL_CAUSE, "A generated mock includes its header directly, without the test file's #include directives."],
      notes:   ["Macros the prerequisite defines and the header's declarations use may also need listing in :cmock ↳ :strippables."],
      options: [mock_option( prerequisite )]
    )
  end

  # With no prerequisite named, an option says what to fill in
  def flag_option(prerequisite)
    return "Add `-include` and the prerequisite header's name to :flags ↳ :test ↳ :preprocess, so the header's preprocessing sees the prerequisite first." unless prerequisite

    return "Add `-include #{prerequisite}` to :flags ↳ :test ↳ :preprocess, so the header's preprocessing sees '#{prerequisite}' first."
  end

  def mock_option(prerequisite)
    header = prerequisite ? "'#{prerequisite}'" : "the prerequisite header's name"

    return "Add #{header} to :cmock ↳ :includes_h_pre_orig_header, so the generated mock includes it before the header."
  end

  # The header as a sentence names it
  def reference(prerequisite)
    return prerequisite ? "'#{prerequisite}'" : 'a prerequisite header'
  end

  # The first header the message names that isn't the guarded header itself, or nil
  def prerequisite(symptoms)
    guarded = File.basename( symptoms[:file] ).downcase
    message = symptoms[:message].to_s.strip

    return message.scan( HEADER_NAME ).find { |name| File.basename( name ).downcase != guarded }
  end

  # A source Ceedling generated for a mock: named with the mock prefix, below the test's mocks directory
  def generated_mock?(source, testable)
    mocks = testable&.paths&.dig( :mocks )
    return false if source.nil? || mocks.nil?
    return false unless File.basename( source ).start_with?( @configurator.cmock_mock_prefix )

    return File.expand_path( source ).start_with?( File.join( File.expand_path( mocks ), '' ) )
  end

  # Whether the #error is in the source or in a header the source includes
  def reaches?(output, file, source)
    return false if source.nil?

    return same_file?( file, source ) || included_from( output ).any? { |included| same_file?( included, source ) }
  end

  # The files the output's chain of #include directives names
  def included_from(output)
    return output.scan( INCLUDED_FROM ).flatten
  end

  def same_file?(path, other)
    return File.expand_path( path ) == File.expand_path( other )
  end
end
