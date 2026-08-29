# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_invoker_types'

class TestInvoker

  include TestInvokerTypes

  # -------------------------------------------------------------------------
  # Dependency injection
  # -------------------------------------------------------------------------

  constructor(
    :application,
    :plugin_manager,
    :dependinator,
    :loginator,
    :verbosinator,
    :test_pipeline_manager
  )

  def setup
    @state = nil
  end

  # -------------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------------

  # Runs the test-build pipeline for the given tests. `options:` is a flat Array of
  # Symbols controlling pipeline behavior -- see TestPipelineManager for the full set
  # of recognized flags and their effect on the stage sequence.
  def setup_and_invoke(tests:, context: TEST_SYM, options: [])
    timestamp_s = SystemWrapper.time_stopwatch_s()
    @plugin_manager.pre_test_build( context, timestamp_s )

    # `identifier: context` isolates this run's own cache file (see Dependinator#open) --
    # a plugin building its own variant of the test pipeline under a distinct context
    # (:gcov, :valgrind, ...) gets its own cache automatically, never sharing one with
    # ordinary :test runs (or another plugin's context) and never exposed to a full
    # :test run's own pruning flush evicting its entries.
    @dependinator.open( identifier: context )

    @state = PipelineState.new(
      tests:            tests,
      testables:        {},
      context:          context,
      options:          options,
      partials_headers: [],
      partials_sources: [],
      mocks_list:       [],
      objects_list:     [],
      lock:             Mutex.new
    )

    begin
      @test_pipeline_manager.run( @state )
    rescue StandardError => ex
      @application.register_build_failure
      @loginator.log( ex.message, Verbosity::ERRORS, LogLabels::EXCEPTION )
      @loginator.log_debug_backtrace( ex )
    ensure
      @dependinator.flush( refresh_dependencies: options.include?(:refresh_dependencies) )
      @plugin_manager.post_test_build( context, SystemWrapper.time_stopwatch_s() )
    end
  end

  def each_test_with_sources
    @state.testables.each do |test, _|
      yield( test.to_s, lookup_sources( test: test ) )
    end
  end

  def lookup_sources(test:)
    return @state.testables[test.to_sym].sources
  end

end
