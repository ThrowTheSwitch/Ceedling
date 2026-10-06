# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'securerandom'
require 'time'

require_relative 'sources'
require_relative 'gem_licenses'
require_relative 'lockfile'
require_relative 'submodules'
require_relative 'inventory'
require_relative 'cyclonedx'
require_relative 'spdx'

# Wires collection, assembly, and rendering together, and writes the result.
#
# The only place in tools/sbom that knows all three stages. Everything it calls is
# either the single I/O boundary or pure, so this file stays a short sequence of
# delegations.
module Sbom
  class Generator

    FORMATS = {
      'cdx.json' => CycloneDX,
      'spdx.json' => SPDX
    }.freeze

    def initialize(root, output_dir: nil)
      @root = root
      @output_dir = output_dir || root
      @sources = Sources.new( root )
    end

    # Returns the paths written. A timestamp and serial number are generated here, once,
    # and handed to both serializers, so the two documents agree on when they were made.
    def build
      doc = document
      stamp = {
        timestamp: Time.now.utc.iso8601,
        serial_number: "urn:uuid:#{SecureRandom.uuid}"
      }

      FORMATS.map do |extension, serializer|
        path = File.join( @output_dir, "ceedling-#{doc.root.version}.#{extension}" )
        File.write( path, serializer.new( doc, **stamp ).render.string )
        path
      end
    end

    def document
      spec = @sources.gemspec
      lockfile = Lockfile.new( @sources.lockfile_content )
      submodules = Submodules.parse( @sources.submodule_status )
      roots = spec.runtime_dependencies.map( &:name )

      closure = lockfile.closure( roots )

      # Refuses to build a document whose gem licenses are stale. Raising here rather
      # than warning is what keeps an out-of-date list from reaching a release, and the
      # message names every disagreement at once.
      GemLicenses.verify!( closure )

      Inventory.new(
        ceedling_version: spec.version.to_s,
        declared: spec.runtime_dependencies.to_h { |d| [d.name, d.requirement.as_list.join( ', ' )] },
        closure: closure,
        submodules: submodules,
        header_versions: @sources.header_versions,
        diy_version: @sources.diy_version,
        licenses: licenses( submodules ),
        excluded_gems: lockfile.excluded( roots ),
        gem_licenses: GemLicenses.licenses_for( closure )
      ).document
    end

    private

    # Every directory whose license belongs to a component. Resolved to an SPDX
    # identifier only where the text says so plainly -- guessing an identifier from
    # license prose is a different problem than this tool solves, and a wrong guess
    # would be worse than no claim at all.
    def licenses(submodules)
      directories = ['.', 'vendor/diy', Inventory::FFF_PATH, Inventory::FFF_VENDOR_PATH] +
        submodules.map( &:path )

      directories.to_h do |directory|
        text = @sources.license_text( directory )
        [directory, text&.include?( 'MIT' ) ? 'MIT' : nil]
      end
    end

  end
end
