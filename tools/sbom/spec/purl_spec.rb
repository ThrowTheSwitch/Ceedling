# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for Package URL construction, the identifier every SBOM component carries.
#
# These specs live under tools/ rather than spec/ because spec/ ships inside the
# gem for certification self-tests while tools/ is excluded from it. Specs here
# would otherwise reference code absent from the packaged gem.
#
# PURL has rules that are easy to satisfy incorrectly and impossible to notice
# afterward. A github namespace must be lowercased, qualifiers must be sorted, and
# an absent version means omitting the separator rather than emitting an empty one.
# A wrong identifier still looks like an identifier, so nothing downstream complains
# -- the consumer's scanner simply matches nothing.

require_relative '../purl'

describe Sbom::Purl do

  describe '.gem' do
    it 'builds a versioned gem identifier' do
      expect( Sbom::Purl.gem( 'rake', '13.2.1' ) ).to eq('pkg:gem/rake@13.2.1')
    end

    it 'preserves name case, RubyGems names being case sensitive' do
      expect( Sbom::Purl.gem( 'Ascii85', '2.0.1' ) ).to eq('pkg:gem/Ascii85@2.0.1')
    end

    it 'keeps a hyphenated name intact' do
      expect( Sbom::Purl.gem( 'unicode-display_width', '3.2.0' ) )
        .to eq('pkg:gem/unicode-display_width@3.2.0')
    end
  end

  describe '.github' do
    it 'builds a commit-versioned identifier' do
      expect( Sbom::Purl.github( 'throwtheswitch', 'unity', '2b80d1a357271b20f15c9f2573ddab164a626132' ) )
        .to eq('pkg:github/throwtheswitch/unity@2b80d1a357271b20f15c9f2573ddab164a626132')
    end

    it 'lowercases namespace and name, which the type requires' do
      expect( Sbom::Purl.github( 'ThrowTheSwitch', 'Unity', '2b80d1a3' ) )
        .to eq('pkg:github/throwtheswitch/unity@2b80d1a3')
    end
  end

  describe 'an absent version' do
    # Nothing in the vendored fff source records which release it came from, so its
    # identifier has nothing to put after the separator. Emitting a bare trailing '@'
    # would be malformed rather than merely empty.
    it 'omits the separator entirely rather than trailing it' do
      expect( Sbom::Purl.github( 'meekrosoft', 'fff' ) ).to eq('pkg:github/meekrosoft/fff')
    end

    it 'omits the separator for a gem as well' do
      expect( Sbom::Purl.gem( 'somegem' ) ).to eq('pkg:gem/somegem')
    end
  end

  describe 'percent encoding' do
    it 'encodes a character that would otherwise delimit a component' do
      # A '?' would start the qualifier section and a '#' the subpath
      expect( Sbom::Purl.gem( 'odd', '1.0+a?b' ) ).to eq('pkg:gem/odd@1.0%2Ba%3Fb')
    end

    it 'leaves unreserved characters alone' do
      expect( Sbom::Purl.gem( 'odd', '1.0.0-pre.1_x~y' ) ).to eq('pkg:gem/odd@1.0.0-pre.1_x~y')
    end
  end

  describe 'qualifiers' do
    it 'sorts keys, since PURL defines qualifier order as canonical' do
      result = Sbom::Purl.gem( 'rake', '13.2.1', qualifiers: { repository_url: 'https://rubygems.org', arch: 'noarch' } )
      expect( result ).to eq('pkg:gem/rake@13.2.1?arch=noarch&repository_url=https%3A%2F%2Frubygems.org')
    end

    it 'drops empty and nil values rather than emitting bare keys' do
      result = Sbom::Purl.gem( 'rake', '13.2.1', qualifiers: { arch: 'noarch', empty: '', missing: nil } )
      expect( result ).to eq('pkg:gem/rake@13.2.1?arch=noarch')
    end

    it 'omits the qualifier section when nothing survives' do
      expect( Sbom::Purl.gem( 'rake', '13.2.1', qualifiers: { empty: nil } ) ).to eq('pkg:gem/rake@13.2.1')
    end
  end

  describe 'refusing to build a meaningless identifier' do
    # A silently malformed PURL is worse than a failed build. Nothing downstream
    # validates these strings, so an empty name would travel all the way into a
    # published document.
    it 'raises on an empty name' do
      expect { Sbom::Purl.gem( '', '1.0.0' ) }.to raise_error(ArgumentError, /name/)
    end

    it 'raises on an empty github namespace' do
      expect { Sbom::Purl.github( '', 'fff' ) }.to raise_error(ArgumentError, /namespace/)
    end
  end

end
