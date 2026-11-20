# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/diagnostics/header_collision_guidance'

describe HeaderCollisionGuidance do
  SUBSTITUTED_HEADER_TEXT = <<~TEXT.freeze
    HOW THIS HAPPENS:
    • A mock replaces a header only where an #include names it and the search paths find the substitute first.
    • A quoted #include looks in the including file's own directory before any search path, so a neighbor of the real header reaches it directly.
    • A substitute is usually a separate file with its own include guard; the guard does not keep the real header out.
    • Ceedling isolates the real header's direct neighbors, one level deep. A chain that passes through further headers or directories is beyond that isolation.

    OPTIONS:
    1. Trace the #include chain that brings in the real header.
    2. Mock or Partialize the intermediate header that #includes it, without necessarily using it, to break the chain.
    3. Change the source's #include so it reaches the header the way the test does.
  TEXT

  SHARED_DIRECTORY_TEXT = <<~TEXT.freeze
    HOW THIS HAPPENS:
    • One translation unit may define a type, a tag, or an enum value only once, and every declaration of a name must agree.
    • An include guard keeps a header out the second time only when both arrivals are the same file. Two copies of a header, or two headers that declare one name, pass every guard.
    • A quoted #include looks in the including file's own directory before any search path. A header there reaches its neighbor directly, whatever order the search paths set.
    • Ceedling isolates a header's neighbors only when the header is mocked or Partialized. No header in this directory is, so no isolation applies here.
    • Isolation reaches only one level: a neighbor that #includes a substituted header directly. A chain that passes through further headers or directories is beyond this isolation.

    OPTIONS:
    1. Trace the #include chains into this directory to the declaration that arrives twice or to the two declarations that disagree.
    2. Mock or Partialize the header whose content should be substituted so that Ceedling isolates its neighbors.
    3. Change the #include or the search path that brings in the second copy.
    4. Add or fix the include guard of a header that arrives twice.
  TEXT

  NEEDS_SETTINGS = ' Mocking requires :project ↳ :use_mocks. Partializing requires :project ↳ :use_partials.'.freeze

  it 'gives the exact text of a substituted-header collision when both features are on' do
    expect( described_class.substituted_header( substitute: 'mock', mocks: true, partials: true ) ).to eq( SUBSTITUTED_HEADER_TEXT )
  end

  it 'names a Partial as the substitute and the settings a disabled feature needs' do
    text = described_class.substituted_header( substitute: 'Partial', mocks: false, partials: false )

    expect( text ).to eq(
      SUBSTITUTED_HEADER_TEXT.sub( 'A mock replaces', 'A Partial replaces' )
                             .sub( "break the chain.\n", "break the chain.#{NEEDS_SETTINGS}\n" )
    )
  end

  it 'gives the exact text of a shared-directory collision when both features are on' do
    expect( described_class.shared_directory( mocks: true, partials: true ) ).to eq( SHARED_DIRECTORY_TEXT )
  end

  it 'names the settings a disabled feature needs in a shared-directory collision' do
    expect( described_class.shared_directory( mocks: false, partials: false ) ).to eq(
      SHARED_DIRECTORY_TEXT.sub( "neighbors.\n", "neighbors.#{NEEDS_SETTINGS}\n" )
    )
  end
end
