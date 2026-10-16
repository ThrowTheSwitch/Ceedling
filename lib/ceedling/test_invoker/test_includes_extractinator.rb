# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stage 4: a test file's #includes, from the real preprocessor. Stage 2's text scan
# reads every #include as written; this stage replaces that list with what the
# preprocessor found, in three passes that build on each other.
#
# 1. Bare includes: GCC lists the #includes it reaches in an isolated copy of the test
#    file. The list is cached between runs, and stand-ins are placed for its mocks and
#    Partials.
# 2. Directives-only: GCC preprocesses the test file, following its #includes, which
#    records which of them came from the test file itself.
# 3. Reconciliation: the second pass's #includes, checked against the first pass's
#    list, replace the stored text-scan list.
#
# Each of the first two passes runs a real preprocessor and is skipped when the
# dependency tracker reports nothing relevant changed. Without directives-only support,
# only the first pass runs, and the text-scan list stays in place.
class TestIncludesExtractinator

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :test_context_extractor,
    :preprocessinator,
    :file_path_utils,
    :dependinator,
    :test_search_paths,
    :standin_headerinator
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  def stage_collect_preprocessor_context(state)
    collect_bare_includes( state )
    generate_directives_only_output( state ) if directives_only?
    reconcile_includes( state )
  end

  private

  def directives_only?
    return @configurator.test_build_preprocess_directives_only_available
  end

  ### First pass: bare includes

  # The list is needed right away for stand-ins and again by reconciliation, so a cache
  # hit recalls it rather than leaving it on disk.
  def collect_bare_includes(state)
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      if bare_includes_stale?( testable )
        testable.preprocess[:includes] = extract_bare_includes( testable )
      else
        testable.preprocess[:includes] = recall_bare_includes( testable )
        state.lock.synchronize { skipped += 1 }
      end

      place_standins( state, testable )
    end

    log_skip_summary( task: "#include extraction", count: skipped, noun: "test files" )
  end

  def bare_includes_stale?(testable)
    target = @file_path_utils.form_preprocessed_includes_list_filepath( testable.filepath, testable.name )

    @dependinator.register(
      target,
      files: [testable.filepath],
      meta:  dependency_meta(
        flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
        tools: [@configurator.tools_test_bare_includes_preprocessor]
      )
    )

    return @dependinator.stale?( target )
  end

  def extract_bare_includes(testable)
    log_progress( 'Extracting #includes from', testable )

    includes = @preprocessinator.preprocess_bare_includes(
      test:         testable.name,
      filepath:     testable.filepath,
      search_paths: vendor_search_paths(),
      flags:        testable.preprocess_flags,
      defines:      testable.preprocess_defines
    )

    @preprocessinator.store_includes_list( test: testable.name, filepath: testable.filepath, includes: includes )
    @dependinator.mark_fresh( @file_path_utils.form_preprocessed_includes_list_filepath( testable.filepath, testable.name ) )

    return includes
  end

  def recall_bare_includes(testable)
    log_progress( 'Skipping preprocessing for #includes in favor of cached #includes for', testable, Verbosity::OBNOXIOUS )

    return @preprocessinator.load_includes_list( test: testable.name, filepath: testable.filepath )
  end

  # A cached list says nothing about whether its stand-ins survived, so they are placed
  # either way. Reconciliation draws only from this list, so where it runs, this list's
  # mocks are the ones the build uses, and the second pass needs their directories to
  # find the stand-ins just placed.
  def place_standins(state, testable)
    mock_dirs = @standin_headerinator.place( testable, testable.preprocess[:includes] )
    return unless directives_only?

    paths = @test_search_paths.compose( testable.filepath, testable.paths, mock_dirs )
    state.lock.synchronize do
      testable.mock_search_paths = mock_dirs
      testable.search_paths      = paths
    end
  end

  ### Second pass: directives-only output

  def generate_directives_only_output(state)
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      target = directives_only_target( testable )

      if @dependinator.stale?( target )
        testable.preprocess[:directives_only][:filepath] = preprocess_directives_only( testable, target )
      else
        log_progress( 'Skipping directives-only preprocessing for', testable, Verbosity::OBNOXIOUS )
        testable.preprocess[:directives_only][:filepath] = target
        state.lock.synchronize { skipped += 1 }
      end
    end

    log_skip_summary( task: "directives-only preprocessing", count: skipped, noun: "test files" )
  end

  # The raw output path is deterministic, so it can be registered and checked before
  # deciding whether to run the preprocessor at all
  def directives_only_target(testable)
    target = @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( testable.filepath, testable.name )

    @dependinator.register(
      target,
      files: [testable.filepath],
      meta:  dependency_meta(
        flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
        tools: [@configurator.tools_test_file_directives_only_preprocessor]
      )
    )

    return target
  end

  # Gives the raw output's path, or nil when the preprocessor failed. A failure writes
  # nothing to mark fresh, so the next run tries again. The same run also writes a
  # compacted file, which the raw target vouches for as an output.
  def preprocess_directives_only(testable, target)
    log_progress( 'Preprocessing test files for follow-on details extraction steps', testable, Verbosity::OBNOXIOUS )

    filepath = @preprocessinator.generate_directives_only_output(
      filepath:      testable.filepath,
      test:          testable.name,
      flags:         testable.preprocess_flags,
      include_paths: testable.search_paths,
      vendor_paths:  vendor_search_paths(),
      defines:       testable.preprocess_defines
    )
    return nil if filepath.nil?

    compacted = @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( testable.filepath, testable.name )
    @dependinator.register( target, outputs: [compacted] )
    @dependinator.mark_fresh( target )

    return filepath
  end

  ### Third pass: reconciliation

  # No dependency-tracker gate: it parses the second pass's already-gated output or does
  # a cheap text scan, and reconciling is list merging
  def reconcile_includes(state)
    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      unless directives_only?
        log_progress( 'Using fallback text-only includes extracted for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING )
        next
      end

      user, system = accurate_includes( testable )

      # A test file's own #include of a mock is deliberate, so mocked headers are kept
      includes = @preprocessinator.reconcile_includes(
        bare:          testable.preprocess[:includes],
        user:          user,
        system:        system,
        test_filepath: testable.filepath,
        drop_mocked:   false
      )

      @loginator.log_list( includes, "Extracted reconciled #include list from #{testable.filepath}:", Verbosity::OBNOXIOUS )
      @context_extractor.ingest_includes( testable.filepath, includes )
    end
  end

  # The user and system #includes from the second pass's output, or from the text scan
  # when that pass failed for this file
  def accurate_includes(testable)
    directives_only_filepath = testable.preprocess[:directives_only][:filepath]

    if directives_only_filepath.nil?
      log_progress( 'Using fallback text-only includes extracted for', testable, Verbosity::OBNOXIOUS, LogLabels::WARNING )
      includes = @context_extractor.lookup_all_header_includes_list( testable.filepath )
      return [Includes.user( includes ), Includes.system( includes )]
    end

    args = { name: testable.name, filepath: testable.filepath, directives_only_filepath: directives_only_filepath }
    return [@preprocessinator.preprocess_user_includes( **args ), @preprocessinator.preprocess_system_includes( **args )]
  end

  def log_progress(operation, testable, verbosity = Verbosity::NORMAL, label = LogLabels::AUTO)
    msg = @reportinator.generate_module_progress(
      operation:   operation,
      module_name: testable.name,
      filename:    File.basename( testable.filepath )
    )
    @loginator.log( msg, verbosity, label )
  end

end
