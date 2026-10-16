# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stage 4's third pass. The second pass's #includes, checked against the first pass's
# candidates and the #includes a macro names, replace each test file's stored text-scan
# list, and its mock search paths narrow to the mocks that remain.
#
# No dependency-tracker gate: it parses the second pass's already-gated output or does a
# cheap text scan, and reconciling is list merging. Without directives-only support,
# nothing is reconciled, and the text-scan list stays in place.
class TestIncludesReconcilinator

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :test_context_extractor,
    :preprocessinator,
    :test_search_paths,
    :mock_locator
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  def reconcile(state)
    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      unless @configurator.test_build_preprocess_directives_only_available
        log_module_progress( 'Using fallback text-only includes extracted for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING )
        next
      end

      ingest( testable )
      narrow_mock_search_paths( state, testable )
    end
  end

  private

  # A test file's own #include of a mock is deliberate, so mocked headers are kept
  def ingest(testable)
    user, system = accurate_includes( testable )
    includes = @preprocessinator.reconcile_includes(
      bare: bare( testable ), user: user, system: system, test_filepath: testable.filepath, drop_mocked: false
    )

    @loginator.log_list( includes, "Extracted reconciled #include list from #{testable.filepath}:", Verbosity::OBNOXIOUS )
    @context_extractor.ingest_includes( testable.filepath, includes )
  end

  # The user and system #includes from the second pass's output, or from the text scan
  # when that pass failed for this file
  def accurate_includes(testable)
    directives_only_filepath = testable.preprocess[:directives_only][:filepath]

    if directives_only_filepath.nil?
      log_module_progress( 'Using fallback text-only includes extracted for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING )
      includes = @context_extractor.lookup_all_header_includes_list( testable.filepath )
      return [Includes.user( includes ), Includes.system( includes )]
    end

    args = { name: testable.name, filepath: testable.filepath, directives_only_filepath: directives_only_filepath }
    return [@preprocessinator.preprocess_user_includes( **args ), @preprocessinator.preprocess_system_includes( **args )]
  end

  # With directives-only output, the candidates plus the #includes a macro names, which
  # that output resolved. Without it, the text-scanned #includes stand in for the second
  # pass, and checking them against candidates holding those same #includes would keep
  # every one, mocks in branches that are off included. GCC's list alone still evaluated
  # those branches.
  def bare(testable)
    directives_only_filepath = testable.preprocess[:directives_only][:filepath]
    return testable.preprocess[:includes] if directives_only_filepath.nil?

    return @preprocessinator.supplement_with_computed_includes(
      filepath: testable.filepath, bare: testable.preprocess[:candidates], directives_only_filepath: directives_only_filepath
    )
  end

  # The candidates' mock directories served the second pass. Once reconciled, only the
  # mocks that remain need a search path. A remaining mock whose header is missing or
  # mis-cased is reported by stage 5, which resolves every mock strictly.
  def narrow_mock_search_paths(state, testable)
    return if testable.paths[:mocks].nil?

    mock_dirs = @mock_locator.directories(
      @context_extractor.lookup_mock_header_includes_list( testable.filepath ),
      mocks_root: testable.paths[:mocks],
      collection: @mock_locator.header_collection( testable.search_paths, testable.mock_search_paths ),
      complain:   :silent
    )
    @test_search_paths.assign_mock_search_paths( testable, mock_dirs, state.lock )
  end

end
