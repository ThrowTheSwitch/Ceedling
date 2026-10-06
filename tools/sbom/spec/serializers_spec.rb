# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for rendering the component model as CycloneDX and SPDX.
#
# Both serializers read one model and neither collects anything, so the formats cannot
# assert different facts. The final examples check exactly that, comparing the two
# documents against each other rather than against expectations written twice.
#
# Rendering goes to an IO so a spec can hand over a StringIO and read back what a file
# would have received.

require 'json'
require 'stringio'

require_relative '../cyclonedx'
require_relative '../spdx'
require_relative '../inventory'
require_relative '../submodules'

describe 'SBOM serializers' do

  let(:document) do
    Sbom::Inventory.new(
      ceedling_version: '1.2.0',
      declared: { 'rake' => '>= 12, < 14' },
      closure: { 'rake' => '13.2.1' },
      submodules: [
        Sbom::Submodules::Entry.new( path: 'vendor/unity', commit: '2b80d1a3', status: ' ' ),
        Sbom::Submodules::Entry.new( path: 'vendor/cmock/vendor/unity', commit: '2b67b99a', status: ' ' )
      ],
      header_versions: { unity: '2.7.2', cmock: '2.7.2', cexception: '1.3.5' },
      diy_version: '1.1.2',
      licenses: { '.' => 'MIT', 'vendor/unity' => 'MIT' },
      excluded_gems: ['rspec']
    ).document
  end

  # A fixed moment and identifier, so a rendered document is a function of its model
  # alone. Left live, a timestamp and a generated UUID would differ on every run.
  let(:stamp) { { timestamp: '2026-10-06T00:00:00Z', serial_number: 'urn:uuid:0000-test' } }

  def render(serializer)
    io = StringIO.new
    serializer.new( document, **stamp ).render( io )
    JSON.parse( io.string )
  end

  describe Sbom::CycloneDX do
    subject(:bom) { render( described_class ) }

    it 'declares the format and its spec version' do
      expect( bom['bomFormat'] ).to eq('CycloneDX')
      expect( bom['specVersion'] ).to be_a(String)
    end

    it 'names Ceedling as the subject of the document' do
      expect( bom.dig( 'metadata', 'component', 'purl' ) ).to eq('pkg:gem/ceedling@1.2.0')
    end

    it 'carries the scope boundaries as document properties' do
      names = bom.dig( 'metadata', 'properties' ).map { |p| p['name'] }
      expect( names ).to include('ceedling:scope', 'ceedling:plugin-tools')
    end

    it 'puts a PURL on each identified component' do
      purls = bom['components'].map { |c| c['purl'] }.compact
      expect( purls ).to include('pkg:gem/rake@13.2.1', 'pkg:github/throwtheswitch/unity@2b80d1a3')
    end

    it 'keeps a declared constraint as a component property' do
      rake = bom['components'].find { |c| c['name'] == 'rake' }
      constraint = rake['properties'].find { |p| p['name'] == 'ceedling:declared-constraint' }
      expect( constraint['value'] ).to eq('>= 12, < 14')
    end

    it 'gives every component a distinct bom-ref even where PURLs repeat' do
      refs = bom['components'].map { |c| c['bom-ref'] }
      expect( refs.uniq.size ).to eq(refs.size)
    end

    it 'expresses fff lineage as pedigree rather than as an identifier' do
      fff = bom['components'].find { |c| c['name'] == 'fake_function_framework' }

      expect( fff['purl'] ).to be_nil
      expect( fff.dig( 'pedigree', 'ancestors' ).first['purl'] )
        .to eq('pkg:github/electronvector/fake_function_framework@d3914ef0')
    end

    it 'renders a license as an SPDX identifier' do
      unity = bom['components'].find { |c| c['name'] == 'unity' && c['purl'].include?( '2b80d1a3' ) }
      expect( unity.dig( 'licenses', 0, 'license', 'id' ) ).to eq('MIT')
    end
  end

  describe Sbom::SPDX do
    subject(:doc) { render( described_class ) }

    it 'declares the SPDX version and the document data license' do
      expect( doc['spdxVersion'] ).to match(/\ASPDX-/)
      expect( doc['dataLicense'] ).to eq('CC0-1.0')
    end

    it 'gives the document a unique namespace' do
      expect( doc['documentNamespace'] ).to be_a(String)
      expect( doc['documentNamespace'] ).not_to be_empty
    end

    it 'carries a PURL for each identified package in externalRefs' do
      purls = doc['packages'].flat_map { |p| (p['externalRefs'] || []).map { |r| r['referenceLocator'] } }
      expect( purls ).to include('pkg:gem/rake@13.2.1')
    end

    it 'marks every package reference as a package-manager purl' do
      refs = doc['packages'].flat_map { |p| p['externalRefs'] || [] }
      expect( refs.map { |r| r['referenceType'] }.uniq ).to eq(['purl'])
      expect( refs.map { |r| r['referenceCategory'] }.uniq ).to eq(['PACKAGE-MANAGER'])
    end

    it 'relates each package to the document root' do
      described = doc['relationships'].select { |r| r['relationshipType'] == 'DESCRIBES' }
      expect( described.first['spdxElementId'] ).to eq('SPDXRef-DOCUMENT')
    end

    it 'expresses fff lineage as a VARIANT_OF relationship' do
      variant = doc['relationships'].find { |r| r['relationshipType'] == 'VARIANT_OF' }
      expect( variant ).not_to be_nil
    end

    it 'gives every package a distinct SPDXID' do
      ids = doc['packages'].map { |p| p['SPDXID'] }
      expect( ids.uniq.size ).to eq(ids.size)
    end

    it 'uses NOASSERTION where no license was found, rather than claiming one' do
      fff = doc['packages'].find { |p| p['name'] == 'fff' }
      expect( fff['licenseDeclared'] ).to eq('NOASSERTION')
    end
  end

  # The reason for one model and two serializers. A divergence here means one format
  # learned something the other did not.
  #
  # The comparison accounts for where each format puts lineage. CycloneDX nests an
  # ancestor inside a component's pedigree, while SPDX has no pedigree and needs a
  # package of its own to point a VARIANT_OF relationship at. Same facts, different
  # shapes, so a naive count comparison would report a difference that is not one.
  describe 'the two formats agreeing' do
    let(:cyclonedx) { render( Sbom::CycloneDX ) }
    let(:spdx) { render( Sbom::SPDX ) }

    # CycloneDX nests a contained component inside its parent, so reading only the
    # top-level array would miss whatever sits inside something else.
    def flatten_components(entries)
      entries.flat_map { |c| [c] + flatten_components( c['components'] || [] ) }
    end

    def ancestor_purls(bom)
      flatten_components( bom['components'] )
        .flat_map { |c| c.dig( 'pedigree', 'ancestors' )&.map { |a| a['purl'] } || [] }
    end

    it 'describes the same components, SPDX adding one package per ancestor' do
      components = flatten_components( cyclonedx['components'] ).size
      ancestors = ancestor_purls( cyclonedx ).size
      packages = spdx['packages'].count { |p| p['SPDXID'] != 'SPDXRef-Package-ceedling' }

      expect( packages ).to eq(components + ancestors)
    end

    it 'carries an identical set of PURLs, lineage included' do
      from_cyclonedx = ([cyclonedx.dig( 'metadata', 'component', 'purl' )] +
        flatten_components( cyclonedx['components'] ).map { |c| c['purl'] } +
        ancestor_purls( cyclonedx )).compact.sort

      from_spdx = spdx['packages']
        .flat_map { |p| (p['externalRefs'] || []).map { |r| r['referenceLocator'] } }
        .sort

      expect( from_spdx ).to eq(from_cyclonedx)
    end

    # Containment is the fact each format states its own way. Losing it in one would
    # leave that document saying less than the other about the same gem.
    it 'states containment in both, nested in one and related in the other' do
      parent = cyclonedx['components'].find { |c| c['name'] == 'fake_function_framework' }
      expect( parent['components'].map { |c| c['name'] } ).to eq(['fff'])

      contains = spdx['relationships'].select { |r| r['relationshipType'] == 'CONTAINS' }
      expect( contains.size ).to eq(1)
      expect( contains.first['spdxElementId'] ).to include('plugins-fff')
    end

    it 'does not lose the ancestor in either format' do
      ancestor = 'pkg:github/electronvector/fake_function_framework@d3914ef0'

      expect( ancestor_purls( cyclonedx ) ).to include(ancestor)
      expect( spdx['packages'].flat_map { |p| (p['externalRefs'] || []).map { |r| r['referenceLocator'] } } )
        .to include(ancestor)
    end
  end

  describe 'reproducibility' do
    it 'renders identically for the same model and stamp' do
      expect( render( Sbom::CycloneDX ) ).to eq(render( Sbom::CycloneDX ))
      expect( render( Sbom::SPDX ) ).to eq(render( Sbom::SPDX ))
    end

    # Comparing two renders inside one process is not enough. An identifier derived
    # from String#hash is stable within a process and different in the next one, so
    # the expected SPDXID is spelled out here. Two builds of one commit must agree.
    it 'names an SPDX ancestor package deterministically across processes' do
      variant = render( Sbom::SPDX )['relationships'].find { |r| r['relationshipType'] == 'VARIANT_OF' }

      expect( variant['relatedSpdxElement'] )
        .to eq('SPDXRef-Package-bundled-plugins-fff-ancestor-1')
    end

    it 'keeps the SPDX document namespace free of a URN inside its path' do
      expect( render( Sbom::SPDX )['documentNamespace'] ).not_to include('urn:uuid:')
    end
  end

end
