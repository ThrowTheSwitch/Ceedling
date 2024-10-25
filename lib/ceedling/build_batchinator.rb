# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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
  def exec(workload:, things:, &block)
    workers = 0

    case workload
    when :compile
      workers = @configurator.project_compile_threads
    when :test
      workers = @configurator.project_test_threads
    else
      raise NameError.new("Unrecognized batch workload type: #{workload}")
    end

    # Enqueue all the items the block will execute against
    things.each { |thing| @queue << thing }

    # Choose lesser of max workers or number of things to process & redefine workers
    # (It's neater and more efficient to avoid workers we won't use)
    workers = [workers, things.size].min

    threads = (1..workers).collect do
      thread = Thread.new do
        Thread.handle_interrupt(Exception => :never) do
          begin
            Thread.handle_interrupt(Exception => :immediate) do
              # Run tasks until there are no more enqueued
              loop do
                # pop(true) is non-blocking and raises ThreadError when queue is empty
                yield @queue.pop(true)
              end
            end

          # First, handle thread exceptions (should always be due to empty queue)
          rescue ThreadError => e
            # Typical case: do nothing and allow thread to wind down

            # ThreadError outside scope of expected empty queue condition
            unless e.message.strip.casecmp("queue empty")
              # Shutdown all worker threads
              shutdown_threads(threads) 
              # Raise exception again after intervening
              raise(e)
            end

          # Second, catch every other kind of exception so we can intervene with thread cleanup.
          # Generally speaking, catching Exception is a no-no, but we must in this case.
          # Raise the exception again so that:
          #  1. Calling code knows something bad happened and handles appropriately
          #  2. Ruby runtime can handle most serious problems
          rescue Exception => e
            # Shutdown all worker threads
            shutdown_threads(threads) 
            # Raise exception again after intervening
            raise(e)
          end
        end
      end

      # Hand thread to Enumerable collect() routine
      thread.abort_on_exception = true
      thread
    end

    # Hand worker threads to scheduler / wait for them to finish
    threads.each { |thread| thread.join }
  end

  ### Private ###

  private

  # Terminate worker threads other than ourselves (we're already winding down)
  def shutdown_threads(workers)
    workers.each do |thread|
      next if thread == Thread.current
      thread.terminate
    end
  end

end

