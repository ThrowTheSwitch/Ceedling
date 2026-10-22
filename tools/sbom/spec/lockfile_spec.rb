# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for resolving the runtime dependency closure out of Gemfile.lock.
#
# The closure starts from the gemspec's declared runtime dependencies, not from the
# Gemfile. That distinction is what separates the eight gems a user installs from the
# twenty-odd a contributor does, and it is why Ceedling needs no Bundler groups to
# produce an accurate document.
#
# The sample below is crafted rather than copied from the repository. It mirrors the
# real lockfile's shape while staying readable, and it stays stable as dependencies
# move. Real figures are asserted by an end-to-end generation run instead, where
# drift is the point rather than noise.

require_relative '../lockfile'

describe Sbom::Lockfile do

  # Shaped like the real lockfile. `shared` is reachable from both a runtime gem and
  # a dev gem, which is the case most easily got wrong.
  LOCK = <<~TEXT
    GEM
      remote: http://rubygems.org/
      specs:
        benchmark (0.5.0)
        constructor (2.0.0)
        deep_merge (1.2.2)
        diff-lcs (1.6.2)
        parallel (1.28.0)
          shared (1.0.0)
        rake (13.2.1)
        rspec (3.13.2)
          rspec-core (~> 3.13.0)
        rspec-core (3.13.7)
          rspec-support (~> 3.13.0)
          shared (1.0.0)
        rspec-support (3.13.6)
        shared (1.0.0)
        thor (1.5.0)
        unicode-display_width (3.2.0)
          unicode-emoji (~> 4.1)
        unicode-emoji (4.2.0)

    PLATFORMS
      ruby

    DEPENDENCIES
      benchmark (>= 0.3)
      constructor (~> 2)
      deep_merge (~> 1.2)
      diff-lcs (~> 1.5)
      parallel (~> 1.26)
      rake (>= 12, < 14)
      rspec (~> 3.8)
      thor (~> 1.3)
      unicode-display_width (~> 3.1)

    BUNDLED WITH
       2.5.23
  TEXT

  # The gemspec's runtime roots, as they stand with DIY vendored rather than declared
  ROOTS = %w[rake constructor thor deep_merge benchmark unicode-display_width parallel].freeze

  subject(:lockfile) { Sbom::Lockfile.new( LOCK ) }

  describe '#closure' do
    it 'resolves every root to its locked version' do
      expect( lockfile.closure( ROOTS ) ).to include(
        'rake' => '13.2.1',
        'thor' => '1.5.0',
        'benchmark' => '0.5.0',
        'unicode-display_width' => '3.2.0'
      )
    end

    it 'reaches a transitive dependency no root names directly' do
      expect( lockfile.closure( ROOTS ) ).to include('unicode-emoji' => '4.2.0')
    end

    it 'includes a gem reachable from both a runtime and a development path' do
      # Reachability from any runtime root is what qualifies a gem, regardless of
      # what else also depends on it
      expect( lockfile.closure( ROOTS ) ).to include('shared' => '1.0.0')
    end

    it 'excludes development-only gems and everything only they reach' do
      resolved = lockfile.closure( ROOTS ).keys
      expect( resolved ).not_to include('rspec', 'rspec-core', 'rspec-support', 'diff-lcs')
    end

    it 'returns names in a stable order so output does not churn' do
      expect( lockfile.closure( ROOTS ).keys ).to eq(lockfile.closure( ROOTS.shuffle ).keys)
    end

    it 'ignores a root absent from the lockfile rather than inventing a version' do
      expect( lockfile.closure( ROOTS + ['not-in-lock'] ) ).not_to have_key('not-in-lock')
    end
  end

  describe '#excluded' do
    it 'names every locked gem outside the closure' do
      expect( lockfile.excluded( ROOTS ) ).to eq(['diff-lcs', 'rspec', 'rspec-core', 'rspec-support'])
    end

    it 'partitions the lockfile exactly, nothing counted twice or lost' do
      total = lockfile.closure( ROOTS ).size + lockfile.excluded( ROOTS ).size
      expect( total ).to eq(lockfile.all_specs.size)
    end
  end

end
