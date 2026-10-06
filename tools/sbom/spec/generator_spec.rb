# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for the layer that wires collection, assembly, and rendering together.
#
# Sources is the only collaborator touching a filesystem, and it is doubled here, so
# these specs read nothing and write nothing. What they cover is the wiring itself: that
# the license guard is reached before a document is assembled, and that both formats come
# out of one generation.
#
# The guard matters most. It lives in a single call that nothing else would notice the
# absence of -- the documents would still generate, still validate, and still be wrong
# about a license.

require 'stringio'

require_relative '../generator'

describe Sbom::Generator do

  GEMSPEC_STUB = Struct.new( :version, :runtime_dependencies )
  DEPENDENCY_STUB = Struct.new( :name, :requirement )
  REQUIREMENT_STUB = Struct.new( :as_list )

  # Built from the curated license list rather than written out, so the closure is always
  # the full one the guard expects and the spec does not need editing when a dependency
  # moves. unicode-emoji is placed as a transitive of unicode-display_width, matching the
  # one indirect dependency Ceedling actually has.
  TRANSITIVE = 'unicode-emoji'

  def self.lock_stub
    gems = Sbom::GemLicenses::GEMS.transform_values { |entry| entry[:verified_for] }
    roots = gems.keys - [TRANSITIVE]

    specs = gems.sort.map do |name, version|
      line = "    #{name} (#{version})"
      line += "\n      #{TRANSITIVE} (>= 0)" if name == 'unicode-display_width'
      line
    end

    <<~TEXT
      GEM
        remote: http://rubygems.org/
        specs:
      #{specs.join( "\n" )}

      PLATFORMS
        ruby

      DEPENDENCIES
      #{roots.sort.map { |name| "  #{name}" }.join( "\n" )}

      BUNDLED WITH
         2.5.23
    TEXT
  end

  LOCK_STUB = lock_stub

  def self.root_dependencies
    (Sbom::GemLicenses::GEMS.keys - [TRANSITIVE]).sort
  end

  SUBMODULE_STUB = " 2b80d1a357271b20f15c9f2573ddab164a626132 vendor/unity (v2.7.0-20-g2b80d1a)\n"

  let(:sources) do
    instance_double(
      Sbom::Sources,
      gemspec: GEMSPEC_STUB.new(
        '1.2.0',
        self.class.root_dependencies.map do |name|
          DEPENDENCY_STUB.new( name, REQUIREMENT_STUB.new( ['>= 0'] ) )
        end
      ),
      lockfile_content: LOCK_STUB,
      submodule_status: SUBMODULE_STUB,
      header_versions: { unity: '2.7.2', cmock: '2.7.2', cexception: '1.3.5' },
      diy_version: '1.1.2',
      license_text: 'The MIT License (MIT)'
    )
  end

  subject(:generator) { described_class.new( '/nowhere', sources: sources ) }

  describe '#document' do
    it 'assembles Ceedling at the version the gemspec reports' do
      expect( generator.document.root.purl ).to eq('pkg:gem/ceedling@1.2.0')
    end

    it 'resolves the closure from the gemspec roots, transitives included' do
      names = generator.document.all_components.select { |c| c.kind == 'gem' }.map( &:name )

      expect( names ).to contain_exactly(*Sbom::GemLicenses::GEMS.keys)
    end

    it 'attaches curated licenses to gems, which carry none in the lockfile' do
      rake = generator.document.all_components.find { |c| c.name == 'rake' }

      expect( rake.license ).to eq('MIT')
    end

    # The guard's whole purpose. Without this call the documents would still generate and
    # still validate, and a license would silently be wrong.
    it 'refuses to assemble when a dependency has no recorded license' do
      # One gem added to an otherwise correct closure, which is what arriving looks like
      allow( sources ).to receive( :gemspec ).and_return(
        GEMSPEC_STUB.new(
          '1.2.0',
          (self.class.root_dependencies + ['mystery']).map do |name|
            DEPENDENCY_STUB.new( name, REQUIREMENT_STUB.new( ['>= 0'] ) )
          end
        )
      )
      allow( sources ).to receive( :lockfile_content ).and_return(
        LOCK_STUB.sub( "  specs:\n", "  specs:\n    mystery (1.0.0)\n" )
      )

      expect { generator.document }.to raise_error(Sbom::GemLicenses::Error, /mystery/)
    end
  end

  describe 'rendering both formats' do
    it 'stamps both documents from one moment, so they agree on when they were made' do
      doc = generator.document

      cyclonedx = JSON.parse( Sbom::CycloneDX.new( doc, timestamp: 'T', serial_number: 'S' ).render.string )
      spdx = JSON.parse( Sbom::SPDX.new( doc, timestamp: 'T', serial_number: 'S' ).render.string )

      expect( cyclonedx.dig( 'metadata', 'timestamp' ) ).to eq('T')
      expect( spdx.dig( 'creationInfo', 'created' ) ).to eq('T')
    end

    it 'names one file per format, each carrying the version' do
      expect( described_class::FORMATS.keys ).to contain_exactly('cdx.json', 'spdx.json')
    end
  end

end
