# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'contract/runner'
require 'contract/recorder'

# One example group per row file in spec/contract/rows. Each row builds every variant
# once, before its examples, and each example checks one column of one variant.
describe 'Contract rows' do

  platform = Contract.platform

  # Each row's time, for the tier's total
  timings = {}

  after(:context) do
    next if timings.empty?

    FileUtils.mkdir_p( Contract.out_dir )
    lines = timings.map { |id, seconds| format( '%-10s %7.1fs', id, seconds ) }
    lines << format( '%-10s %7.1fs', 'total', timings.values.sum )
    File.write( File.join( Contract.out_dir, "timings-#{platform}.txt" ), lines.join( "\n" ) + "\n" )
  end

  Contract::Loader.all.each do |row|
    describe row.id, row.title do

      runs_here = row.platforms.include?( platform )

      before(:context) do
        @state = { mismatch: false }
        next unless runs_here

        started  = Process.clock_gettime( Process::CLOCK_MONOTONIC )
        runner   = Contract::Runner.new( row )
        @results = row.variants.to_h { |variant| [variant.key, runner.run( variant )] }
        timings[row.id] = Process.clock_gettime( Process::CLOCK_MONOTONIC ) - started
        @recorder = Contract::Recorder.new( row )
      end

      after(:context) do
        next unless runs_here

        merged = @recorder.merged( platform, @results.values )
        @recorder.write( merged ) if Contract.recording?
        @recorder.write( merged, File.join( Contract.out_dir, "#{row.id}.yml" ) ) if Contract.recording? || @state[:mismatch]
      end

      # The variant's result, skipping the example where the row or the leg cannot run
      def result_for(row, key, runs_here)
        skip( "#{row.id} runs on #{row.platforms.join( ', ' )} only: #{row.platform_note}" ) unless runs_here

        result = @results.fetch( key )
        skip( result.skipped ) unless result.skipped.nil?
        return result
      end

      def checked
        yield
      rescue Contract::Mismatch
        @state[:mismatch] = true
        raise
      end

      row.variants.each do |variant|
        context variant.key do

          it 'matches its recorded current column' do
            result = result_for( row, variant.key, runs_here )
            next if Contract.recording?

            checked do
              recorded = @recorder.current( platform, variant.key )
              raise Contract::Mismatch, "no #{platform} section is recorded for #{variant.key}. Record it with CONTRACT_RECORD=1." if recorded.nil?

              Contract::Check.equal!( recorded, Contract::Recorder.section( result ), "#{row.id} #{variant.key} on #{platform}" )
            end
          end

          it 'agrees with the recorded compiler column' do
            result = result_for( row, variant.key, runs_here )
            next if Contract.recording?

            checked do
              recorded = @recorder.compiler
              raise Contract::Mismatch, "no compiler column is recorded. Record it with CONTRACT_RECORD=1." if recorded.nil?

              Contract::Check.equal!( recorded, Contract::Recorder.compiler_column( result ), "#{row.id} #{variant.key} compiler column" )
            end
          end

          it 'declares every divergence from the compiler' do
            result   = result_for( row, variant.key, runs_here )
            declared = row.divergences.map( &:at )

            checked do
              result.builds.each_with_index do |build, index|
                found = Contract::Check.divergences( build.report['resolved'], build.compiler )
                Contract::Check.declared!( found, declared, "#{row.id} #{variant.key} build #{index + 1}" )
              end
            end
          end

          unless row.target.nil?
            it 'meets its target' do
              result = result_for( row, variant.key, runs_here )
              target = row.target[variant.key]
              skip( "no target for #{variant.key}" ) if target.nil?

              pending( 'the redesign has not yet made this row meet its target' )
              live = Contract::Recorder.section( result )
              Contract::Check.equal!( target, live.map { |build| build.slice( *target.first.keys ) }, "#{row.id} #{variant.key} target" )
            end
          end

        end
      end

      it 'declares only divergences it shows' do
        skip( "#{row.id} runs on #{row.platforms.join( ', ' )} only: #{row.platform_note}" ) unless runs_here
        skip( 'a leg could not run here, so its divergences are unknown' ) if @results.values.any?( &:skipped )

        shown = @results.values.flat_map do |result|
          result.builds.flat_map { |build| Contract::Check.divergences( build.report['resolved'], build.compiler ).keys }
        end
        stale = row.divergences.map( &:at ) - shown

        expect( stale ).to be_empty, "declared but never shown: #{stale.join( '; ' )}"
      end

    end
  end

end
