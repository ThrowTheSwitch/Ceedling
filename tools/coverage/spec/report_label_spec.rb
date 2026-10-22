# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for the name a merged coverage report gives its runs.
#
# These specs live under tools/ rather than spec/ because spec/ ships inside the gem
# for certification self-tests while tools/ is excluded from it.

require_relative '../report_label'

describe CoverageReportLabel do

  it 'names a suite measured in a single run' do
    expect(described_class.for( 'units' => 1 )).to eq( 'units' )
    expect(described_class.for( 'integration' => 1 )).to eq( 'integration' )
  end

  it 'counts the runs of a suite measured in many' do
    expect(described_class.for( 'system' => 714 )).to eq( 'system (714 runs)' )
  end

  it 'lists every suite of a combined report in order' do
    expect(described_class.for( 'units' => 1, 'integration' => 1, 'system' => 714 )).to eq( 'units, integration, system (714 runs)' )
  end

  it 'leaves out a suite with no runs' do
    expect(described_class.for( 'units' => 1, 'integration' => 0, 'system' => 2 )).to eq( 'units, system (2 runs)' )
  end

  it 'counts a single system run in the singular' do
    expect(described_class.for( 'system' => 1 )).to eq( 'system (1 run)' )
  end

end
