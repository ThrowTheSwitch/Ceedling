# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_context_extractor'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stage 11: each test file, preprocessed for the steps after it. The preprocessed file is
# the runner's input, from which stage 12 parses test case names, and its
# TEST_SOURCE_FILE() directives are scanned once it is written.
#
# When the preprocessed file is already current, its directives are recalled from a
# small cache instead of being scanned again. That cache is an output of the
# preprocessed target, so a damaged cache makes the target stale.
#
# The preprocessed file comes from a full expansion that reads every header the test
# reaches, so the project files that expansion entered are registered as its
# dependencies, as a compile registers its .d file. Editing a header that enables a test
# case then reruns this stage and, through the runner's own dependencies, stage 13.
class TestFilePreprocessinator

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :preprocessinator,
    :test_context_extractor,
    :file_path_utils,
    :file_wrapper,
    :dependinator,
    :test_source_file_directive_resolver
  )

  def setup()
    @context_extractor = @test_context_extractor
  end

  def preprocess(state)
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      stale = preprocess_test_file( state, testable )
      state.lock.synchronize { skipped += 1 } unless stale

      stale ? scan_source_directives( testable ) : recall_source_directives( testable )
      state.testables.each_value { |each| @test_source_file_directive_resolver.validate!( test: testable.name, filepath: each.filepath ) }
    end

    log_skip_summary( task: "test file preprocessing", count: skipped, noun: "test files" )
  end

  private

  # The preprocessed path is deterministic, so it can be registered and checked before
  # deciding whether to preprocess. Gives whether the test file was preprocessed.
  def preprocess_test_file(state, testable)
    target = target( testable )
    @dependinator.register( target, files: [testable.filepath], meta: preprocess_meta( testable ) )
    register_preprocessed_dependencies( target, expansion( testable ) ) if @file_wrapper.exist?( expansion( testable ) )
    stale = @dependinator.stale?( target )

    input = stale ? preprocess_now( testable ) : recall( testable, target )
    state.lock.synchronize { testable.runner.input_filepath = input }

    return stale
  end

  def target(testable)
    return @file_path_utils.form_preprocessed_file_filepath( testable.filepath, testable.name )
  end

  def expansion(testable)
    return @file_path_utils.form_preprocessed_file_full_expansion_filepath( testable.filepath, testable.name )
  end

  def preprocess_meta(testable)
    return dependency_meta( flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths )
  end

  def preprocess_now(testable)
    return @preprocessinator.preprocess_test_file(
      test: testable.name, filepath: testable.filepath, directives_only_filepath: directives_only_filepath( testable ),
      fallback: fallback?( testable ), includes: @context_extractor.lookup_all_header_includes_list( testable.filepath ),
      flags: testable.preprocess_flags, include_paths: testable.search_paths, vendor_paths: vendor_search_paths(),
      defines: testable.preprocess_defines
    )
  end

  def recall(testable, target)
    log_module_progress( 'Skipping test file preprocessing for', testable, Verbosity::OBNOXIOUS )
    return target
  end

  def directives_only_filepath(testable)
    return testable.preprocess[:directives_only][:filepath]
  end

  def fallback?(testable)
    return directives_only_fallback?( @configurator.test_build_preprocess_directives_only_available, directives_only_filepath( testable ) )
  end

  def source_files_cache(testable)
    return @file_path_utils.form_preprocessed_source_files_cache_filepath( testable.filepath, testable.name )
  end

  # The cache is recalled whenever the preprocessed file is fresh, so that file vouches
  # for it. Marking fresh only once the cache is written leaves the target stale if
  # directive parsing raises.
  def scan_source_directives(testable)
    filename = File.basename( testable.filepath )
    @loginator.log( @reportinator.generate_progress( "Parsing #{filename} for test source directive macros" ) )

    @context_extractor.collect_simple_context_from_file( directives_source( testable ), testable.filepath, TestContextExtractor::Context::BUILD_DIRECTIVE_SOURCE_FILES )
    @context_extractor.store_build_directives_cache( filepath: testable.filepath, cache_filepath: source_files_cache( testable ) )

    mark_fresh( testable )
  end

  # The preprocessed file vouches for the directive cache and depends on what its
  # expansion read
  def mark_fresh(testable)
    @dependinator.register( target( testable ), outputs: [source_files_cache( testable )] )
    register_preprocessed_dependencies( target( testable ), expansion( testable ) )
    @dependinator.mark_fresh( target( testable ) )
  end

  # Directives are scanned from the compacted directives-only output, or from the test
  # file itself without one
  def directives_source(testable)
    return testable.filepath if fallback?( testable )

    return @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( testable.filepath, testable.name )
  end

  def recall_source_directives(testable)
    filename = File.basename( testable.filepath )
    @loginator.log( @reportinator.generate_progress( "Recalling cached source directive macros for #{filename}" ), Verbosity::OBNOXIOUS )
    @context_extractor.load_build_directives_cache( filepath: testable.filepath, cache_filepath: source_files_cache( testable ) )
  end

end
