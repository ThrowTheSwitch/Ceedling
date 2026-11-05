# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for reading each CI leg's results from the artifacts the workflow downloads.

require 'tmpdir'
require_relative '../collector'

describe CiSummary::Collector do
  around(:each) do |example|
    Dir.mktmpdir { |dir| @results_dir = dir; example.run }
  end

  def rspec_json(examples)
    return JSON.generate( 'summary' => { 'example_count' => examples, 'failure_count' => 0, 'pending_count' => 0,
                                         'errors_outside_of_examples_count' => 0 } )
  end

  def write_result(artifact, suite, text)
    FileUtils.mkdir_p( File.join( @results_dir, artifact ) )
    File.write( File.join( @results_dir, artifact, "#{suite}.json" ), text )
  end

  def legs
    collector = described_class.new( results_dir: @results_dir, jobs_path: nil, baseline_path: nil, diff_path: nil, merge_base: nil )
    return collector.legs
  end

  describe '#legs' do
    it 'reads each suite a leg uploaded' do
      write_result( 'ci-results-Windows-ruby-3.3', 'units', rspec_json( 5363 ) )

      expect(legs).to eq( 'Windows 3.3' => { 'units' => { 'examples' => 5363, 'failures' => 0, 'pending' => 0 } } )
    end

    # A spec run killed by a timeout or a cancellation leaves its results file empty or cut short
    it 'reads an empty results file as no results for that suite, and keeps the leg’s other suites' do
      write_result( 'ci-results-Windows-ruby-3.0', 'units', '' )
      write_result( 'ci-results-Windows-ruby-3.0', 'integration', rspec_json( 582 ) )

      expect(legs).to eq( 'Windows 3.0' => { 'integration' => { 'examples' => 582, 'failures' => 0, 'pending' => 0 } } )
    end

    it 'reads a truncated results file as no results for that suite' do
      write_result( 'ci-results-Windows-ruby-3.1', 'units', rspec_json( 5363 )[0, 20] )

      expect(legs).to eq( 'Windows 3.1' => {} )
    end
  end
end
