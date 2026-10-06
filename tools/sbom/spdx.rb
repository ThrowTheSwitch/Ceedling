# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'

# Renders the component model as SPDX, for consumers whose compliance processes ask for
# it specifically.
#
# SPDX expresses less natively than CycloneDX does, so two things are translated rather
# than copied. A PURL rides in `externalRefs` as a PACKAGE-MANAGER reference instead of
# being a field of its own. And lineage becomes a `VARIANT_OF` relationship to a
# separate package standing for the ancestor, since SPDX has no pedigree.
#
# Both serializers read the same model, so neither can know a fact the other does not.
module Sbom
  class SPDX

    SPDX_VERSION = 'SPDX-2.3'
    DATA_LICENSE = 'CC0-1.0'

    def initialize(document, timestamp:, serial_number:)
      @document = document
      @timestamp = timestamp
      @serial_number = serial_number
    end

    def render(io = StringIO.new)
      io.write( JSON.pretty_generate( spdx ) )
      io
    end

    private

    def spdx
      packages = [package( @document.root )] + @document.all_components.map { |c| package( c ) }
      ancestors = ancestor_packages

      {
        'spdxVersion' => SPDX_VERSION,
        'dataLicense' => DATA_LICENSE,
        'SPDXID' => 'SPDXRef-DOCUMENT',
        'name' => "ceedling-#{@document.root.version}",
        'documentNamespace' => document_namespace,
        'creationInfo' => {
          'created' => @timestamp,
          'creators' => ['Tool: ceedling-sbom', 'Organization: ThrowTheSwitch.org']
        },
        'comment' => @document.properties.map { |name, value| "#{name}: #{value}" }.join( "\n" ),
        'packages' => packages + ancestors,
        'relationships' => relationships
      }
    end

    # Derived from the caller's serial number so the namespace is as reproducible as the
    # rest of the document. SPDX requires it to be unique per document. The `urn:uuid:`
    # prefix comes off, a URN being awkward inside a URL path.
    def document_namespace
      "https://throwtheswitch.org/spdx/ceedling-#{@document.root.version}-" \
        "#{@serial_number.delete_prefix( 'urn:uuid:' )}"
    end

    # The root carries a fixed identifier rather than a derived one, being the single
    # package every DESCRIBES relationship points at.
    def spdx_id(entry)
      return 'SPDXRef-Package-ceedling' if entry.kind == 'root'

      "SPDXRef-Package-#{entry.ref}"
    end

    # NOASSERTION rather than an omission or a guess. SPDX distinguishes "no claim made"
    # from "no license", and only the first is true where nothing was read. Download
    # location and copyright are unasserted throughout: the gem is the download, and
    # copyright lives in each component's own license file.
    UNASSERTED = {
      'downloadLocation' => 'NOASSERTION',
      'filesAnalyzed' => false,
      'licenseConcluded' => 'NOASSERTION',
      'copyrightText' => 'NOASSERTION'
    }.freeze

    def package(entry)
      optional = {
        'versionInfo' => entry.version,
        'sourceInfo' => entry.path.nil? ? nil : "Vendored at #{entry.path}",
        'comment' => entry.notes,
        'externalRefs' => entry.purl.nil? ? nil : [external_ref( entry.purl )]
      }

      {
        'SPDXID' => spdx_id( entry ),
        'name' => entry.name,
        'licenseDeclared' => entry.license || 'NOASSERTION'
      }.merge( UNASSERTED ).merge( optional.compact )
    end

    def external_ref(purl)
      {
        'referenceCategory' => 'PACKAGE-MANAGER',
        'referenceType' => 'purl',
        'referenceLocator' => purl
      }
    end

    # SPDX has no pedigree, so each ancestor becomes a package of its own that the
    # modified component points at. Without this the lineage would simply be absent.
    def ancestor_packages
      lineages.flat_map do |entry, lineage|
        lineage.ancestors.each_with_index.map do |ancestor, index|
          package( ancestor )
            .merge( 'SPDXID' => ancestor_id( entry, index ) )
            .merge( lineage.notes.nil? ? {} : { 'comment' => lineage.notes } )
        end
      end
    end

    def lineages
      @document.all_components.reject { |c| c.pedigree.nil? }.map { |c| [c, c.pedigree] }
    end

    # Indexed by position rather than derived from the identifier. `String#hash` is
    # seeded per process, so hashing the PURL would give the same ancestor a different
    # SPDXID on every run and make two builds of one commit differ.
    def ancestor_id(entry, index)
      "SPDXRef-Package-#{entry.ref}-ancestor-#{index + 1}"
    end

    # Three kinds, each its own method. SPDX states as a relationship what CycloneDX
    # states structurally, so this is where the two formats diverge most.
    def relationships
      describes + contains + variants
    end

    def describes
      ([@document.root] + @document.all_components).map do |entry|
        {
          'spdxElementId' => 'SPDXRef-DOCUMENT',
          'relationshipType' => 'DESCRIBES',
          'relatedSpdxElement' => spdx_id( entry )
        }
      end
    end

    # SPDX has no nesting, so containment is a relationship. CycloneDX nests the same
    # fact inside the parent's own components array.
    def contains
      @document.all_components.flat_map do |entry|
        entry.children.map do |child|
          {
            'spdxElementId' => spdx_id( entry ),
            'relationshipType' => 'CONTAINS',
            'relatedSpdxElement' => spdx_id( child )
          }
        end
      end
    end

    def variants
      lineages.flat_map do |entry, lineage|
        lineage.ancestors.each_index.map do |index|
          {
            'spdxElementId' => spdx_id( entry ),
            'relationshipType' => 'VARIANT_OF',
            'relatedSpdxElement' => ancestor_id( entry, index )
          }
        end
      end
    end

  end
end
