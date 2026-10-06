# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'bundler'

# Resolves the runtime dependency closure out of Gemfile.lock.
#
# The closure starts from the gemspec's declared runtime dependencies rather than from
# the Gemfile. That is what separates the gems a user installs from the ones only a
# contributor does, and it is why an accurate document needs no Bundler groups. The
# Gemfile describes the contributor environment, which this SBOM's scope excludes.
#
# `Bundler::LockfileParser` takes a string, so this class reads no file. Bundler
# already ships with Ceedling, so parsing the real format costs no new dependency and
# avoids hand-rolling a parser against a format Bundler owns.
module Sbom
  class Lockfile

    def initialize(content)
      @specs = Bundler::LockfileParser.new( content ).specs.to_h { |spec| [spec.name, spec] }
    end

    def all_specs
      @specs
    end

    # Walks outward from the root names, following each locked spec's own
    # dependencies. A gem qualifies by being reachable from any runtime root, whatever
    # else also depends on it. Names absent from the lockfile are skipped rather than
    # guessed at, which keeps a stale root from inventing a component.
    def closure(root_names)
      found = {}

      visit = lambda do |name|
        return if found.key?( name )

        spec = @specs[name]
        return if spec.nil?

        found[name] = spec.version.to_s
        spec.dependencies.each { |dependency| visit.call( dependency.name ) }
      end

      root_names.each { |name| visit.call( name ) }

      # Sorted so a regenerated document does not reorder on root ordering alone
      found.sort.to_h
    end

    # Everything locked but outside the closure: the development and test gems, plus
    # whatever only they reach. Named rather than merely absent so the document can
    # state what it leaves out.
    def excluded(root_names)
      (@specs.keys - closure( root_names ).keys).sort
    end

  end
end
