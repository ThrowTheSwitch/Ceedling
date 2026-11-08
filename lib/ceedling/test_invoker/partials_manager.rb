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
    :file_path_utils,
    :file_wrapper
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
  # A Partial whose implementation and interface are fresh is passed over without extraction.
  # Its staleness record depends on nothing extraction finds, so it is checked first. Each of
  # those two files vouches for the types header it includes. A Partial passed over still
  # joins its test's `testable.partials.tests`/`.mocks` lists, which stage 14 reads to decide
  # compile sources.
  #
  # Any other Partial is extracted and validated in full, and each file it generates is
  # written only where stale. Each of the three files is optional. A module with no types gets
  # no types header, and the implementation and interface each follow one side of the
  # selection. So each file has its own DependencyTracker target. One target shared by all
  # three, as stage 6's preprocessing passes share one, would never read back as fresh when a
  # file is legitimately never written.
  def stage_generate_partials(state)
    directives_only = @configurator.test_build_preprocess_directives_only_available

    partials = []
    state.testables.each do |_, testable|
      next if testable.partials.configs.empty?
      testable.partials.configs.each do |_, config|
        partials << { config: config, testable: testable }
      end
    end

    # How many of each kind of generated file were fresh and so left alone
    skipped = Hash.new( 0 )

    @batchinator.exec(workload: :compile, things: partials) do |partial|
      config   = partial[:config]
      testable = partial[:testable]
      name     = testable.name

      # Every input generation reads rides in the staleness record below, so a change to any of
      # them regenerates what the previous ones produced:
      #  - The preprocessed copies stages 6/7 wrote, beside the originals. Extraction parses the
      #    copies, so whatever rewrites them without touching the originals -- forced fallback
      #    toggled, a different preprocessor -- reaches this stage through them.
      #  - The test's selection, which decides what each generated file holds.
      #  - The real header's guard, spoofed deliberately in every generated file.
      #  - Each generated file's includes, which depend on the test's other Partial modules
      #    and how each is selected. The record's lists leave out the types header, since the
      #    module files the record holds decide whether one exists.
      antecedent_files     = partial_antecedent_files( config )
      module_include_guard = @partializer.extract_module_include_guard( config.header.filepath )
      # Generation's lists are the ones logged, so the record's are computed without a test name
      record_includes      = remap_partial_includes( config, testable.partials.configs, nil, nil )

      antecedent_meta  = {
        flags:        testable.preprocess_flags,
        defines:      testable.preprocess_defines,
        search_paths: testable.search_paths,
        # No shell tool runs in this stage -- Partial generation is pure Ruby (below) --
        # so there's nothing to add here beyond the whole :partials config.
        tools:        [],
        partials:     @configurator.get_partials_config,
        selection:    { tests: config.tests.to_h, mocks: config.mocks.to_h },
        include_guard: module_include_guard,
        types_includes:       record_includes[:types].map( &:to_s ),
        impl_header_includes: record_includes[:impl_header].map( &:to_s ),
        impl_source_includes: record_includes[:impl_source].map( &:to_s ),
        interface_includes:   record_includes[:interface].map( &:to_s )
      }

      record = { files: antecedent_files, meta: antecedent_meta, name: name, partial: config.module }
      paths  = partial_paths( config, testable )

      fresh = fresh_targets( config, paths, record )
      if fresh
        skip_fresh_partial( state, testable, config, fresh, skipped )
        next
      end

      module_contents = @partializer.extract_module_contents(
        name,
        config,
        fallback: !directives_only
      )

      @partializer.validate_config(
        c_module: module_contents, config: config, name: name, fallback: !directives_only
      )

      @partializer.sanitize( module_contents )

      # Generated once and shared by the implementation and interface headers below (via
      # their own includes lists), so a module tested and mocked in the same test file gets
      # exactly one C definition of each of its typedefs and aggregate types. A module with no
      # typedefs or aggregate definitions gets none, and one an earlier build left is removed.
      # The bare filename is computed the same deterministic way GeneratorPartials#generate_types
      # computes it, so the includes remapping below knows what to #include.
      types_header = nil
      if !module_contents.type_definitions.empty? || !module_contents.aggregate_definitions.empty?
        types_header = @file_path_utils.form_partial_types_header_filename( config.module )
      end
      discard_leftover_types( paths[:types] ) if types_header.nil?

      includes = remap_partial_includes( config, testable.partials.configs, types_header, name )

      # The implementation and interface include the types header, so each vouches for it
      types_target = types_header && paths[:types]

      if types_header
        unchanged = generate_when_stale( target: types_target, kind: :types, **record ) do
          @generator.generate_partial_types(
            name:          name,
            partial:       config.module,
            c_module:      module_contents,
            output_path:   testable.paths[:partials],
            includes:      includes[:types],
            include_guard: module_include_guard
          )
        end
        state.lock.synchronize { skipped[:types] += 1 } if unchanged
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

      unless implementation.nil?
        # The same call writes a header alongside the source, so the source vouches for it
        # as an output. A modified or deleted header then regenerates both.
        outputs   = [paths[:impl_header], types_target].compact
        unchanged = generate_when_stale( target: paths[:implementation], outputs: outputs, kind: :implementation, **record ) do
          # What the implementation source carries beyond the selection. Planned only when the
          # source regenerates, so its notices appear with that build.
          carry = @partializer.plan_carry(
            test:            name,
            partial:         config.module,
            c_module:        module_contents,
            impl:            implementation,
            interface:       interface,
            fallback:        !directives_only,
            header_guarded:  !module_include_guard.nil?,
            header_filepath: config.header.filepath,
            source_filepath: config.source.filepath
          )

          @generator.generate_partial_implementation(
            test:                     name,
            partial:                  config.module,
            function_definitions:     implementation,
            c_module:                 module_contents,
            header_includes:          includes[:impl_header],
            source_includes:          includes[:impl_source],
            output_path:              testable.paths[:partials],
            include_guard:            module_include_guard,
            carry:                    carry,
            suppress_redundant_decls: @configurator.partials_suppress_redundant_decls,
            extern_variables:         @configurator.partials_extern_variables
          )
        end

        state.lock.synchronize do
          skipped[:implementation] += 1 if unchanged
          testable.partials.tests << config.module
        end
      end

      unless interface.nil?
        unchanged = generate_when_stale( target: paths[:interface], outputs: [types_target].compact, kind: :interface, **record ) do
          @generator.generate_partial_interface(
            test:                  name,
            partial:               config.module,
            function_declarations: interface,
            includes:              includes[:interface],
            c_module:              module_contents,
            output_path:           testable.paths[:partials],
            include_guard:         module_include_guard
          )
        end

        state.lock.synchronize do
          skipped[:interface] += 1 if unchanged
          testable.partials.mocks << config.module
        end
      end
    end

    order_partials( partials.map { |partial| partial[:testable] }.uniq )

    log_skip_summary( task: "Partial types generation", count: skipped[:types], noun: "types headers" )
    log_skip_summary( task: "Partial implementation generation", count: skipped[:implementation], noun: "implementations" )
    log_skip_summary( task: "Partial interface generation", count: skipped[:interface], noun: "interfaces" )
  end

  private

  # Generates one Partial file when its record says it's stale, and logs the skip otherwise.
  # Returns true when generation was skipped, for the stage's summary.
  def generate_when_stale(target:, files:, meta:, kind:, name:, partial:, outputs: [])
    @dependinator.register( target, files: files, meta: meta, outputs: outputs )

    if @dependinator.stale?( target )
      yield
      @dependinator.mark_fresh( target )
      return false
    end

    log_generation_skip( kind, name, partial )
    return true
  end

  def log_generation_skip(kind, name, partial)
    msg = @reportinator.generate_module_progress(
      operation: "Skipping Partial #{kind} generation for", module_name: name, filename: partial
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS )
  end

  # Where each file a Partial generates lives
  def partial_paths(config, testable)
    dir = testable.paths[:partials]
    return {
      types:          File.join( dir, @file_path_utils.form_partial_types_header_filename( config.module ) ),
      implementation: File.join( dir, @file_path_utils.form_partial_implementation_source_filename( config.module ) ),
      impl_header:    File.join( dir, @file_path_utils.form_partial_implementation_header_filename( config.module ) ),
      interface:      File.join( dir, @file_path_utils.form_partial_interface_header_filename( config.module ) )
    }
  end

  # The files a fresh Partial would have generated, keyed by kind, or nil when the Partial must
  # be extracted. The implementation and interface decide, each vouching for the types header it
  # includes. A types header still on disk is registered too, so a full run's pruning keeps its
  # record.
  def fresh_targets(config, paths, record)
    targets  = checkable_targets( config, paths )
    vouching = targets.values_at( :implementation, :interface ).compact

    targets.each_value { |target| @dependinator.register( target, files: record[:files], meta: record[:meta] ) }
    return nil if vouching.empty? or vouching.any? { |target| @dependinator.stale?( target ) }

    return targets
  end

  # Each file a Partial generates that can be checked before extraction. The implementation and
  # interface follow the test's selection. Only extraction knows whether a types header is due,
  # so its file on disk stands in.
  def checkable_targets(config, paths)
    targets = {}
    targets[:types]          = paths[:types] if @file_wrapper.exist?( paths[:types] )
    targets[:implementation] = paths[:implementation] unless config.tests.type.nil?
    targets[:interface]      = paths[:interface] unless config.mocks.type.nil?
    return targets
  end

  # A fresh Partial needs only its bookkeeping. Each file it would have generated is logged and
  # counted as skipped, and the module joins its test's lists as generation would have added it.
  def skip_fresh_partial(state, testable, config, targets, skipped)
    targets.each_key { |kind| log_generation_skip( kind, testable.name, config.module ) }

    state.lock.synchronize do
      targets.each_key { |kind| skipped[kind] += 1 }
      join_partial_lists( testable.partials, config.module, targets.keys )
    end
  end

  # A module with no types gets no types header. One an earlier build left would otherwise pass
  # for current whenever the Partial is next found fresh.
  def discard_leftover_types(path)
    return unless @file_wrapper.exist?( path )

    @file_wrapper.rm_f( path )
    @dependinator.invalidate( path )
  end

  # A module joins the test's list for each side of its Partial that exists
  def join_partial_lists(partials, partial_module, kinds)
    partials.tests << partial_module if kinds.include?( :implementation )
    partials.mocks << partial_module if kinds.include?( :interface )
  end

  # A Partial's original header and source, and the preprocessed copies of each that extraction
  # parses. A declaration-only Partial (a prototype with no matching definition) has no source
  # file to find, leaving all three of its source paths legitimately nil -- compacted out before
  # they reach path normalization, which expects real paths only.
  def partial_antecedent_files(config)
    return [config.header, config.source].flat_map do |file|
      [file.filepath, file.directives_only_filepath, file.full_expansion_filepath]
    end.compact.uniq
  end

  # The includes of each file this module's Partial can generate, keyed by file. The impl and
  # interface headers carry the shared types header when the module has one.
  def remap_partial_includes(config, partials, types_header, test)
    common = { name: config.module, includes: config.source.includes + config.header.includes, partials: partials, test: test }

    return {
      types:       @partializer.remap_types_header_includes( **common ),
      impl_header: @partializer.remap_implementation_header_includes( **common, types_header: types_header ),
      impl_source: @partializer.remap_implementation_source_includes( **common ),
      interface:   @partializer.remap_interface_header_includes( **common, types_header: types_header )
    }
  end

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
  # Build threads finish in any order. Each test's Partial modules return to its configuration
  # order, which its link and mock lists follow, so an unchanged build sees unchanged lists.
  def order_partials(testables)
    testables.each do |testable|
      order = testable.partials.configs.values.map( &:module )
      testable.partials.tests.sort_by! { |_module| order.index( _module ) }
      testable.partials.mocks.sort_by! { |_module| order.index( _module ) }
    end
  end

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

      # A skipped run recalls the includes list and full expansion this run wrote, so the
      # preprocessed target vouches for both
      @dependinator.register(
        details.preprocessed_target,
        outputs: [
          @file_path_utils.form_preprocessed_includes_list_filepath( config.filepath, name ),
          @file_path_utils.form_preprocessed_file_full_expansion_filepath( config.filepath, name )
        ]
      )
      @dependinator.mark_fresh( details.preprocessed_target )
    end
  end

end
