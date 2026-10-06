# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Curated licenses for the runtime gem dependencies, and the checks that keep the list
# from going stale.
#
# Hand-maintained because nothing else is accurate. Gemfile.lock records no license at
# all, and a gem's own gemspec is unreliable: constructor declares none while stating
# MIT plainly in its README, and benchmark is dual-licensed, which no single identifier
# expresses. Reading and recording, once per version, is the only honest option.
#
# Each entry carries the version it was verified against. That is what makes the list
# maintainable rather than merely hand-written. A license cannot be re-read without the
# network, but a version change is a reliable proxy for "worth re-reading" and costs
# nothing to detect. Three checks follow from it: a dependency arriving without an
# entry, an entry outliving its dependency, and a version moving under an entry.
#
# To update an entry: read the gem's license where `source` says it lives, then set
# `license` and `verified_for` together. `rake sbom:licenses:audit` compares the list
# against gems installed locally, which catches the remaining case these checks cannot
# -- a gem relicensing without changing version.
module Sbom
  module GemLicenses

    class Error < RuntimeError; end

    GEMS = {
      'benchmark' => {
        # Offered under either, so an SPDX expression rather than one identifier
        license: 'Ruby OR BSD-2-Clause',
        verified_for: '0.5.0',
        source: "the gem's own gemspec"
      },
      'constructor' => {
        license: 'MIT',
        verified_for: '2.0.0',
        source: 'README.rdoc, Copyright (c) 2007-2010 Atomic Object -- the gemspec declares none'
      },
      'deep_merge' => {
        license: 'MIT',
        verified_for: '1.2.2',
        source: "the gem's own gemspec"
      },
      'parallel' => {
        license: 'MIT',
        verified_for: '1.28.0',
        source: "the gem's own gemspec"
      },
      'rake' => {
        license: 'MIT',
        verified_for: '13.2.1',
        source: "the gem's own gemspec"
      },
      'thor' => {
        license: 'MIT',
        verified_for: '1.5.0',
        source: "the gem's own gemspec"
      },
      'unicode-display_width' => {
        license: 'MIT',
        verified_for: '3.2.0',
        source: "the gem's own gemspec"
      },
      'unicode-emoji' => {
        license: 'MIT',
        verified_for: '4.2.0',
        source: "the gem's own gemspec"
      }
    }.freeze

    module_function

    # Closure name to recorded license, skipping anything the list does not cover.
    # Omission is deliberate: an uncovered gem gets no license rather than a guess, and
    # #verify! is what refuses to let that reach a document.
    def licenses_for(closure)
      closure.keys.each_with_object( {} ) do |name, result|
        entry = GEMS[name]
        result[name] = entry[:license] if entry && entry[:license]
      end
    end

    # Every way the list and the closure can disagree, as readable sentences.
    def audit(closure)
      problems = []

      (closure.keys - GEMS.keys).sort.each do |name|
        problems << "#{name} #{closure[name]} is a new dependency with no license entry. " \
                    'Read its license and add one.'
      end

      (GEMS.keys - closure.keys).sort.each do |name|
        problems << "#{name} has a license entry but is no longer a dependency. Remove it."
      end

      closure.each do |name, version|
        entry = GEMS[name]
        next if entry.nil?
        next if entry[:verified_for] == version

        problems << "#{name} resolved to #{version} but its license was verified " \
                    "against #{entry[:verified_for]}. Re-read #{entry[:source]}, then " \
                    'update license and verified_for together.'
      end

      problems
    end

    # Raises on any disagreement, rather than warning. Gemfile.lock is curated by hand
    # here, so a version change is already a deliberate act -- this failure lands while
    # someone is editing dependencies, and the fix is one line.
    def verify!(closure)
      problems = audit( closure )
      return if problems.empty?

      raise Error, "Gem license list is out of date:\n  - #{problems.join( "\n  - " )}"
    end

  end
end
