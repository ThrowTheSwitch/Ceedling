# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stage 4's second pass. The preprocessor runs over each test file with its full search
# paths, following its #includes through the stand-ins into the headers they name. The
# output's line markers record which #includes came from the test file itself.
#
# With -fdirectives-only, the output also keeps macros, and a compacted copy serves stage
# 11. Without it, in fallback, a plain expansion stands in. Its line markers carry the same
# record, but fallback is best effort: a file that fails to expand in full is left to its
# text-scan #includes, checked against GCC's bare list.
#
# The output depends on every file it read, a mocked header through its stand-in among
# them, so those files are registered as its dependencies, as a compile registers its .d
# file.
class TestIncludesPreprocessinator

  include TestPipelineHelpers

  # What differs between the pass's two ways of running: where its output goes and what
  # makes it, the testable key that records it, and any further output it vouches for
  MODES = {
    directives_only: {
      noun: 'directives-only', key: :directives_only, tool: :tools_test_file_directives_only_preprocessor,
      target: :form_preprocessed_file_raw_directives_only_filepath, generate: :generate_directives_only_output,
      outputs: [:form_preprocessed_file_compacted_directives_only_filepath]
    },
    fallback: {
      noun: 'fallback', key: :fallback_expansion, tool: :tools_test_file_full_preprocessor,
      target: :form_preprocessed_file_fallback_expansion_filepath, generate: :generate_fallback_expansion_output,
      outputs: []
    }
  }.freeze

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
    mode    = current_mode()
    skipped = 0

    @batchinator.exec( workload: :compile, things: state.testables ) do |_, testable|
      target = register( testable, mode )
      stale  = @dependinator.stale?( target )

      testable.preprocess[mode[:key]][:filepath] = stale ? generate( testable, target, mode ) : recall( testable, target, mode )
      state.lock.synchronize { skipped += 1 } unless stale
    end

    log_skip_summary( task: "#{mode[:noun]} preprocessing", count: skipped, noun: "test files" )
  end

  private

  # Chosen per run, since the configurator settles directives-only support after this
  # object is built
  def current_mode
    return MODES[@configurator.test_build_preprocess_directives_only_available ? :directives_only : :fallback]
  end

  # The output path is deterministic, so it can be registered and checked before deciding
  # whether to run the preprocessor at all
  def register(testable, mode)
    target = @file_path_utils.public_send( mode[:target], testable.filepath, testable.name )
    meta   = dependency_meta(
      flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
      tools: [@configurator.public_send( mode[:tool] )]
    )

    @dependinator.register( target, files: [testable.filepath], meta: meta )
    register_preprocessed_dependencies( target, target ) if @file_wrapper.exist?( target )

    return target
  end

  def recall(testable, target, mode)
    log_module_progress( "Skipping #{mode[:noun]} preprocessing for", testable, Verbosity::OBNOXIOUS )
    return target
  end

  # Gives the output's path, or nil when the preprocessor failed. A failure writes nothing
  # to mark fresh, so the next run tries again.
  def generate(testable, target, mode)
    log_module_progress( 'Preprocessing test files for follow-on details extraction steps', testable, Verbosity::OBNOXIOUS )

    output = @preprocessinator.public_send(
      mode[:generate], filepath: testable.filepath, test: testable.name, flags: testable.preprocess_flags,
      include_paths: testable.search_paths, vendor_paths: vendor_search_paths(), defines: testable.preprocess_defines
    )
    mark_fresh( testable, target, mode ) unless output.nil?

    return output
  end

  # Any further file the same run wrote is registered as an output, so the target vouches for it
  def mark_fresh(testable, target, mode)
    outputs = mode[:outputs].map { |builder| @file_path_utils.public_send( builder, testable.filepath, testable.name ) }
    @dependinator.register( target, outputs: outputs ) unless outputs.empty?
    register_preprocessed_dependencies( target, target )
    @dependinator.mark_fresh( target )
  end

end
