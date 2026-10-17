# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stages 12 and 13: each test's Unity runner. Stage 12 parses test case names from the
# preprocessed test file, and stage 13 generates the runner from them and the test's
# mock and include lists.
#
# Both stages check the one runner target, registered the same way. Test case names
# exist only to feed the runner, so stage 12 does nothing when the runner is current.
# Registration accumulates, and only stage 13 marks the target fresh.
#
# The runner depends on what it is generated from: the test file, the input file its
# test case names are parsed from (the preprocessed test file, with test preprocessing),
# and the test's mock and include lists. Those lists come from stage 4's reconciliation
# with test preprocessing, so they can change while the test file doesn't, as when a
# header's macro decides which mocks a test has.
class TestRunnerGeneratinator

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :generator,
    :test_context_extractor,
    :dependinator
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  # Stage 12
  def collect_details(state)
    each_stale( state, task: "test case name parsing", noun: "test files", skip: 'Skipping test case name parsing for' ) do |testable|
      log_module_progress( 'Parsing test case names', testable )
      @context_extractor.collect_test_runner_details( testable.filepath, testable.runner.input_filepath )
    end
  end

  # Stage 13
  def generate(state)
    each_stale( state, task: "test runner generation", noun: "test runners", skip: 'Skipping test runner generation for' ) do |testable|
      generate_runner( state, testable )
    end
  end

  private

  # Yields each test whose runner is stale, logging each one skipped and a summary
  def each_stale(state, task:, noun:, skip:)
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      next yield( testable ) if stale?( testable )

      log_module_progress( skip, testable, Verbosity::OBNOXIOUS )
      state.lock.synchronize { skipped += 1 }
    end

    log_skip_summary( task: task, count: skipped, noun: noun )
  end

  def stale?(testable)
    files = [testable.filepath, testable.runner.input_filepath].uniq
    @dependinator.register( testable.runner.output_filepath, files: files, meta: runner_meta( testable ) )
    return @dependinator.stale?( testable.runner.output_filepath )
  end

  def generate_runner(state, testable)
    @generator.generate_test_runner(
      context:         state.context,
      mocks:           @context_extractor.lookup_mock_header_includes_list( testable.filepath ),
      includes:        @context_extractor.lookup_nonmock_header_includes_list( testable.filepath ),
      test_filepath:   testable.filepath,
      input_filepath:  testable.runner.input_filepath,
      runner_filepath: testable.runner.output_filepath
    )
    @dependinator.mark_fresh( testable.runner.output_filepath )
  end

  # The real runner and Unity configuration, not project_config_hash's flattened
  # sections, which never hold :test_runner or :unity. Whether test files are
  # preprocessed decides where test case names come from, so toggling it alone must
  # invalidate the runner. The mock and include lists are the runner's #includes.
  def runner_meta(testable)
    return {
      test_runner:             @configurator.get_runner_config,
      unity:                   @configurator.get_unity_config,
      test_preprocessor_tests: @configurator.project_use_test_preprocessor_tests,
      mocks:                   @context_extractor.lookup_mock_header_includes_list( testable.filepath ).map( &:filepath ),
      includes:                @context_extractor.lookup_nonmock_header_includes_list( testable.filepath ).map( &:filepath )
    }
  end

end
