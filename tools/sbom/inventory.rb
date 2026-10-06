# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'model'
require_relative 'purl'

# Turns the facts about a Ceedling gem into the component model.
#
# Receives plain values rather than reading anything, which is what lets it be
# specified without a filesystem. sources.rb collects; this assembles.
#
# Two kinds of component come out. A gem is fetched at install time and identified by
# its resolved version. Vendored source is already present and identified by the commit
# it was pinned at, which matters because two Unity trees ship in one gem at different
# commits while both report header version 2.7.2.
module Sbom
  class Inventory

    class Error < RuntimeError; end

    # Submodule directory basename to the GitHub coordinates its source came from.
    # CException is the one whose repository name differs from its directory.
    REPOSITORIES = {
      'unity'       => %w[throwtheswitch unity],
      'cmock'       => %w[throwtheswitch cmock],
      'c_exception' => %w[throwtheswitch cexception]
    }.freeze

    # Header macro versions arrive keyed by component rather than by path, since both
    # copies of a component report the same one.
    HEADER_KEYS = { 'unity' => :unity, 'cmock' => :cmock, 'c_exception' => :cexception }.freeze

    # fff reached Ceedling as a submodule of a plugin packaging of the framework, became
    # a snapshot of 0.1.1 in January 2024, and has been modified since. Constants rather
    # than lookups: nothing in the tree records any of it.
    FFF_ANCESTOR_COMMIT = 'd3914ef0'
    FFF_PATH = 'plugins/fff'
    FFF_VENDOR_PATH = 'plugins/fff/vendor/fff'

    # `licenses` keys on a path, for source shipped inside the gem whose license file was
    # read. `gem_licenses` keys on a gem name, those arriving from the curated list --
    # Gemfile.lock records no license, so they cannot be read from anything here.
    def initialize(ceedling_version:, declared:, closure:, submodules:, header_versions:,
                   diy_version:, licenses:, excluded_gems:, gem_licenses: {})
      @ceedling_version = ceedling_version
      @declared = declared
      @closure = closure
      @submodules = submodules
      @header_versions = header_versions
      @diy_version = diy_version
      @licenses = licenses
      @excluded_gems = excluded_gems
      @gem_licenses = gem_licenses
    end

    def document
      Document.new( root: root, components: gems + vendored, properties: properties )
    end

    private

    def root
      Component.new(
        name: 'ceedling',
        kind: 'root',
        version: @ceedling_version,
        purl: Purl.gem( 'ceedling', @ceedling_version ),
        license: @licenses['.']
      )
    end

    def gems
      @closure.sort.map do |name, version|
        Component.new(
          name: name,
          kind: 'gem',
          version: version,
          purl: Purl.gem( name, version ),
          license: @gem_licenses[name],
          declared: @declared[name]
        )
      end
    end

    def vendored
      submodule_components + [diy_component, fff_component]
    end

    def submodule_components
      @submodules.map do |entry|
        # An uninitialized submodule still records its commit, but nothing can be read
        # out of its working tree. Describing it anyway would publish a component with
        # no version while claiming completeness.
        unless entry.initialized?
          raise Error, "submodule #{entry.path} is not initialized -- cannot describe it"
        end

        key = File.basename( entry.path )
        namespace, repository = REPOSITORIES.fetch( key ) do
          raise Error, "no repository known for submodule #{entry.path}"
        end

        Component.new(
          name: repository,
          kind: 'bundled',
          path: entry.path,
          version: @header_versions[HEADER_KEYS[key]],
          purl: Purl.github( namespace, repository, entry.commit ),
          license: @licenses[entry.path]
        )
      end
    end

    # DIY ships as source inside the gem rather than arriving as a dependency, so it is
    # a bundled component even though its identifier is a gem PURL.
    def diy_component
      Component.new(
        name: 'diy',
        kind: 'bundled',
        path: 'vendor/diy',
        version: @diy_version,
        purl: Purl.gem( 'diy', @diy_version ),
        license: @licenses['vendor/diy'],
        notes: 'Vendored rather than depended upon. Upstream unmaintained since 2009.'
      )
    end

    # The plugin layer and the framework it carries are separate components: the plugin
    # has diverged from its upstream, while the framework underneath is a copy.
    #
    # The plugin layer carries no PURL of its own, deliberately. Having been modified, it
    # is no longer the package it descends from, and pointing a PURL at that package
    # would invite a scanner to match advisories against code that differs. Its lineage
    # is expressed as pedigree instead, which is what pedigree is for.
    def fff_component
      Component.new(
        name: 'fake_function_framework',
        kind: 'bundled',
        path: FFF_PATH,
        license: @licenses[FFF_PATH],
        notes: 'Modified descendant, so no upstream package identifier applies. See pedigree.',
        pedigree: Pedigree.new(
          ancestors: [
            Component.new(
              name: 'fake_function_framework',
              kind: 'ancestor',
              purl: Purl.github( 'electronvector', 'fake_function_framework', FFF_ANCESTOR_COMMIT ),
              license: 'MIT',
              path: 'ancestor/electronvector-fake_function_framework'
            )
          ],
          notes: 'Descends from a snapshot of 0.1.1, modified since it stopped being a submodule in 2024.'
        ),
        children: [
          Component.new(
            name: 'fff',
            kind: 'bundled',
            path: FFF_VENDOR_PATH,
            # No version of any kind. The vendored framework carries no version macro
            # and no version file, so a PURL without one is the honest identifier.
            purl: Purl.github( 'meekrosoft', 'fff' ),
            license: @licenses[FFF_VENDOR_PATH],
            notes: 'Upstream carries no version marker.'
          )
        ]
      )
    end

    # Repeated in the document itself, not only in the documentation. A consumer who
    # finds an SBOM without its page still has to learn what it does and does not cover.
    def properties
      {
        'ceedling:scope' =>
          'Describes the Ceedling gem as distributed. Does not describe the C code ' \
          'Ceedling builds -- not generated test runners or mocks, not user source, ' \
          'and not user toolchains.',
        'ceedling:plugin-tools' =>
          'Does not describe per-installation plugin tool requirements. An enabled ' \
          'gcov, valgrind, bullseye, or cppcheck plugin needs external tools that ' \
          'vary by installation and are documented with each plugin.',
        'ceedling:excluded-development-dependencies' =>
          'Development and test dependencies are outside this scope. Excluded: ' \
          "#{@excluded_gems.sort.join( ', ' )}.",
        'ceedling:dependency-versions' =>
          'Gem versions are those the release build resolved, not the only versions ' \
          'the declared constraints permit.',
        'ceedling:gem-licenses' =>
          'Licenses for source shipped inside the gem were read from the license file ' \
          'beside it. Licenses for fetched gems come from a curated list, Gemfile.lock ' \
          'recording none and a gemspec being unreliable, and each was verified against ' \
          'the resolved version.'
      }
    end

  end
end
