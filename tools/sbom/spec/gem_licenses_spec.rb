# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for the curated gem license map and the checks that keep it honest.
#
# The map is hand-maintained because nothing else works. Gemfile.lock records no
# license, and a gem's own gemspec is unreliable -- constructor declares none while
# stating MIT in its README, and benchmark is dual-licensed, which no single identifier
# expresses. A human has to read and record, once per version.
#
# Hand-maintained means it can go stale, so three structural checks run against the
# resolved closure. They catch a dependency arriving, a dependency leaving, and a
# version moving under an entry that was verified against a different one.

require_relative '../gem_licenses'

describe Sbom::GemLicenses do

  describe 'the curated map' do
    it 'records a license, the version it was verified against, and where it was read' do
      entry = described_class::GEMS['rake']

      expect( entry[:license] ).to eq('MIT')
      expect( entry[:verified_for] ).to be_a(String)
      expect( entry[:source] ).to be_a(String)
    end

    it 'expresses a dual license as an SPDX expression, not a single identifier' do
      # benchmark is offered under either Ruby or BSD-2-Clause
      expect( described_class::GEMS['benchmark'][:license] ).to eq('Ruby OR BSD-2-Clause')
    end

    it 'records where a license came from when the gemspec does not declare one' do
      # constructor's gemspec declares nothing; its README states MIT. This is the case
      # that makes automated extraction insufficient.
      entry = described_class::GEMS['constructor']

      expect( entry[:license] ).to eq('MIT')
      expect( entry[:source] ).to match(/README/i)
    end
  end

  describe '.licenses_for' do
    it 'maps closure names to their recorded licenses' do
      result = described_class.licenses_for( { 'rake' => '13.2.1', 'thor' => '1.5.0' } )

      expect( result ).to eq({ 'rake' => 'MIT', 'thor' => 'MIT' })
    end

    it 'omits a gem the map does not cover rather than inventing a license' do
      expect( described_class.licenses_for( { 'mystery' => '1.0.0' } ) ).to eq({})
    end
  end

  describe '.audit' do
    it 'is quiet when the closure matches the map exactly' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }

      expect( described_class.audit( closure ) ).to be_empty
    end

    it 'reports a dependency that arrived without a map entry' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }
        .merge( 'newcomer' => '1.0.0' )

      expect( described_class.audit( closure ).join( ' ' ) ).to match(/newcomer/)
    end

    it 'reports a dependency that left while its entry stayed' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }
      closure.delete( 'thor' )

      expect( described_class.audit( closure ).join( ' ' ) ).to match(/thor/)
    end

    # The check that makes the map maintainable rather than merely hand-written. A
    # license cannot be re-read without the network, but a version change is a reliable
    # proxy for "worth re-reading", and it is detectable with no network at all.
    it 'reports a version that moved away from the one its entry was verified against' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }
      closure['rake'] = '99.0.0'

      problems = described_class.audit( closure ).join( ' ' )

      expect( problems ).to match(/rake/)
      expect( problems ).to match(/99\.0\.0/)
    end

    it 'names the recorded version too, so the reviewer can see what moved' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }
      closure['rake'] = '99.0.0'

      expect( described_class.audit( closure ).join( ' ' ) )
        .to include(described_class::GEMS['rake'][:verified_for])
    end
  end

  describe '.verify!' do
    it 'passes silently when the map is current' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }

      expect { described_class.verify!( closure ) }.not_to raise_error
    end

    # Raising rather than warning, because Gemfile.lock is curated by hand in this
    # repository. Every version change is already a deliberate act, so the failure lands
    # while someone is editing dependencies, and the fix is one line in the map.
    it 'raises on any drift, so a stale map cannot reach a published document' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }
      closure['rake'] = '99.0.0'

      expect { described_class.verify!( closure ) }
        .to raise_error(described_class::Error, /rake/)
    end

    it 'names every problem at once rather than one per run' do
      closure = described_class::GEMS.transform_values { |e| e[:verified_for] }
      closure['rake'] = '99.0.0'
      closure['brand-new'] = '1.0.0'

      expect { described_class.verify!( closure ) }
        .to raise_error(described_class::Error, /rake.*brand-new|brand-new.*rake/m)
    end
  end

end
