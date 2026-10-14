# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for reading one CI leg's RSpec results.

require_relative '../results'

describe CiSummary::Results do

  describe '.counts' do
    it 'reads examples, failures, and pending from an RSpec JSON summary' do
      rspec = { 'summary' => { 'example_count' => 12, 'failure_count' => 1, 'pending_count' => 3,
                               'errors_outside_of_examples_count' => 0 } }

      expect(described_class.counts( rspec )).to eq( 'examples' => 12, 'failures' => 1, 'pending' => 3 )
    end

    it 'counts an error outside any example as a failure' do
      rspec = { 'summary' => { 'example_count' => 0, 'failure_count' => 0, 'pending_count' => 0,
                               'errors_outside_of_examples_count' => 2 } }

      expect(described_class.counts( rspec )['failures']).to eq( 2 )
    end
  end

  describe '.leg_name' do
    it 'names a leg by its runner OS and Ruby version' do
      expect(described_class.leg_name( 'ci-results-Linux-ruby-3.3' )).to eq( 'Linux 3.3' )
    end

    it 'returns nil for an artifact that holds no leg results' do
      expect(described_class.leg_name( 'coverage-report' )).to be_nil
    end
  end

end
