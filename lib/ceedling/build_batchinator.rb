# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'benchmark'
require 'parallel'

class BuildBatchinator

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

    sum_elapsed = 0.0
    all_elapsed = Benchmark.realtime do
      workers = 1

      case workload
      when :compile
        workers = @configurator.project_compile_threads
      when :test
        workers = @configurator.project_test_threads
      else
        raise NameError.new("Unrecognized batch workload type: #{workload}")
      end

      sum_elapsed += Parallel.map(things, in_threads: workers) do |key, value| 
        Benchmark.realtime { job_block.call(key, value) }
      end.sum()
    end

    @loginator.lazy(Verbosity::OBNOXIOUS) do 
      "\nBatch Elapsed All: #{all_elapsed.to_s}\nBatch Elapsed Sum: #{sum_elapsed.to_s}\n"
    end
  end
end

