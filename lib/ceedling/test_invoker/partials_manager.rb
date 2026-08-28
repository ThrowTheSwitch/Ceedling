# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

class PartialsManager

  include TestPipelineHelpers

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :batchinator,
    :preprocessinator,
    :partializer,
    :generator,
    :dependinator,
    :file_path_utils
  )

  # Stage 6: Preprocess partial header files for extract-and-generate pass.
  def stage_preprocess_partial_headers(state)
    preprocess_partials(
      items:                  state.partials_headers,
      kind:                   'header',
      noun:                   'headers',
      preserve_macros_method: :preprocess_partial_header_file_preserve_macros,
      expand_macros_method:   :preprocess_partial_header_expand_macros
    )
  end

  # Stage 7: Preprocess partial source files for extract-and-generate pass.
  def stage_preprocess_partial_sources(state)
    preprocess_partials(
      items:                  state.partials_sources,
      kind:                   'source',
      noun:                   'sources',
      preserve_macros_method: :preprocess_partial_source_file_preserve_macros,
      expand_macros_method:   :preprocess_partial_source_expand_macros
    )
  end

  # Stage 8: Extract and generate partial implementation and interface files.
  #
  # Extraction and validation below always run in full, for every partial, every
  # invocation -- pure in-memory C parsing from whatever `config` already holds,
  # cheap regardless of whether stages 6/7 did real preprocessing work or recalled
  # it. `testable.partials.tests`/`.mocks` are rebuilt from that in-memory result
  # every run too, since stage 14 reads those lists to decide compile sources
  # regardless of whether anything on disk actually changed.
  #
  # The three disk writes below -- types header, implementation, interface -- are
  # each independently optional (a module with no type/aggregate defs never gets
  # a types header at all; implementation/interface are separately gated on
  # extraction succeeding) and each gets its own DependencyTracker target rather
  # than one combined target the way stage 6's three preprocessing passes share
  # one: a target that's sometimes legitimately never written would never read
  # back as fresh.
  def stage_generate_partials(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available

    partials = []
    state.testables.each do |_, testable|
      next if testable.partials.configs.empty?
      testable.partials.configs.each do |_, config|
        partials << { config: config, testable: testable }
      end
    end

    skipped_types      = 0
    skipped_impl       = 0
    skipped_interface  = 0

    @batchinator.exec(workload: :compile, things: partials) do |partial|
      config   = partial[:config]
      testable = partial[:testable]
      name     = testable.name

      module_contents = @partializer.extract_module_contents(
        name,
        config,
        fallback: !directives_only
      )

      @partializer.validate_config( c_module: module_contents, config: config, name: name )

      @partializer.sanitize( module_contents )

      # Antecedents mirror stages 6/7's own targets for this same module's header/source --
      # Partial generation's actual inputs (the preprocessed content those stages produce or
      # recall) are already fully covered by the same file+flags/defines/search_paths.
      # A declaration-only Partial (a prototype with no matching definition) has no source
      # file to find, leaving config.source.filepath legitimately nil -- compact it out
      # before it reaches path normalization, which expects real paths only.
      antecedent_files = [config.header.filepath, config.source.filepath].compact
      antecedent_meta  = {
        flags:        testable.preprocess_flags,
        defines:      testable.preprocess_defines,
        search_paths: testable.search_paths,
        # No shell tool runs in this stage -- Partial generation is pure Ruby (below) --
        # so there's nothing to add here beyond the whole :partials config.
        tools:        [],
        partials:     @configurator.get_partials_config
      }

      # Generated once and shared by the implementation and interface headers below (via
      # their own includes lists), so a module tested and mocked in the same test file gets
      # exactly one C definition of each of its typedefs and aggregate types. Nothing to
      # write (and therefore nothing to track) when the module has no typedefs or aggregate
      # definitions -- recompute the bare filename the same deterministic way
      # GeneratorPartials#generate_types would have, purely so the includes-remapping below
      # still knows what to #include.
      types_header = nil
      if !module_contents.type_definitions.empty? || !module_contents.aggregate_definitions.empty?
        types_header = @file_path_utils.form_partial_types_header_filename( config.module )
        target       = File.join( testable.paths[:partials], types_header )

        @dependinator.register( target, files: antecedent_files, meta: antecedent_meta )

        if @dependinator.stale?( target )
          @generator.generate_partial_types(
            name:        name,
            partial:     config.module,
            c_module:    module_contents,
            output_path: testable.paths[:partials]
          )
          @dependinator.mark_fresh( target )
        else
          msg = @reportinator.generate_module_progress(
            operation:   'Skipping Partial types generation for',
            module_name: name,
            filename:    config.module
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )
          state.lock.synchronize { skipped_types += 1 }
        end
      end

      implementation = @partializer.extract_implementation_functions(
        test:        name,
        partial:     config.module,
        definitions: module_contents.function_definitions,
        config:      config
      )

      interface = @partializer.extract_interface_functions(
        test:         name,
        partial:      config.module,
        definitions:  module_contents.function_definitions,
        declarations: module_contents.function_declarations,
        config:       config
      )

      @partializer.validate_extracted_functions(
        name:      name,
        partial:   config.module,
        impl:      implementation,
        interface: interface
      )

      arg_hash = {
        test:                 name,
        partial:              config.module,
        function_definitions: implementation,
        c_module:             module_contents,
        header_includes:      @partializer.remap_implementation_header_includes(
                                name:         config.module,
                                includes:     (config.source.includes + config.header.includes),
                                partials:     testable.partials.configs,
                                types_header: types_header,
                                test:         name
                              ),
        source_includes:      @partializer.remap_implementation_source_includes(
                                name:     config.module,
                                includes: (config.source.includes + config.header.includes),
                                partials: testable.partials.configs,
                                test:     name
                              ),
        input_filepath:       config.source.filepath,
        output_path:          testable.paths[:partials]
      }

      unless implementation.nil?
        # The header this same call writes alongside the source isn't itself an
        # antecedent -- tracking it too catches an externally modified/deleted header
        # even when the source's own antecedents look unchanged.
        target        = File.join( testable.paths[:partials], @file_path_utils.form_partial_implementation_source_filename( config.module ) )
        header_target = File.join( testable.paths[:partials], @file_path_utils.form_partial_implementation_header_filename( config.module ) )

        @dependinator.register( target, files: antecedent_files + [header_target], meta: antecedent_meta )

        if @dependinator.stale?( target )
          @generator.generate_partial_implementation( **arg_hash )
          @dependinator.mark_fresh( target )
        else
          msg = @reportinator.generate_module_progress(
            operation:   'Skipping Partial implementation generation for',
            module_name: name,
            filename:    config.module
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )
          state.lock.synchronize { skipped_impl += 1 }
        end

        state.lock.synchronize { testable.partials.tests << config.module }
      end

      arg_hash = {
        test:                  name,
        partial:               config.module,
        function_declarations: interface,
        includes:              @partializer.remap_interface_header_includes(
                                 name:         config.module,
                                 includes:     (config.source.includes + config.header.includes),
                                 partials:     testable.partials.configs,
                                 types_header: types_header,
                                 test:         name
                               ),
        c_module:              module_contents,
        input_filepath:        config.header.filepath,
        output_path:           testable.paths[:partials]
      }

      unless interface.nil?
        target = File.join( testable.paths[:partials], @file_path_utils.form_partial_interface_header_filename( config.module ) )

        @dependinator.register( target, files: antecedent_files, meta: antecedent_meta )

        if @dependinator.stale?( target )
          @generator.generate_partial_interface( **arg_hash )
          @dependinator.mark_fresh( target )
        else
          msg = @reportinator.generate_module_progress(
            operation:   'Skipping Partial interface generation for',
            module_name: name,
            filename:    config.module
          )
          @loginator.log( msg, Verbosity::OBNOXIOUS )
          state.lock.synchronize { skipped_interface += 1 }
        end

        state.lock.synchronize { testable.partials.mocks << config.module }
      end
    end

    log_skip_summary( task: "Partial types generation", count: skipped_types, noun: "types headers" )
    log_skip_summary( task: "Partial implementation generation", count: skipped_impl, noun: "implementations" )
    log_skip_summary( task: "Partial interface generation", count: skipped_interface, noun: "interfaces" )
  end

  private

  # Shared body for stages 6 and 7 -- a partial's header and source files go through
  # identical preprocessing, differing only in which of `state.partials_headers`/
  # `state.partials_sources` supplies the work and which Preprocessinator methods
  # `kind` (a header or a source) is actually preprocessed by.
  #
  # A partial file's three preprocessing passes below (directives-only generation,
  # preserve-macros preprocessing, full-expansion) all derive from the same
  # antecedent file and the same preprocess flags/defines/search paths, so they're
  # stale or fresh together as a single unit -- one DependencyTracker target per
  # file per test covers all three.
  #
  # Settling every target's staleness in its own sequential pass first (cheap, no
  # subprocess work) is what lets the three parallel batches below each just check
  # `details.stale` instead of duplicating the register/stale? call three times
  # over. On a stale target, all three passes run and populate `config` as they do
  # today. On a fresh target, the two preprocessed output filepaths are recomputed
  # the same deterministic way the preprocessor methods themselves compute them,
  # and `config.includes` is recalled from the on-disk list a prior stale run wrote
  # -- so `config` ends up populated identically either way, and stage 8 (which
  # reads only `config`) needs no knowledge of which path produced it.
  def preprocess_partials(items:, kind:, noun:, preserve_macros_method:, expand_macros_method:)
    directives_only = @configurator.test_build_preprocess_directives_only_available
    skipped = 0

    items.each do |details|
      config   = details.config
      testable = details.testable
      name     = testable.name

      target = @file_path_utils.form_preprocessed_file_filepath( config.filepath, name )

      @dependinator.register(
        target,
        files: [config.filepath],
        meta:  dependency_meta(
          flags: testable.preprocess_flags, defines: testable.preprocess_defines, search_paths: testable.search_paths,
          tools: [
            @configurator.tools_test_file_directives_only_preprocessor,
            @configurator.tools_test_bare_includes_preprocessor,
            @configurator.tools_test_file_full_preprocessor
          ],
          partials: @configurator.get_partials_config
        )
      )

      details.preprocessed_target = target
      details.stale               = @dependinator.stale?( target )

      if details.stale
        msg = @reportinator.generate_module_progress(
          operation:   "Preprocessing partial #{kind} for",
          module_name: name,
          filename:    File.basename( config.filepath )
        )
        @loginator.log( msg )
      else
        msg = @reportinator.generate_module_progress(
          operation:   "Skipping partial #{kind} preprocessing for",
          module_name: name,
          filename:    File.basename( config.filepath )
        )
        @loginator.log( msg, Verbosity::OBNOXIOUS )
        skipped += 1

        config.directives_only_filepath = target
        config.includes                 = @preprocessinator.load_includes_list( test: name, filepath: config.filepath )
        config.full_expansion_filepath  = @file_path_utils.form_preprocessed_file_full_expansion_filepath( config.filepath, name )
      end
    end

    log_skip_summary( task: "partial #{kind} preprocessing", count: skipped, noun: noun )

    # Generate directive-only preprocessor output if available
    @batchinator.exec(workload: :compile, things: items) do |details|
      next unless details.stale

      config   = details.config
      testable = details.testable
      name     = testable.name

      arg_hash = {
        filepath:      config.filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  vendor_search_paths(),
        defines:       testable.preprocess_defines
      }

      details.directives_only_filepath = @preprocessinator.generate_directives_only_output( **arg_hash )
    end if directives_only

    # Preprocess and assemble files
    @batchinator.exec(workload: :compile, things: items) do |details|
      next unless details.stale

      config                   = details.config
      testable                 = details.testable
      name                     = testable.name
      directives_only_filepath = details.directives_only_filepath

      arg_hash = {
        test:                     name,
        filepath:                 config.filepath,
        directives_only_filepath: directives_only_filepath,
        fallback:                 directives_only_fallback?( directives_only, directives_only_filepath ),
        flags:                    testable.preprocess_flags,
        include_paths:            testable.search_paths,
        vendor_paths:             vendor_search_paths(),
        defines:                  testable.preprocess_defines
      }

      config.directives_only_filepath, config.includes = @preprocessinator.public_send( preserve_macros_method, **arg_hash )
    end

    # Full-preprocess files for expanded signature extraction.
    @batchinator.exec(workload: :compile, things: items) do |details|
      next unless details.stale

      config   = details.config
      testable = details.testable
      name     = testable.name

      arg_hash = {
        filepath:      config.filepath,
        test:          name,
        flags:         testable.preprocess_flags,
        include_paths: testable.search_paths,
        vendor_paths:  vendor_search_paths(),
        defines:       testable.preprocess_defines
      }

      config.full_expansion_filepath = @preprocessinator.public_send( expand_macros_method, **arg_hash )

      @dependinator.mark_fresh( details.preprocessed_target )
    end
  end

end
