# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stage 4's first pass. GCC lists the #includes it reaches in an isolated copy of each
# test file, a list cached between runs. The test file's literal #includes are added as
# candidates, as they are for a mockable header, since the isolated copy can't see a
# macro another header defines. Stand-ins are placed for the candidates' mocks and
# Partials, and the mock search paths are set from them.
class TestBareIncludesExtractinator

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :preprocessinator,
    :file_path_utils,
    :dependinator,
    :test_search_paths,
    :standin_headerinator
  )

  # The list is needed right away for stand-ins and again by reconciliation, so a cache
  # hit recalls it rather than leaving it on disk
  def collect(state)
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      cached = !stale?( testable )
      testable.preprocess[:includes] = cached ? recall( testable ) : extract( testable )
      state.lock.synchronize { skipped += 1 } if cached

      add_candidates( testable )
      place_standins( state, testable )
    end

    log_skip_summary( task: "#include extraction", count: skipped, noun: "test files" )
  end

  private

  def target(testable)
    return @file_path_utils.form_preprocessed_includes_list_filepath( testable.filepath, testable.name )
  end

  # The isolated copy reads nothing but the test file, so the test file and the
  # preprocessor's settings are all the list depends on
  def stale?(testable)
    meta = dependency_meta(
      flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
      tools: [@configurator.tools_test_bare_includes_preprocessor]
    )
    @dependinator.register( target( testable ), files: [testable.filepath], meta: meta )

    return @dependinator.stale?( target( testable ) )
  end

  # A failed run says nothing about the file, so its empty stand-in isn't cached and the
  # next run tries again. Meanwhile the text scan alone makes the candidates.
  def extract(testable)
    log_module_progress( 'Extracting #includes from', testable )

    includes = @preprocessinator.preprocess_bare_includes(
      test: testable.name, filepath: testable.filepath, search_paths: vendor_search_paths(),
      flags: testable.preprocess_flags, defines: testable.preprocess_defines
    )
    return [] if includes.nil?

    cache( testable, includes )
    return includes
  end

  def cache(testable, includes)
    @preprocessinator.store_includes_list( test: testable.name, filepath: testable.filepath, includes: includes )
    @dependinator.mark_fresh( target( testable ) )
  end

  def recall(testable)
    log_module_progress( 'Skipping preprocessing for #includes in favor of cached #includes for', testable, Verbosity::OBNOXIOUS )

    return @preprocessinator.load_includes_list( test: testable.name, filepath: testable.filepath )
  end

  def add_candidates(testable)
    testable.preprocess[:candidates] = @preprocessinator.supplement_with_text_includes(
      filepath: testable.filepath, bare: testable.preprocess[:includes]
    )
  end

  # A cached list says nothing about whether its stand-ins survived, so they are placed
  # either way. Reconciliation draws only from the candidates, so their mocks cover every
  # mock the build uses, and the second pass needs their directories to find the
  # stand-ins.
  #
  # A literal #include may sit in a branch that is off, naming a mock whose header
  # doesn't exist or matches one only in letter case, so a mock only the text scan found
  # gets no stand-in without an exact header, and nothing is said. A mock on GCC's list
  # must have its header.
  def place_standins(state, testable)
    bare    = testable.preprocess[:includes]
    literal = testable.preprocess[:candidates].reject { |include| bare.any? { |each| each.filepath == include.filepath } }

    mock_dirs  = @standin_headerinator.place( testable, bare )
    mock_dirs += @standin_headerinator.place( testable, literal, complain: :silent )
    @test_search_paths.assign_mock_search_paths( testable, mock_dirs.uniq, state.lock )
  end

end
