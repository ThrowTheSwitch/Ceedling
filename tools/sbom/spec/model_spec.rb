# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for the component model both SBOM formats serialize from.
#
# Two behaviors here carry weight. Reference keys must stay distinct for components
# that share a PURL, which happens in a real Ceedling gem. And flattening must reach
# nested components, since the cross-format consistency check counts what it returns.

require_relative '../model'

describe Sbom::Component do

  describe '#ref' do
    # CException ships twice at the same commit, once at vendor/c_exception and once
    # inside CMock. Both occurrences produce an identical PURL, so a reference keyed
    # on PURL would collide and one occurrence would vanish from the document.
    it 'distinguishes two occurrences of the same package by path' do
      shared_purl = 'pkg:github/throwtheswitch/cexception@923835236bd2'

      top = Sbom::Component.new(
        name: 'cexception', kind: 'bundled', purl: shared_purl, path: 'vendor/c_exception'
      )
      nested = Sbom::Component.new(
        name: 'cexception', kind: 'bundled', purl: shared_purl, path: 'vendor/cmock/vendor/c_exception'
      )

      expect( top.ref ).not_to eq(nested.ref)
    end

    it 'falls back to name for a fetched gem, which has no path' do
      component = Sbom::Component.new( name: 'rake', kind: 'gem', version: '13.2.1' )
      expect( component.ref ).to eq('gem-rake')
    end

    it 'reduces path separators to a reference-safe form' do
      component = Sbom::Component.new( name: 'unity', kind: 'bundled', path: 'vendor/cmock/vendor/unity' )
      expect( component.ref ).to eq('bundled-vendor-cmock-vendor-unity')
    end
  end

  describe '#to_a' do
    it 'reaches nested components' do
      inner = Sbom::Component.new( name: 'fff', kind: 'bundled', path: 'plugins/fff/vendor/fff' )
      outer = Sbom::Component.new( name: 'fff-plugin', kind: 'bundled', path: 'plugins/fff', children: [inner] )

      expect( outer.to_a.map( &:name ) ).to eq(['fff-plugin', 'fff'])
    end

    it 'returns just itself when childless' do
      component = Sbom::Component.new( name: 'rake', kind: 'gem' )
      expect( component.to_a ).to eq([component])
    end
  end

  describe 'a declared constraint beside a resolved version' do
    # The gem declares ranges. Recording only the resolved version would imply
    # Ceedling pins what it merely bounds.
    it 'carries both' do
      component = Sbom::Component.new(
        name: 'rake', kind: 'gem', version: '13.2.1', declared: '>= 12, < 14'
      )
      expect( component.version ).to eq('13.2.1')
      expect( component.declared ).to eq('>= 12, < 14')
    end
  end

end

describe Sbom::Document do

  it 'flattens nested components into one enumeration' do
    inner = Sbom::Component.new( name: 'fff', kind: 'bundled', path: 'plugins/fff/vendor/fff' )
    outer = Sbom::Component.new( name: 'fff-plugin', kind: 'bundled', path: 'plugins/fff', children: [inner] )
    gem   = Sbom::Component.new( name: 'rake', kind: 'gem', version: '13.2.1' )

    document = Sbom::Document.new(
      root: Sbom::Component.new( name: 'ceedling', kind: 'root', version: '1.2.0' ),
      components: [gem, outer]
    )

    expect( document.all_components.map( &:name ) ).to eq(['rake', 'fff-plugin', 'fff'])
  end

  it 'keeps document-level properties, which carry the scope boundaries' do
    document = Sbom::Document.new(
      root: Sbom::Component.new( name: 'ceedling', kind: 'root' ),
      components: [],
      properties: { 'ceedling:scope' => 'the gem as distributed' }
    )

    expect( document.properties['ceedling:scope'] ).to eq('the gem as distributed')
  end

end
