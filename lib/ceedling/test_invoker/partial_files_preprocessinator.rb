# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stages 6 and 7. Each Partial header (stage 6) and source (stage 7) is preprocessed in one
# job, and each job's three runs feed a later step:
#  1. A -fdirectives-only run keeps macros and records every file it entered. It is
#     skipped in fallback, without -fdirectives-only.
#  2. A bare-includes run, checked against that output or in fallback the file's own
#     text, yields the reconciled #includes. The assembled copy extraction parses follows.
#  3. A full expansion shows what a macro hides. Its own lines are what reconciliation
#     parses.
#
# The job's target is the assembled copy. Its dependencies are the file itself and every
# project header the full expansion entered, so editing a macro in any of them reruns
# the job. A job whose expansion fails is left stale, and its expansion is gone, so the
# next run tries again rather than reading an earlier run's expansion.
#
# A fresh job's record is rebuilt from the files its last run left. Each run either
# leaves a file or removes it, so a file's presence says what that run produced.
class PartialFilesPreprocessinator

  include TestPipelineHelpers

  # How each stage names the files it preprocesses
  NOUNS = { header: 'headers', source: 'sources' }.freeze

  # The tools a job runs, each of which shapes its outputs
  TOOLS = %i[tools_test_file_directives_only_preprocessor tools_test_bare_includes_preprocessor tools_test_file_full_preprocessor].freeze

  # Where each file a job reads or writes lives
  PATHS = {
    target:              :form_preprocessed_file_filepath,
    raw_directives_only: :form_preprocessed_file_raw_directives_only_filepath,
    raw_expansion:       :form_preprocessed_file_full_expansion_filepath,
    expanded_code:       :form_preprocessed_file_expanded_code_filepath,
    includes_list:       :form_preprocessed_includes_list_filepath
  }.freeze

  constructor :configurator, :loginator, :reportinator, :batchinator, :preprocessinator, :file_path_utils, :file_wrapper,
              :dependinator

  # Stage 6
  def preprocess_headers(state)
    preprocess( state, state.partials_headers, :header )
  end

  # Stage 7
  def preprocess_sources(state)
    preprocess( state, state.partials_sources, :source )
  end

  private

  def preprocess(state, items, kind)
    skipped = 0

    @batchinator.exec( workload: :compile, things: items ) do |work|
      target = register( work )
      next generate( work, target, kind ) if stale?( work, target )

      recall( work, target, kind )
      state.lock.synchronize { skipped += 1 }
    end

    log_skip_summary( task: "partial #{kind} preprocessing", count: skipped, noun: NOUNS[kind] )
  end

  # The target path is deterministic, so it is registered and checked before any run.
  # The previous run's expansion names the headers it entered, which this run's staleness
  # depends on too.
  def register(work)
    testable = work.testable
    target   = path( work, :target )
    meta     = dependency_meta(
      flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
      tools: TOOLS.map { |tool| @configurator.public_send( tool ) }, partials: @configurator.get_partials_config
    )

    @dependinator.register( target, files: [work.config.filepath], meta: meta )

    raw_expansion = path( work, :raw_expansion )
    register_preprocessed_dependencies( target, raw_expansion ) if @file_wrapper.exist?( raw_expansion )

    return target
  end

  # A record written before the expanded code was an output doesn't vouch for it, and
  # reconciliation needs that file
  def stale?(work, target)
    return (@dependinator.stale?( target ) or !@file_wrapper.exist?( path( work, :expanded_code ) ))
  end

  def generate(work, target, kind)
    config = work.config
    log_progress( "Preprocessing partial #{kind} for", work )

    run = { filepath: config.filepath, test: work.testable.name, **tool_args( work.testable ) }

    assemble( work, kind, run )
    config.expansion_filepath     = @preprocessinator.generate_partial_expansion( **run )
    config.raw_expansion_filepath = config.expansion_filepath && path( work, :raw_expansion )

    mark_fresh( work, target ) unless config.expansion_filepath.nil?
  end

  # The directives-only run, then the assembled copy built from its output. A run with no
  # directives-only output removes an earlier one, so a raw copy on disk means this file
  # was preprocessed accurately.
  def assemble(work, kind, run)
    config = work.config

    raw = directives_only? ? @preprocessinator.generate_directives_only_output( **run ) : nil
    @file_wrapper.rm_f( path( work, :raw_directives_only ) ) if raw.nil?

    config.raw_directives_only_filepath = raw
    config.fallback                     = directives_only_fallback?( directives_only?, raw )

    config.assembled_filepath, config.includes = @preprocessinator.preprocess_partial_file(
      kind: kind, directives_only_filepath: raw, fallback: config.fallback, **run
    )
  end

  # Every file a later build trusts is an output, so a missing or edited one makes the job stale
  def mark_fresh(work, target)
    config  = work.config
    outputs = [path( work, :includes_list ), config.raw_directives_only_filepath, config.raw_expansion_filepath, config.expansion_filepath]

    @dependinator.register( target, outputs: outputs.compact )
    register_preprocessed_dependencies( target, config.raw_expansion_filepath )
    @dependinator.mark_fresh( target )
  end

  # A fresh job's record, from the files its last run left. The raw copy alone says whether
  # that run was accurate, whatever this run's toolchain supports.
  def recall(work, target, kind)
    log_progress( "Skipping partial #{kind} preprocessing for", work, Verbosity::OBNOXIOUS )

    raw = present( work, :raw_directives_only )
    fill(
      work.config, raw_directives_only_filepath: raw, fallback: raw.nil?, assembled_filepath: target,
      includes: @preprocessinator.load_includes_list( test: work.testable.name, filepath: work.config.filepath ),
      raw_expansion_filepath: present( work, :raw_expansion ), expansion_filepath: path( work, :expanded_code )
    )
  end

  def fill(config, **fields)
    fields.each { |field, value| config[field] = value }
  end

  def tool_args(testable)
    return { flags: testable.preprocess_flags, include_paths: testable.search_paths, vendor_paths: vendor_search_paths(), defines: testable.preprocess_defines }
  end

  # Settled per run, since the configurator learns of directives-only support after this
  # object is built
  def directives_only?
    return @configurator.test_build_preprocess_directives_only_available
  end

  def path(work, kind)
    return @file_path_utils.public_send( PATHS[kind], work.config.filepath, work.testable.name )
  end

  def present(work, kind)
    file = path( work, kind )
    return @file_wrapper.exist?( file ) ? file : nil
  end

  # A Partial's progress names its own file rather than the test's
  def log_progress(operation, work, verbosity = Verbosity::NORMAL)
    msg = @reportinator.generate_module_progress( operation: operation, module_name: work.testable.name, filename: File.basename( work.config.filepath ) )
    @loginator.log( msg, verbosity )
  end

end
