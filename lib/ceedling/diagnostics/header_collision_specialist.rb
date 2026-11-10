# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'

# Explains compiler errors where one translation unit declares a name twice or two ways.
#
# A mock or Partial substitutes a header only through the #include directives a test
# names and the order of its search paths. A header's real content can still reach a
# compilation another way, and its declarations then collide with the substitute's (see
# HEADER_COLLISIONS.md). Compilers word the collision differently. GCC reports
# "conflicting types for" and "previous definition of". Clang reports "redefinition of"
# and "previous definition is here". Each is a real wording for the same error.
class HeaderCollisionSpecialist

  COLLISION_SYMPTOMS = /redeclaration of|redefinition of|conflicting types|previous definition/i

  # A header path in a GCC or Clang diagnostic location, `path.h:line:column`
  HEADER_LOCATION = /([^\s"]+\.h):\d+:\d+/

  constructor :test_substitutions

  def diagnoses()
    return [
      BuildStepDoctor::Diagnosis.new(
        name:        :substituted_header_collision,
        steps:       [:compile],
        symptoms:    COLLISION_SYMPTOMS,
        examination: method( :examine_substituted_header )
      )
    ]
  end

  ### Private ###

  private

  # A header the output names that is also one the test substitutes means the real
  # header's content reached the compilation beside its substitute
  def examine_substituted_header(kase)
    mentioned = kase.output.scan( HEADER_LOCATION ).flatten.uniq

    culprit = @test_substitutions.real_headers( kase.inputs[:testable] ).find do |basename, real_path|
      mentioned.any? { |m| File.basename( m ) == basename && File.expand_path( m ) == File.expand_path( real_path ) }
    end
    return nil if culprit.nil?

    return substituted_header_prescription( *culprit )
  end

  def substituted_header_prescription(basename, real_path)
    notice  = "This looks like '#{basename}' is mocked or Partialized for this test, but its " \
              "real content ('#{real_path}') is also reaching compilation through a second " \
              "unmocked #include chain.\n"
    notice += "> The cause is most likely a transitive #include chain through an unrelated " \
              "header brought about by C convention quirks in search paths and #include guards.\n"
    notice += "> Consider investigating the #include chain and modifying your source or " \
              "Partializing/mocking the problematic header (without necessarily using it) to " \
              "break the transitive #include chain.\n"

    return notice
  end
end
