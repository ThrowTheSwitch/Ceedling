# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stage 4's second pass. GCC preprocesses each test file with -fdirectives-only, using
# its full search paths, following its #includes through the stand-ins into the headers
# they name. The output records which #includes came from the test file itself.
#
# The output depends on every file it read, a mocked header through its stand-in among
# them, so those files are registered as its dependencies, as a compile registers its .d
# file. The pass runs only where the preprocessor supports -fdirectives-only.
class TestDirectivesOnlyPreprocessinator

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :preprocessinator,
    :file_path_utils,
    :file_wrapper,
    :dependinator
  )

  def preprocess(state)
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      target = register( testable )
      stale  = @dependinator.stale?( target )

      testable.preprocess[:directives_only][:filepath] = stale ? generate( testable, target ) : recall( testable, target )
      state.lock.synchronize { skipped += 1 } unless stale
    end

    log_skip_summary( task: "directives-only preprocessing", count: skipped, noun: "test files" )
  end

  private

  # The raw output path is deterministic, so it can be registered and checked before
  # deciding whether to run the preprocessor at all
  def register(testable)
    target = @file_path_utils.form_preprocessed_file_raw_directives_only_filepath( testable.filepath, testable.name )
    meta   = dependency_meta(
      flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
      tools: [@configurator.tools_test_file_directives_only_preprocessor]
    )

    @dependinator.register( target, files: [testable.filepath], meta: meta )
    register_dependencies( target ) if @file_wrapper.exist?( target )

    return target
  end

  # The project files an output entered. Files below the build root, such as stand-ins
  # and the mocks that replace them, are generated from those project files and would
  # only ever look changed.
  def register_dependencies(target)
    build_root = File.join( @configurator.project_build_root, '' )
    files      = @preprocessinator.directives_only_dependencies( directives_only_filepath: target )

    @dependinator.register( target, files: files.reject { |file| file.start_with?( build_root ) } )
  end

  def recall(testable, target)
    log_module_progress( 'Skipping directives-only preprocessing for', testable, Verbosity::OBNOXIOUS )
    return target
  end

  # Gives the raw output's path, or nil when the preprocessor failed. A failure writes
  # nothing to mark fresh, so the next run tries again. The same run also writes a
  # compacted file, which the raw target vouches for as an output.
  def generate(testable, target)
    log_module_progress( 'Preprocessing test files for follow-on details extraction steps', testable, Verbosity::OBNOXIOUS )

    output = @preprocessinator.generate_directives_only_output(
      filepath: testable.filepath, test: testable.name, flags: testable.preprocess_flags,
      include_paths: testable.search_paths, vendor_paths: vendor_search_paths(), defines: testable.preprocess_defines
    )
    mark_fresh( testable, target ) unless output.nil?

    return output
  end

  def mark_fresh(testable, target)
    compacted = @file_path_utils.form_preprocessed_file_compacted_directives_only_filepath( testable.filepath, testable.name )
    @dependinator.register( target, outputs: [compacted] )
    register_dependencies( target )
    @dependinator.mark_fresh( target )
  end

end
