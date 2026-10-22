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
# list, and its mock search paths narrow to the mocks that remain. An empty result never
# replaces a text scan that found #includes, and with neither pass to go on, the text scan
# stands as it is.
#
# In fallback the second pass's output is a plain expansion, so reconciling against it is
# a best effort. No dependency-tracker gate: this pass parses the second pass's
# already-gated output or does a cheap text scan, and reconciling is list merging.
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
      ingest( testable )
      narrow_mock_search_paths( state, testable )
    end
  end

  private

  # Reconciling to nothing while the text names #includes means preprocessing found none it
  # should have. Ingesting would replace the test's header and source #includes with that
  # nothing, so stage 2's list stands instead.
  def ingest(testable)
    return keep_text_scan( testable ) if nothing_preprocessed?( testable )

    includes = reconciled_includes( testable )
    return warn_of_text_scan( testable ) if includes.empty? && text_scanned?( testable )

    @loginator.log_list( includes, "Extracted reconciled #include list from #{testable.filepath}:", Verbosity::OBNOXIOUS )
    @context_extractor.ingest_includes( testable.filepath, includes )
  end

  # A test file's own #include of a mock is deliberate, so mocked headers are kept
  def reconciled_includes(testable)
    user, system = accurate_includes( testable )
    return @preprocessinator.reconcile_includes(
      bare: bare( testable ), user: user, system: system, test_filepath: testable.filepath, drop_mocked: false
    )
  end

  def text_scanned?(testable)
    return [:lookup_all_header_includes_list, :lookup_source_includes_list].any? do |lookup|
      !@context_extractor.public_send( lookup, testable.filepath ).empty?
    end
  end

  def warn_of_text_scan(testable)
    msg = "No #includes of #{testable.filepath} survived reconciliation, though its text names some. Using the text-scanned " \
          "#includes as a best effort. Rerun with --verbosity=obnoxious to see why preprocessing found none."
    @loginator.log( msg, Verbosity::COMPLAIN )
  end

  # GCC's list is empty and the second pass failed: GCC's run failed too, or every #include
  # sits in a branch that is off. Either way nothing is left to check the text scan against.
  def nothing_preprocessed?(testable)
    return testable.preprocess[:includes].empty? && preprocessed_filepath( testable ).nil?
  end

  # Stage 2's text-scan list stands, the Partial headers its configuration added included.
  # This is a best effort: mocks in branches that are off stay with it.
  def keep_text_scan(testable)
    log_module_progress( 'Using fallback text-only includes extracted for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING )
  end

  # The user and system #includes from the second pass's output, or from the text scan
  # when that pass failed for this file
  def accurate_includes(testable)
    preprocessed = preprocessed_filepath( testable )

    if preprocessed.nil?
      log_module_progress( 'Using fallback text-only includes extracted for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING )
      includes = @context_extractor.lookup_all_header_includes_list( testable.filepath )
      return [Includes.user( includes ), Includes.system( includes )]
    end

    log_module_progress( 'Reconciling #includes from best-effort fallback preprocessing for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING ) unless directives_only?
    args = { name: testable.name, filepath: testable.filepath, directives_only_filepath: preprocessed }
    return [@preprocessinator.preprocess_user_includes( **args ), @preprocessinator.preprocess_system_includes( **args )]
  end

  # With the second pass's output, the candidates plus the #includes a macro names, which
  # that output resolved. Without it, the text-scanned #includes stand in for the second
  # pass, and checking them against candidates holding those same #includes would keep
  # every one, mocks in branches that are off included. GCC's list alone still evaluated
  # those branches.
  def bare(testable)
    preprocessed = preprocessed_filepath( testable )
    return testable.preprocess[:includes] if preprocessed.nil?

    return @preprocessinator.supplement_with_computed_includes(
      filepath: testable.filepath, bare: testable.preprocess[:candidates], directives_only_filepath: preprocessed
    )
  end

  # The second pass's line-marker output, whichever way it ran, or nil when it failed for
  # this file
  def preprocessed_filepath(testable)
    return testable.preprocess[:directives_only][:filepath] || testable.preprocess.dig( :fallback_expansion, :filepath )
  end

  def directives_only?
    return @configurator.test_build_preprocess_directives_only_available
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
