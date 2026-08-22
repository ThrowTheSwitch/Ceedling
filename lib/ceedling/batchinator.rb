# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Batchinator is Ceedling's one chokepoint for parallel work. Every worker
# thread the build spins up, for compiling or for running tests, passes
# through here. Keeping that in one small file makes the parallel handling
# easy to find and easy to reason about, instead of scattered thread-pool
# code wherever a build step happens to need parallelism.
#
# Actually running things in parallel is handled by the `parallel` gem.
# Batchinator's job is just the Ceedling-specific parts on top: picking a
# worker count from project configuration, and reporting timing.

require 'benchmark'
require 'parallel'

class Batchinator

  constructor :configurator, :loginator, :reportinator

  def setup
    @queue = Queue.new
  end

  # Neaten up a build step with progress message and some scope encapsulation
  def build_step(msg, heading: true, &block)
    if heading
      msg = @reportinator.generate_heading( @loginator.decorate( msg, LogLabels::RUN ) )
    else # Progress message
      msg = "\n" + @reportinator.generate_progress( @loginator.decorate( msg, LogLabels::RUN ) )
    end

    @loginator.log( msg )

    yield # Execute build step block
  end

  # Run a block once per item in `things`, spread across worker threads.
  #
  # `workload:` picks how many worker threads to use. Compiling and running
  # tests are configured with independent thread counts (`:project ↳
  # :compile_threads` and `:project ↳ :test_threads`), since the two
  # workloads have different performance characteristics and a project may
  # want to tune them separately. `workload:` says which of the two
  # settings applies to this call.
  #
  # `things:` is whatever collection of work items needs processing. It can
  # be a plain Array (`job_block` receives one item, e.g. `|object|`) or a
  # Hash (`job_block` receives a key/value pair, e.g. `|name, testable|`).
  # Both work through the same `|key, value|` block signature below because
  # of two ordinary Ruby behaviors, not anything Batchinator does itself:
  # the `parallel` gem converts any `things` collection to an Array of
  # items first, and Ruby auto-splats a 2-element Array item (a Hash pair)
  # into two block parameters. A plain Array item just becomes `key`, with
  # `value` left `nil`.
  #
  # Thread safety is the caller's responsibility, not Batchinator's.
  # `job_block` runs concurrently on multiple threads. If it reads or
  # writes anything shared across those calls (a counter, an entry in a
  # shared results object), that access needs its own synchronization,
  # typically a `Mutex` the caller owns and passes in via closure. Nothing
  # about calling `exec` makes shared state safe on its own.
  #
  # If `job_block` raises, already-running items keep running to
  # completion. No new items start once an exception has been seen. Once
  # every thread is done, the first exception raised is re-raised here, in
  # the calling thread. This is the `parallel` gem's own default behavior
  # for thread-based work, not something Batchinator changes.
  def exec(workload:, things:, &job_block)

    batch_results = []
    sum_elapsed = 0.0

    all_elapsed = Benchmark.realtime do
      # Determine number of worker threads to run
      workers = 1
      case workload
      when :compile
        workers = @configurator.project_compile_threads
      when :test
        workers = @configurator.project_test_threads
      else
        raise NameError.new("Unrecognized batch workload type: #{workload}")
      end

      # Perform the actual parallelized work and collect the results and timing
      batch_results = Parallel.map(things, in_threads: workers) do |key, value| 
        this_results = ''
        this_elapsed = Benchmark.realtime { this_results = job_block.call(key, value) }
        [this_results, this_elapsed]
      end

      # Separate the elapsed time and results
      if batch_results.size > 0
        batch_results, batch_elapsed = batch_results.transpose
        sum_elapsed = batch_elapsed.sum()
      end
    end

    # Report the timing if requested
    @loginator.lazy(Verbosity::OBNOXIOUS) do 
      "\nBatch Elapsed: (All: %.3fsec Sum: %.3fsec)\n" % [all_elapsed, sum_elapsed]
    end

    batch_results
  end
end

