# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The component model both SBOM formats serialize from.
#
# One model feeding two serializers is what keeps CycloneDX and SPDX from asserting
# different facts about the same gem. Neither serializer collects anything itself.
#
# A component's reference key comes from its path rather than its PURL, because a
# PURL is not unique within a Ceedling gem. CException ships twice at the same
# commit, once at vendor/c_exception and once inside CMock, so both occurrences
# produce an identical PURL. The PURL identifies the package; the path identifies the
# occurrence.
module Sbom

  # Upstream lineage for a component that has diverged from its source. Vendored fff
  # is the case in hand: a modified descendant of a Ceedling plugin packaging of the
  # framework, which stopped being a submodule in 2024.
  # Ancestors are Components, not bare identifiers. CycloneDX requires a type and a name
  # on each pedigree ancestor rather than only a PURL, and SPDX needs a whole package to
  # point a relationship at. Both serializers already know how to render a Component.
  class Pedigree
    attr_reader :ancestors, :notes

    def initialize(ancestors:, notes: nil)
      @ancestors = ancestors
      @notes = notes
    end
  end

  class Component
    attr_reader :name, :version, :purl, :license, :kind, :path, :declared, :notes,
                :pedigree, :children

    # kind distinguishes a resolved gem dependency from source shipped inside the
    # gem. The serializers render the two differently, and a consumer reads them
    # differently: one is fetched at install time, the other is already present.
    #
    # declared carries the constraint the gemspec states, kept beside the resolved
    # version so the document does not imply Ceedling pins what it only bounds.
    def initialize(name:, kind:, purl: nil, version: nil, license: nil, path: nil,
                   declared: nil, notes: nil, pedigree: nil, children: [])
      @name = name
      @kind = kind
      @purl = purl
      @version = version
      @license = license
      @path = path
      @declared = declared
      @notes = notes
      @pedigree = pedigree
      @children = children
    end

    # Stable and unique within a document. Paths are unique by construction; a
    # pathless component is a fetched gem, whose name is unique in a resolved
    # closure.
    def ref
      source = path || name
      "#{kind}-#{source.to_s.gsub( %r{[^A-Za-z0-9._-]+}, '-' )}"
    end

    def to_a
      [self] + children.flat_map( &:to_a )
    end
  end

  class Document
    attr_reader :root, :components, :properties

    def initialize(root:, components:, properties: {})
      @root = root
      @components = components
      @properties = properties
    end

    # Flattened, children included. Both serializers emit every component, and the
    # cross-format check compares these counts and PURL sets.
    def all_components
      components.flat_map( &:to_a )
    end
  end

end
