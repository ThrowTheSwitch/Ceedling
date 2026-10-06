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
        # Derived from the caller's serial number so the namespace is as reproducible as
        # the rest of the document. SPDX requires it to be unique per document. The
        # `urn:uuid:` prefix is stripped, a URN being awkward inside a URL path.
        'documentNamespace' =>
          "https://throwtheswitch.org/spdx/ceedling-#{@document.root.version}-" \
          "#{@serial_number.sub( /\Aurn:uuid:/, '' )}",
        'creationInfo' => {
          'created' => @timestamp,
          'creators' => ['Tool: ceedling-sbom', 'Organization: ThrowTheSwitch.org']
        },
        'comment' => @document.properties.map { |name, value| "#{name}: #{value}" }.join( "\n" ),
        'packages' => packages + ancestors,
        'relationships' => relationships( ancestors )
      }
    end

    def spdx_id(entry)
      "SPDXRef-Package-#{entry.ref}"
    end

    def package(entry)
      result = {
        'SPDXID' => entry.kind == 'root' ? 'SPDXRef-Package-ceedling' : spdx_id( entry ),
        'name' => entry.name,
        'downloadLocation' => 'NOASSERTION',
        'filesAnalyzed' => false,
        # NOASSERTION rather than an omission or a guess. SPDX distinguishes "no claim
        # made" from "no license", and only the first is true where no file was found.
        'licenseConcluded' => 'NOASSERTION',
        'licenseDeclared' => entry.license || 'NOASSERTION',
        'copyrightText' => 'NOASSERTION'
      }

      result['versionInfo'] = entry.version unless entry.version.nil?
      result['sourceInfo'] = "Vendored at #{entry.path}" unless entry.path.nil?
      result['comment'] = entry.notes unless entry.notes.nil?
      result['externalRefs'] = [external_ref( entry.purl )] unless entry.purl.nil?

      result
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
        lineage.ancestors.map do |purl|
          {
            'SPDXID' => ancestor_id( entry, purl ),
            'name' => "#{entry.name}-ancestor",
            'downloadLocation' => 'NOASSERTION',
            'filesAnalyzed' => false,
            'licenseConcluded' => 'NOASSERTION',
            'licenseDeclared' => 'NOASSERTION',
            'copyrightText' => 'NOASSERTION',
            'comment' => lineage.notes,
            'externalRefs' => [external_ref( purl )]
          }.compact
        end
      end
    end

    def lineages
      @document.all_components.reject { |c| c.pedigree.nil? }.map { |c| [c, c.pedigree] }
    end

    # Indexed by position rather than derived from the identifier. `String#hash` is
    # seeded per process, so hashing the PURL would give the same ancestor a different
    # SPDXID on every run and make two builds of one commit differ.
    def ancestor_id(entry, purl)
      index = entry.pedigree.ancestors.index( purl )
      "SPDXRef-Package-#{entry.ref}-ancestor-#{index + 1}"
    end

    def relationships(ancestors)
      describes = ([@document.root] + @document.all_components).map do |entry|
        {
          'spdxElementId' => 'SPDXRef-DOCUMENT',
          'relationshipType' => 'DESCRIBES',
          'relatedSpdxElement' => entry.kind == 'root' ? 'SPDXRef-Package-ceedling' : spdx_id( entry )
        }
      end

      variants = lineages.flat_map do |entry, lineage|
        lineage.ancestors.map do |purl|
          {
            'spdxElementId' => spdx_id( entry ),
            'relationshipType' => 'VARIANT_OF',
            'relatedSpdxElement' => ancestor_id( entry, purl )
          }
        end
      end

      describes + variants
    end

  end
end
