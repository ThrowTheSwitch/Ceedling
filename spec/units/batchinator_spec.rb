# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/batchinator'
require 'ceedling/constants'

# Parallel.map is stubbed to a plain serial map throughout this file. That
# strips out real threading entirely, so these specs exercise Batchinator's
# own decision logic -- worker count lookup, item dispatch, error handling --
# without testing Ruby's or the parallel gem's own thread scheduling, which
# isn't Batchinator's job to get right and isn't practical to assert on
# deterministically. A small number of real-threading smoke tests exist
# separately to catch a broken Parallel integration this stub would hide.
describe Batchinator do
  before(:each) do
    @configurator = double('configurator')

    @loginator = double('loginator')
    allow(@loginator).to receive(:log)
    allow(@loginator).to receive(:lazy)
    allow(@loginator).to receive(:decorate) {|msg, _label| msg }

    @reportinator = double('reportinator')
    allow(@reportinator).to receive(:generate_heading) {|msg| msg }
    allow(@reportinator).to receive(:generate_progress) {|msg| msg }

    @batchinator = described_class.new({
      :configurator => @configurator,
      :loginator    => @loginator,
      :reportinator => @reportinator,
    })

    # Mirrors the real gem's contract closely enough for these specs: runs
    # serially (no real threading), calls the given block once per item in
    # order, and invokes start:/finish: around each call the same way the
    # real gem does, if given. block.call(item) (not block.call(*item)) so
    # Ruby's own proc auto-splat -- not this stub -- is what decomposes a
    # Hash pair into |key, value|, same as production.
    allow(Parallel).to receive(:map) do |things, in_threads: nil, start: nil, finish: nil, &block|
      things.to_a.each_with_index.map do |item, index|
        start.call( item, index ) if start
        result = block.call( item )
        finish.call( item, index, result ) if finish
        result
      end
    end
  end

  # =========================================================================
  describe '#exec' do
    it 'uses project_compile_threads as the worker count for :compile workload' do
      allow(@configurator).to receive(:project_compile_threads).and_return(3)

      captured_workers = nil
      allow(Parallel).to receive(:map) do |things, in_threads:, **_opts, &block|
        captured_workers = in_threads
        things.map(&block)
      end

      @batchinator.exec(workload: :compile, things: [1]) {|item| item }

      expect(captured_workers).to eq(3)
    end

    it 'uses project_test_threads as the worker count for :test workload' do
      allow(@configurator).to receive(:project_test_threads).and_return(7)

      captured_workers = nil
      allow(Parallel).to receive(:map) do |things, in_threads:, **_opts, &block|
        captured_workers = in_threads
        things.map(&block)
      end

      @batchinator.exec(workload: :test, things: [1]) {|item| item }

      expect(captured_workers).to eq(7)
    end

    it 'passes every item to the job block exactly once, in input order' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      processed = []
      @batchinator.exec(workload: :compile, things: [1, 2, 3]) do |item|
        processed << item
      end

      expect(processed).to eq([1, 2, 3])
    end

    it 'auto-splats a Hash pair into key and value block parameters' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      captured = []
      @batchinator.exec(workload: :compile, things: {a: 1, b: 2}) do |key, value|
        captured << [key, value]
      end

      expect(captured).to eq([[:a, 1], [:b, 2]])
    end

    it 'does not raise for an empty things collection' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      expect {
        @batchinator.exec(workload: :compile, things: []) {|item| item }
      }.to_not raise_error
    end

    it 'raises ArgumentError for an unrecognized workload' do
      expect {
        @batchinator.exec(workload: :bogus, things: [1]) {|item| item }
      }.to raise_error(ArgumentError, /Unrecognized batch workload type/)
    end

    it 'returns the job block per-item results directly, with no timing wrapper' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      result = @batchinator.exec(workload: :compile, things: [1, 2, 3]) {|item| item * 10 }

      expect(result).to eq([10, 20, 30])
    end

    it 'times each item using Parallel.map start:/finish: callbacks, once per item' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      start_indexes = []
      finish_indexes = []
      allow(Parallel).to receive(:map) do |things, in_threads:, start:, finish:, &block|
        things.each_with_index.map do |item, index|
          start.call( item, index )
          start_indexes << index
          result = block.call( item )
          finish.call( item, index, result )
          finish_indexes << index
          result
        end
      end

      @batchinator.exec(workload: :compile, things: [10, 20, 30]) {|item| item }

      expect(start_indexes).to eq([0, 1, 2])
      expect(finish_indexes).to eq([0, 1, 2])
    end

    it 'logs a well-formed batch elapsed summary after processing' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      logged_message = nil
      allow(@loginator).to receive(:lazy) {|_verbosity, &blk| logged_message = blk.call }

      @batchinator.exec(workload: :compile, things: [1, 2]) {|item| item }

      expect(logged_message).to match(/Batch Elapsed: \(All: [\d.]+sec Sum: [\d.]+sec\)/)
    end

    it 'logs a sane batch elapsed summary for an empty things collection' do
      allow(@configurator).to receive(:project_compile_threads).and_return(2)

      logged_message = nil
      allow(@loginator).to receive(:lazy) {|_verbosity, &blk| logged_message = blk.call }

      @batchinator.exec(workload: :compile, things: []) {|item| item }

      expect(logged_message).to match(/Batch Elapsed: \(All: [\d.]+sec Sum: 0\.000sec\)/)
    end
  end

  # =========================================================================
  describe '#build_step' do
    it 'logs a heading message by default' do
      expect(@reportinator).to receive(:generate_heading)
      expect(@loginator).to receive(:log)

      @batchinator.build_step('Doing a thing') { }
    end

    it 'logs a progress message when heading: false' do
      expect(@reportinator).to receive(:generate_progress)
      expect(@loginator).to receive(:log)

      @batchinator.build_step('Doing a thing', heading: false) { }
    end

    it 'executes the given block' do
      executed = false

      @batchinator.build_step('Doing a thing') { executed = true }

      expect(executed).to eq(true)
    end
  end
end
