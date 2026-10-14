# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for the CI summary's markdown, the body of a pull request's sticky comment.
#
# Every input is an in-memory hash, the same shapes the collector reads from CI
# artifacts and the GitHub API, so nothing here touches the filesystem or a shell.

require_relative '../renderer'

describe CiSummary::Renderer do

  def counts(examples, failures = 0, pending = 0)
    { 'examples' => examples, 'failures' => failures, 'pending' => pending }
  end

  let(:jobs) do
    [{ 'name' => 'Linux Test Suite (3.3)', 'conclusion' => 'success', 'url' => 'https://ci/1' },
     { 'name' => 'Lint Ruby Source',       'conclusion' => 'success', 'url' => 'https://ci/2' },
     { 'name' => 'Validate Ceedling Gem',  'conclusion' => 'skipped', 'url' => 'https://ci/3' }]
  end

  let(:legs) do
    { 'Linux 3.3'   => { 'units' => counts(4405), 'integration' => counts(348, 0, 15), 'system' => counts(900, 0, 3) },
      'Windows 3.4' => { 'units' => counts(4405), 'integration' => counts(348, 0, 16), 'system' => counts(880, 0, 9) } }
  end

  let(:coverage) do
    { 'units' => { 'covered' => 912, 'total' => 1000 }, 'combined' => { 'covered' => 900, 'total' => 1000 } }
  end

  let(:baseline) do
    { 'sha' => '9f8e7d6c5b', 'branch' => 'next_version', 'nearest' => false,
      'legs' => { 'Linux 3.3'   => { 'units' => counts(4393), 'integration' => counts(348, 0, 15), 'system' => counts(900, 0, 3) },
                  'Windows 3.4' => { 'units' => counts(4393), 'integration' => counts(348, 0, 16), 'system' => counts(880, 0, 9) } },
      'coverage' => { 'units' => { 'covered' => 911, 'total' => 1000 }, 'combined' => { 'covered' => 910, 'total' => 1000 } } }
  end

  let(:diff_coverage) { { covered: 48, relevant: 50, uncovered: { 'lib/x.rb' => ['42-43'] } } }

  def render(**overrides)
    described_class.render(
      sha: 'a1b2c3d4e5f6', jobs: jobs, legs: legs, coverage: coverage,
      diff_coverage: diff_coverage, baseline: baseline, **overrides
    )
  end

  it 'heads an all-green run with the commit, the passing jobs, and the baseline' do
    expect(render).to start_with( "### CI summary · a1b2c3d · ✅ 2/2 jobs passed · baseline 9f8e7d6 (next_version)\n" )
  end

  # The summary job itself is still running when it reads the run's job list
  it 'leaves out jobs still running' do
    running = jobs + [{ 'name' => 'CI Summary', 'conclusion' => nil, 'url' => 'https://ci/4' }]

    expect(render( jobs: running )).to include( '✅ 2/2 jobs passed' )
    expect(render( jobs: running )).not_to include( 'CI Summary](' )
  end

  it 'leads with the failing jobs, each linked' do
    failing = jobs.dup
    failing[0] = jobs[0].merge( 'conclusion' => 'failure' )
    markdown = render( jobs: failing )

    expect(markdown).to include( '❌ 1 of 2 jobs failed' )
    expect(markdown).to include( "- ❌ [Linux Test Suite (3.3)](https://ci/1)\n" )
  end

  it 'shows the reference leg counts with example deltas against the baseline' do
    expect(render).to include( "| units | 4405 (+12) | 0 | 0 |\n" )
    expect(render).to include( "| system | 900 | 0 | 3 |\n" )
  end

  it 'shows coverage with percentage-point deltas against the baseline' do
    expect(render).to include( "| units | 91.20% | ▲0.10 |\n" )
    expect(render).to include( "| combined | 90.00% | ▼1.00 |\n" )
  end

  it 'shows diff coverage and the uncovered changed lines' do
    expect(render).to include( '**Diff coverage:** 96.00% (48/50 changed lines). Uncovered: `lib/x.rb:42-43`' )
  end

  # A pull request comment has a size limit, and a large change can miss many ranges
  it 'lists at most twenty uncovered ranges and counts the rest' do
    ranges   = (1..25).map { |n| (n * 10).to_s }
    markdown = render( diff_coverage: { covered: 0, relevant: 25, uncovered: { 'lib/x.rb' => ranges } } )

    expect(markdown).to include( '`lib/x.rb:200`, and 5 more' )
    expect(markdown).not_to include( '`lib/x.rb:210`' )
  end

  it 'says when no changed line is Ruby that coverage tracks' do
    expect(render( diff_coverage: { covered: 0, relevant: 0, uncovered: {} } )).to include( '**Diff coverage:** no changed lines tracked' )
  end

  it 'says when diff coverage is unavailable' do
    expect(render( diff_coverage: nil )).to include( '**Diff coverage:** unavailable' )
  end

  it 'warns when a leg skips more examples than the same leg on the baseline' do
    rising = legs.merge( 'Linux 3.3' => legs['Linux 3.3'].merge( 'system' => counts(900, 0, 19) ) )

    expect(render( legs: rising )).to include( "⚠️ Linux 3.3 system: pending 3 → 19\n" )
  end

  it 'does not warn about pending counts that differ only between legs' do
    expect(render).not_to include( '⚠️' )
  end

  it 'warns about a baseline leg with no results' do
    expect(render( legs: legs.slice( 'Linux 3.3' ) )).to include( "⚠️ Windows 3.4: no results\n" )
  end

  it 'marks a baseline taken from a different commit than the merge base' do
    expect(render( baseline: baseline.merge( 'nearest' => true ) )).to include( 'nearest baseline 9f8e7d6 (next_version)' )
  end

  it 'renders without a baseline, leaving every delta blank' do
    markdown = render( baseline: nil )

    expect(markdown).to include( '· no baseline' )
    expect(markdown).to include( "| units | 4405 | 0 | 0 |\n" )
    expect(markdown).to include( "| units | 91.20% | — |\n" )
  end

  it 'lists every leg in a collapsed matrix' do
    expect(render).to include( "| Windows 3.4 | 4405 / 0 / 0 | 348 / 0 / 16 | 880 / 0 / 9 |\n" )
  end

end
