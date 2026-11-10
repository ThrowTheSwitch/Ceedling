# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The education and options that follow each HeaderCollisionSpecialist prescription's
# lead sentence. Each opens with how C produces the collision, then numbers the ways to
# resolve it, every line left-justified so a narrow terminal wraps it cleanly.
module HeaderCollisionGuidance
  # Follows the lead of a substituted-header prescription
  SUBSTITUTED_HEADER = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • A mock or Partial replaces a header only where an #include names it and the search paths find the substitute first.
    • A quoted #include looks in the including file's own directory before any search path, so a neighbor of the real header reaches it directly.
    • A substitute is usually a separate file with its own include guard, so the guard does not keep the real header out.
    • Ceedling isolates the real header's direct neighbors, one level deep. A chain that passes through further headers or directories is beyond that isolation.

    OPTIONS:
    1. Trace the #include chain that brings in the real header.
    2. Mock or Partialize the intermediate header that #includes it, without necessarily using it, to break the chain.
    3. Change the source's #include so it reaches the header the way the test does.
  GUIDANCE

  # Follows the lead of a shared-directory prescription
  SHARED_DIRECTORY = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • One translation unit may define a type, a tag, or an enum value only once, and every declaration of a name must agree.
    • An include guard keeps a header out the second time only when both arrivals are the same file. Two copies of a header, or two headers that declare one name, pass every guard.
    • A quoted #include looks in the including file's own directory before any search path. A header there reaches its neighbor directly, whatever order the search paths set.
    • Ceedling isolates a header's neighbors only when the header is mocked or Partialized. No header in this directory is, so no isolation applies here.
    • Isolation reaches only one level: a neighbor that #includes a substituted header directly. A chain that passes through further headers or directories is beyond it.

    OPTIONS:
    1. Trace the #include chains into this directory to the declaration that arrives twice, or to the two declarations that disagree.
    2. Mock or Partialize the header whose content should be substituted, so Ceedling isolates its neighbors.
    3. Change the #include or the search path that brings in the second copy.
    4. Add or fix the include guard of a header that arrives twice.
  GUIDANCE
end
