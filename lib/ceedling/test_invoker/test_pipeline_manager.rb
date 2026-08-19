# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/test_invoker/test_invoker_types'

# Owns the test-build pipeline's shape: what stages exist, in what order, and
# which of `state.options` gates each one. `TestInvoker` owns everything
# around a run (state setup, dependency-cache lifecycle, plugin hooks,
# top-level error handling); this class owns the run itself.
class TestPipelineManager

  include TestInvokerTypes

  constructor(
    :test_build_setup,
    :test_build_planner,
    :test_build_executor,
    :configurator,
    :batchinator,
    :loginator,
    :reportinator
  )

  # `options:` (an Array of Symbols; see `TestInvoker#setup_and_invoke`) is a flat
  # collection of independent pipeline-control flags. Recognized symbols:
  #
  #   :mocking              — Stop the pipeline after stage 10 (Mocking). Skips
  #                           stages 11-17 (test-file preprocessing, runner details/
  #                           generation, artifact determination, object compilation,
  #                           linking, execution).
  #   :test_runner          — Stop the pipeline after stage 13 (Test Runners). Skips
  #                           stages 14-17 (artifact determination, object compilation,
  #                           linking, execution).
  #   :build_only           — Skip stage 17 (Executing) only. Compile and link test
  #                           executables but do not run them.
  #   :sources_only         — Skip stages 15-17 (Building Objects, Building Test
  #                           Executables, Executing). Runs only context-extraction/
  #                           metadata stages 1-14, enough to populate each testable's
  #                           `.sources` -- i.e. no compiler, linker, or test fixture
  #                           is invoked.
  #   :refresh_dependencies — Read by `TestInvoker`, not by any stage here. Included
  #                           for completeness: permits the dependency cache to prune
  #                           entries for targets this run didn't touch.
  #
  # `:mocking`, `:test_runner`, `:sources_only`, and `:build_only` each name a single,
  # different point at which the pipeline stops -- supplying more than one at once is
  # ambiguous and rejected by `validate_stop_point_options!` below.
  STOP_POINT_OPTIONS = %i[mocking test_runner sources_only build_only].freeze unless const_defined?(:STOP_POINT_OPTIONS, false)

  # Read alongside STOP_POINT_OPTIONS above -- named per stop point so a mocks-only or
  # runners-only run's quieter console output (fewer stage headings, no pass/fail
  # summary) is never mistaken for a truncated or broken full test build.
  STOP_POINT_ANNOUNCEMENTS = {
    mocking:      "Generating mocks only -- no test runners, compiling, linking, or running.",
    test_runner:  "Generating mocks and test runners only -- no compiling, linking, or running.",
    build_only:   "Building test executables only -- not running them.",
    sources_only: "Determining test sources only -- no generating, compiling, linking, or running.",
  }.freeze unless const_defined?(:STOP_POINT_ANNOUNCEMENTS, false)

  # Read alongside STOP_POINT_ANNOUNCEMENTS above -- header text for each stop point's
  # own final completion banner (see announce_completion), so a mocks-only or
  # runners-only run ends with a clear, deliberate signal of its own, the same way a
  # full test run ends with its own "OVERALL TEST SUMMARY" banner.
  STOP_POINT_BANNERS = {
    mocking:      'MOCKS GENERATED',
    test_runner:  'MOCKS & TEST RUNNERS GENERATED',
    build_only:   'TEST EXECUTABLES BUILT',
    sources_only: 'TEST SOURCES DETERMINED',
  }.freeze unless const_defined?(:STOP_POINT_BANNERS, false)

  # Validates `state.options`, then builds and runs the stage sequence against `state`.
  def run(state)
    validate_stop_point_options!( state.options )
    announce_run_scope( state.options )

    build_stage_sequence().each do |stage|
      next unless stage.enabled?( state )

      if stage.empty?( state )
        @loginator.log( "#{stage.name}: #{stage.empty_notice}", Verbosity::OBNOXIOUS )
        next
      end

      if stage.transform
        stage.body.call( state )
      else
        @batchinator.build_step( stage.name, heading: stage.heading ) do
          stage.body.call( state )
        end
      end
    end

    announce_completion( state.options )
  end

  private

  def validate_stop_point_options!(options)
    conflicts = STOP_POINT_OPTIONS.select { |key| options.include?( key ) }
    return if conflicts.size <= 1

    named = conflicts.map { |key| ":#{key}" }.join(', ')
    raise CeedlingException.new(
      "Pipeline options #{named} each stop the test-build pipeline at a different " \
      "point -- specify at most one of #{STOP_POINT_OPTIONS.map { |k| ":#{k}" }.join(', ')}."
    )
  end

  # Silent for an ordinary full test build (no stop-point option present) -- only a
  # partial run announces itself, so the announcement's mere presence is itself the
  # signal something less than a full build is happening.
  def announce_run_scope(options)
    stop_point = STOP_POINT_OPTIONS.find { |key| options.include?( key ) }
    return if stop_point.nil?

    @loginator.log( STOP_POINT_ANNOUNCEMENTS[stop_point], Verbosity::NORMAL, LogLabels::NOTICE )
  end

  # A specific final step, mirroring how a full test run's own "OVERALL TEST SUMMARY"
  # banner is generated (ReportTestsStdoutPlugin, via this identical
  # Reportinator#generate_banner) -- silent for a full test build, whose own
  # results banner covers that case through its own, separate mechanism.
  def announce_completion(options)
    stop_point = STOP_POINT_OPTIONS.find { |key| options.include?( key ) }
    return if stop_point.nil?

    header = @loginator.decorate( STOP_POINT_BANNERS[stop_point], LogLabels::BUILT )
    banner = @reportinator.generate_banner( header )
    @loginator.log( "\n" + banner, Verbosity::NORMAL, LogLabels::NONE )
  end

  def build_stage_sequence
    use_preprocessing = -> (s) { @configurator.project_use_test_preprocessor_tests }
    use_partials      = -> (s) { @configurator.project_use_partials }
    use_mocks         = -> (s) { @configurator.project_use_mocks }
    use_mocks_preproc = -> (s) { @configurator.project_use_mocks && @configurator.project_use_test_preprocessor_mocks }
    not_mocking       = -> (s) { !s.options.include?(:mocking) }       # skip stages 11-17 (stop after stage 10)
    not_test_runner   = -> (s) { !s.options.include?(:test_runner) }   # skip stages 14-17 (stop after stage 13)
    not_build_only    = -> (s) { !s.options.include?(:build_only) }    # skip stage 17 only
    not_sources_only  = -> (s) { !s.options.include?(:sources_only) }  # skip stages 15-17

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
            condition:       use_partials,
            empty_condition: ->(s) { s.partials_headers.empty? },
            empty_notice:    "no Partials to process",
            body: ->(s) { @test_build_executor.stage_preprocess_partial_headers(s) }
      ),

      # Stage 7
      stage("Preprocessing for Testing Partials",
            condition:       use_partials,
            empty_condition: ->(s) { s.partials_sources.empty? },
            empty_notice:    "no Partials to process",
            body: ->(s) { @test_build_executor.stage_preprocess_partial_sources(s) }
      ),

      # Stage 8
      stage("Partials",
            condition:       use_partials,
            empty_condition: ->(s) { s.partials_headers.empty? && s.partials_sources.empty? },
            empty_notice:    "no Partials to generate",
            body: ->(s) { @test_build_executor.stage_generate_partials(s) }
      ),

      # Transform 2: Prepare mocks for parallel processing
      stage(transform: true,
            condition: use_mocks,
            body: ->(s) { @test_build_planner.stage_flatten_mocks_list(s) }
      ),

      # Stage 9
      stage("Preprocessing for Mocks",
            condition:       use_mocks_preproc,
            empty_condition: ->(s) { s.mocks_list.empty? },
            empty_notice:    "no mocks to process",
            body: ->(s) { @test_build_executor.stage_preprocess_mocks(s) }
      ),

      # Stage 10 — the :mocking stop point runs through here, then halts.
      stage("Mocking",
            condition:       use_mocks,
            empty_condition: ->(s) { s.mocks_list.empty? },
            empty_notice:    "no mocks to generate",
            body: ->(s) { @test_build_executor.stage_generate_mocks(s) }
      ),

      # Stage 11 — skipped under :mocking.
      stage("Preprocessing Test Files",
            condition: ->(s) { use_preprocessing.call(s) && not_mocking.call(s) },
            body: ->(s) { @test_build_executor.stage_preprocess_test_files(s) }
      ),

      # Stage 12 — skipped under :mocking.
      stage("Collecting More Test Context",
            condition: ->(s) { use_preprocessing.call(s) && not_mocking.call(s) },
            body: ->(s) { @test_build_executor.stage_collect_runner_details(s) }
      ),

      # Stage 13 — skipped under :mocking. The :test_runner stop point runs
      # through here, then halts.
      stage("Test Runners",
            condition: not_mocking,
            body: ->(s) { @test_build_executor.stage_generate_runners(s) }
      ),

      # Stage 14 — skipped under :mocking or :test_runner.
      stage("Determining Artifacts to Be Built",
            heading: false,
            condition: ->(s) { not_mocking.call(s) && not_test_runner.call(s) },
            body: ->(s) { @test_build_planner.stage_determine_artifacts(s) }
      ),

      # Transform 3: Prepare objects for parallel processing — skipped under
      # :mocking or :test_runner.
      stage(transform: true,
            condition: ->(s) { not_mocking.call(s) && not_test_runner.call(s) },
            body: ->(s) { @test_build_planner.stage_flatten_objects_list(s) }
      ),

      # Stage 15 — skipped under :mocking, :test_runner, or :sources_only
      # (no object compilation needed to determine which sources a test references).
      stage("Building Objects",
            condition: ->(s) { not_mocking.call(s) && not_test_runner.call(s) && not_sources_only.call(s) },
            body: ->(s) { @test_build_executor.stage_build_objects(s) }
      ),

      # Stage 16 — skipped under :mocking, :test_runner, or :sources_only
      # (no linking needed either).
      stage("Building Test Executables",
            condition: ->(s) { not_mocking.call(s) && not_test_runner.call(s) && not_sources_only.call(s) },
            body: ->(s) { @test_build_executor.stage_build_executables(s) }
      ),

      # Stage 17 — skipped under :mocking, :test_runner, :build_only, or :sources_only.
      stage("Executing",
            condition: ->(s) {
              not_mocking.call(s) && not_test_runner.call(s) &&
                not_build_only.call(s) && not_sources_only.call(s)
            },
            body: ->(s) { @test_build_executor.stage_execute(s) }
      ),
    ]
  end

  def stage(name = nil, heading: true, condition: nil, empty_condition: nil, empty_notice: nil, transform: false, body:)
    Stage.new(
      name:            name,
      heading:         heading,
      condition:       condition,
      empty_condition: empty_condition,
      empty_notice:    empty_notice,
      transform:       transform,
      body:            body
    )
  end

end
