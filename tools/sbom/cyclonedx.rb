# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'json'

# Renders the component model as CycloneDX.
#
# CycloneDX carries a PURL as a first-class field and expresses a modified component's
# lineage natively through pedigree, which is why it is the primary format here.
#
# The timestamp and serial number arrive from the caller rather than being generated.
# A document is then a function of its model alone, which is what lets a spec compare
# two renderings and a reviewer compare two releases.
module Sbom
  class CycloneDX

    SPEC_VERSION = '1.6'

    def initialize(document, timestamp:, serial_number:)
      @document = document
      @timestamp = timestamp
      @serial_number = serial_number
    end

    def render(io = StringIO.new)
      io.write( JSON.pretty_generate( bom ) )
      io
    end

    private

    def bom
      {
        'bomFormat' => 'CycloneDX',
        'specVersion' => SPEC_VERSION,
        'serialNumber' => @serial_number,
        'version' => 1,
        'metadata' => {
          'timestamp' => @timestamp,
          'tools' => [{ 'name' => 'ceedling-sbom', 'vendor' => 'ThrowTheSwitch.org' }],
          'component' => component( @document.root ),
          'properties' => properties
        },
        'components' => @document.components.map { |c| component( c ) }
      }
    end

    def properties
      @document.properties.map { |name, value| { 'name' => name, 'value' => value } }
    end

    # A component holding others nests them in its own `components` array, which is how
    # CycloneDX says one thing contains another. The vendored framework inside the fff
    # plugin is the case here. Without the nesting, containment would survive only as a
    # path string in a property, readable by a person and by nothing else.
    def component(entry)
      # Every component here is a library, whether it arrives as a gem or as vendored
      # source. The distinction between the two is carried by ceedling:path below.
      result = {
        'type' => 'library',
        'bom-ref' => entry.ref,
        'name' => entry.name
      }

      result['version'] = entry.version unless entry.version.nil?
      result['purl'] = entry.purl unless entry.purl.nil?
      result['licenses'] = licenses( entry.license ) unless entry.license.nil?
      result['pedigree'] = pedigree( entry.pedigree ) unless entry.pedigree.nil?

      extra = component_properties( entry )
      result['properties'] = extra unless extra.empty?

      result['components'] = entry.children.map { |child| component( child ) } unless entry.children.empty?

      result
    end

    # A single SPDX identifier goes in `license.id`, which the schema validates against
    # the SPDX list. A compound license is not an identifier and belongs in `expression`
    # instead -- benchmark, offered under either Ruby or BSD-2-Clause, is the case here.
    def licenses(license)
      if license.match?(/\s(?:OR|AND|WITH)\s/)
        [{ 'expression' => license }]
      else
        [{ 'license' => { 'id' => license } }]
      end
    end

    # Each ancestor renders as a full component. The schema requires a type and a name on
    # it, not merely an identifier.
    def pedigree(lineage)
      {
        'ancestors' => lineage.ancestors.map { |ancestor| component( ancestor ) },
        'notes' => lineage.notes
      }.compact
    end

    # Where a component sits inside the gem, the constraint the gemspec declares, and
    # anything worth saying in prose. The path is what distinguishes two occurrences of
    # one package, so it belongs in the document and not only in the bom-ref.
    def component_properties(entry)
      pairs = {
        'ceedling:path' => entry.path,
        'ceedling:declared-constraint' => entry.declared,
        'ceedling:notes' => entry.notes
      }

      pairs.compact.map { |name, value| { 'name' => name, 'value' => value } }
    end

  end
end
