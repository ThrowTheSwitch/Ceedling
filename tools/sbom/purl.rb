# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'erb'

# Package URL construction, the identifier every SBOM component carries.
#
# Two types cover everything Ceedling ships. `gem` names the Ruby dependencies
# resolved from Gemfile.lock. `github` names the vendored C components, whose pinned
# commit serves as the version -- the only identity that distinguishes the two Unity
# source trees in a Ceedling gem, both of which report header version 2.7.2.
#
# Canonical form is `pkg:type/namespace/name@version?qualifiers`. The github type
# lowercases namespace and name; the gem type does not, RubyGems names being case
# sensitive. Nothing downstream validates these strings, so construction raises on an
# empty name rather than emitting an identifier that matches nothing.
module Sbom
  module Purl

    module_function

    # A RubyGems package. Version is optional only for completeness -- every gem in
    # the dependency closure has a resolved version.
    def gem(name, version = nil, qualifiers: {})
      raise ArgumentError, 'PURL requires a gem name' if name.to_s.empty?

      build( type: 'gem', name: name.to_s, version: version, qualifiers: qualifiers )
    end

    # A GitHub-hosted component, identified by commit where one is known. Namespace
    # and name are lowercased, which the type's definition requires.
    def github(namespace, name, version = nil, qualifiers: {})
      raise ArgumentError, 'PURL requires a github namespace' if namespace.to_s.empty?
      raise ArgumentError, 'PURL requires a github name' if name.to_s.empty?

      build(
        type: 'github',
        namespace: namespace.to_s.downcase,
        name: name.to_s.downcase,
        version: version,
        qualifiers: qualifiers
      )
    end

    def build(type:, name:, namespace: nil, version: nil, qualifiers: {})
      purl = +"pkg:#{type}/"
      purl << "#{encode( namespace )}/" unless namespace.to_s.empty?
      purl << encode( name )
      purl << "@#{encode( version )}" unless version.to_s.empty?

      # Qualifier order is part of canonical form, so sort rather than trusting
      # insertion order. Blank values are dropped instead of emitting a bare key.
      pairs = qualifiers
        .reject { |_key, value| value.to_s.empty? }
        .sort_by { |key, _value| key.to_s }
        .map { |key, value| "#{key}=#{encode( value )}" }

      purl << "?#{pairs.join('&')}" unless pairs.empty?
      purl
    end

    # Percent-encodes everything outside PURL's unreserved set. `/` is excluded from
    # that set here because each segment is encoded individually, so a slash reaching
    # this point would be data rather than a separator.
    def encode(value)
      ERB::Util.url_encode( value.to_s )
    end

  end
end
