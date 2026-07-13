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
    :configurator,
    :test_build_setup,
    :test_build_planner,
    :test_build_executor,
    :plugin_manager,
    :batchinator,
    :loginator,
    :verbosinator
  )

  def setup
    @state = nil
  end

  # -------------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------------

  # Run the test-build pipeline for the given tests.
  #
  # options: — free-form hash forwarded to every pipeline stage as `state.options`.
  # Recognized keys (stages not listed read nothing from `options`):
  #   :build_only   — Boolean. Skip stage 17 (Executing) only. Compile and link
  #                   test executables but do not run them.
  #   :sources_only — Boolean. Skip stages 15-17 (Building Objects, Building Test
  #                   Executables, Executing). Runs only context-extraction/metadata
  #                   stages 1-14, enough to populate each testable's `.sources` —
  #                   i.e. no compiler, linker, or test fixture is invoked.
  #   :test_linker  — Tool config for stage 16 (Building Test Executables). Ignored
  #                   when :sources_only or :build_only skips that stage.
  #   :test_fixture — Tool config for stage 17 (Executing). Ignored when :sources_only
  #                   or :build_only skips that stage.
  # Other keys occasionally merged in by callers (e.g. :test_compiler, :force_run) are
  # currently not read by any pipeline stage; tool selection for compiling is instead
  # resolved per-context via the `pre_compile_execute` plugin hook.
  def setup_and_invoke(tests:, context: TEST_SYM, options: {})
    timestamp_s = SystemWrapper.time_stopwatch_s()
    @plugin_manager.pre_test_build( context, timestamp_s )

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
      run_pipeline( build_stage_sequence(), @state )
    rescue StandardError => ex
      @application.register_build_failure
      @loginator.log( ex.message, Verbosity::ERRORS, LogLabels::EXCEPTION )
      @loginator.log_debug_backtrace( ex )
    ensure
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

  # -------------------------------------------------------------------------
  # Pipeline infrastructure
  # -------------------------------------------------------------------------

  private

  def run_pipeline(stages, state)
    stages.each do |stage|
      next unless stage.run?( state )

      if stage.transform
        stage.body.call( state )
      else
        @batchinator.build_step( stage.name, heading: stage.heading ) do
          stage.body.call( state )
        end
      end
    end
  end

  def build_stage_sequence
    use_preprocessing = -> (s) { @configurator.project_use_test_preprocessor_tests }
    use_partials      = -> (s) { @configurator.project_use_partials }
    use_mocks         = -> (s) { @configurator.project_use_mocks }
    use_mocks_preproc = -> (s) { @configurator.project_use_mocks && @configurator.project_use_test_preprocessor_mocks }
    not_build_only    = -> (s) { !s.options[:build_only] }   # skip stage 17 only
    not_sources_only  = -> (s) { !s.options[:sources_only] } # skip stages 15-17

    [
      # Stage 1
      stage("Preparing Build Paths",
            heading: false,
            body: ->(s) { @test_build_setup.stage_prepare_build_paths(s) }
      ),

      # Stage 2
      stage("Collecting Essential Test Context",
            body: ->(s) { @test_build_setup.stage_collect_test_context(s) }
      ),

      # Stage 3
      stage("Ingesting Test Configurations",
            body: ->(s) { @test_build_setup.stage_ingest_configurations(s) }
      ),

      # Stage 4
      stage("Collecting More Test Context",
            condition: use_preprocessing,
            body: ->(s) { @test_build_setup.stage_collect_preprocessor_context(s) }
      ),

      # Stage 5
      stage("Determining Files to Be Generated",
            heading: false,
            body: ->(s) { @test_build_planner.stage_determine_files(s) }
      ),

      # Transform 1: Prepare partials parallel processing
      stage(transform: true,
            condition: use_partials,
            body: ->(s) { @test_build_planner.stage_flatten_partials_lists(s) }
      ),

      # Stage 6
      stage("Preprocessing for Testing & Mocking Partials",
            condition: use_partials,
            body: ->(s) { @test_build_executor.stage_preprocess_partial_headers(s) }
      ),

      # Stage 7
      stage("Preprocessing for Testing Partials",
            condition: use_partials,
            body: ->(s) { @test_build_executor.stage_preprocess_partial_sources(s) }
      ),

      # Stage 8
      stage("Partials",
            condition: use_partials,
            body: ->(s) { @test_build_executor.stage_generate_partials(s) }
      ),

      # Transform 2: Prepare mocks for parallel processing
      stage(transform: true,
            condition: use_mocks,
            body: ->(s) { @test_build_planner.stage_flatten_mocks_list(s) }
      ),

      # Stage 9
      stage("Preprocessing for Mocks",
            condition: use_mocks_preproc,
            body: ->(s) { @test_build_executor.stage_preprocess_mocks(s) }
      ),

      # Stage 10
      stage("Mocking",
            condition: use_mocks,
            body: ->(s) { @test_build_executor.stage_generate_mocks(s) }
      ),

      # Stage 11
      stage("Preprocessing Test Files",
            condition: use_preprocessing,
            body: ->(s) { @test_build_executor.stage_preprocess_test_files(s) }
      ),

      # Stage 12
      stage("Collecting More Test Context",
            condition: use_preprocessing,
            body: ->(s) { @test_build_executor.stage_collect_runner_details(s) }
      ),

      # Stage 13
      stage("Test Runners",
            body: ->(s) { @test_build_executor.stage_generate_runners(s) }
      ),

      # Stage 14
      stage("Determining Artifacts to Be Built",
            heading: false,
            body: ->(s) { @test_build_planner.stage_determine_artifacts(s) }
      ),

      # Transform 3: Prepare objects for parallel processing
      stage(transform: true,
            body: ->(s) { @test_build_planner.stage_flatten_objects_list(s) }
      ),

      # Stage 15 — skipped under :sources_only (no object compilation needed to
      # determine which sources a test references).
      stage("Building Objects",
            condition: not_sources_only,
            body: ->(s) { @test_build_executor.stage_build_objects(s) }
      ),

      # Stage 16 — skipped under :sources_only (no linking needed either).
      stage("Building Test Executables",
            condition: not_sources_only,
            body: ->(s) { @test_build_executor.stage_build_executables(s) }
      ),

      # Stage 17 — skipped under :build_only or :sources_only.
      stage("Executing",
            condition: ->(s) { not_build_only.call(s) && not_sources_only.call(s) },
            body: ->(s) { @test_build_executor.stage_execute(s) }
      ),
    ]
  end

  def stage(name = nil, heading: true, condition: nil, transform: false, body:)
    Stage.new(
      name:      name,
      heading:   heading,
      condition: condition,
      transform: transform,
      body:      body
    )
  end

end
