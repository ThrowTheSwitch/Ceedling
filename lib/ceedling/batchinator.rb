# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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

  # Parallelize work to be done:
  #  - Enqueue things (thread-safe)
  #  - Spin up a number of worker threads within constraints of project file config and amount of work
  #  - Each worker thread consumes one item from queue and runs the block against its details
  #  - When the queue is empty, the worker threads wind down
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

