# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/reportinator'
require 'ceedling/diagnostics/guidance_phrases'

# The education and options that follow each HeaderCollisionSpecialist prescription's
# lead sentence. Each opens with how C produces the collision, then numbers the ways to
# resolve it. Reportinator.generate_guidance lays the text out. A remedy that mocks or
# Partializes a header names the setting a disabled feature needs.
module HeaderCollisionGuidance

  # The causes after the first of a substituted-header collision, which names the substitute
  SUBSTITUTED_HEADER_CAUSES = [
    "A quoted #include looks in the including file's own directory before any search path, so a neighbor of the real header reaches it directly.",
    'A substitute is usually a separate file with its own include guard; the guard does not keep the real header out.',
    "Ceedling isolates the real header's direct neighbors, one level deep. A chain that passes through further headers or directories is beyond that isolation."
  ].freeze

  # The options around the second, which the project's features word
  SUBSTITUTED_HEADER_OPTIONS = [
    'Trace the #include chain that brings in the real header.',
    "Change the source's #include so it reaches the header the way the test does."
  ].freeze

  SHARED_DIRECTORY_CAUSES = [
    'One translation unit may define a type, a tag, or an enum value only once, and every declaration of a name must agree.',
    'An include guard keeps a header out the second time only when both arrivals are the same file. Two copies of a header, or two headers that declare one name, pass every guard.',
    "A quoted #include looks in the including file's own directory before any search path. A header there reaches its neighbor directly, whatever order the search paths set.",
    "Ceedling isolates a header's neighbors only when the header is mocked or Partialized. No header in this directory is, so no isolation applies here.",
    'Isolation reaches only one level: a neighbor that #includes a substituted header directly. A chain that passes through further headers or directories is beyond this isolation.'
  ].freeze

  # The options around the second, which the project's features word
  SHARED_DIRECTORY_OPTIONS = [
    'Trace the #include chains into this directory to the declaration that arrives twice or to the two declarations that disagree.',
    'Change the #include or the search path that brings in the second copy.',
    'Add or fix the include guard of a header that arrives twice.'
  ].freeze

  # `substitute` is 'mock' or 'Partial', whichever this test made of the header
  def self.substituted_header(substitute:, mocks:, partials:)
    remedy = 'the intermediate header that #includes it, without necessarily using it, to break the chain.'
    first, last = SUBSTITUTED_HEADER_OPTIONS

    return Reportinator.generate_guidance(
      causes:  ["A #{substitute} replaces a header only where an #include names it and the search paths find the substitute first.", *SUBSTITUTED_HEADER_CAUSES],
      options: [first, GuidancePhrases.substitute( remedy, mocks: mocks, partials: partials ), last]
    )
  end

  def self.shared_directory(mocks:, partials:)
    remedy = 'the header whose content should be substituted so that Ceedling isolates its neighbors.'
    first, *rest = SHARED_DIRECTORY_OPTIONS

    return Reportinator.generate_guidance(
      causes:  SHARED_DIRECTORY_CAUSES,
      options: [first, GuidancePhrases.substitute( remedy, mocks: mocks, partials: partials ), *rest]
    )
  end
end
