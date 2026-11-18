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
    :partializer,
    :generator,
    :dependinator,
    :file_path_utils,
    :file_wrapper,
    :mock_locator
  )

  # Stage 8: Extract and generate partial implementation and interface files.
  #
  # A Partial whose implementation and interface are fresh is passed over without extraction.
  # Its staleness record depends on nothing extraction finds, so it is checked first. Each of
  # those two files vouches for the types header it includes. A Partial passed over still
  # joins its test's `testable.partials.tests`/`.mocks` lists. Stage 14 reads `.tests` to decide
  # compile sources.
  #
  # Any other Partial is extracted and validated in full, and each file it generates is
  # written only where stale. Each of the three files is optional. A module with no types gets
  # no types header, and the implementation and interface each follow one side of the
  # selection. So each file has its own DependencyTracker target. One target shared by all
  # three, as stage 6's preprocessing passes share one, would never read back as fresh when a
  # file is legitimately never written.
  def stage_generate_partials(state)
    partials = []
    state.testables.each do |_, testable|
      next if testable.partials.configs.empty?
      testable.partials.configs.each do |_, config|
        partials << { config: config, testable: testable }
      end
    end

    # How many of each kind of generated file were fresh and so left alone
    skipped = Hash.new( 0 )

    # Each test's search, built before the batch, which shares it between that test's Partials
    searches = partials.map { |partial| partial[:testable] }.uniq.to_h { |testable| [testable.name, @mock_locator.header_search( testable )] }

    @batchinator.exec(workload: :compile, things: partials) do |partial|
      config   = partial[:config]
      testable = partial[:testable]
      name     = testable.name

      # Every input generation reads rides in the staleness record below, so a change to any of
      # them regenerates what the previous ones produced:
      #  - The preprocessed copies stages 6/7 wrote, beside the originals. Generation reads the
      #    copies, so whatever rewrites them without touching the originals reaches this stage
      #    through them, as toggling forced fallback or changing the preprocessor does.
      #  - The test's selection, which decides what each generated file holds.
      #  - The real header's guard, spoofed deliberately in every generated file.
      #  - Each generated file's includes, which depend on the test's other Partial modules
      #    and how each is selected. The record's lists leave out the types header, since the
      #    module files the record holds decide whether one exists.
      antecedent_files     = partial_antecedent_files( config )
      module_include_guard = @partializer.extract_module_include_guard( config.header.filepath )
      # Generation's lists are the ones logged, so the record's are computed without a test name
      spelled              = spell_partial_includes( config, searches[name] )
      record_includes      = remap_partial_includes( config, testable.partials.configs, nil, nil, spelled )

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
        types_includes:       record_includes[:types].to_record,
        impl_header_includes: record_includes[:impl_header].to_record,
        impl_source_includes: record_includes[:impl_source].map( &:to_s ),
        interface_includes:   record_includes[:interface].to_record
      }

      record = { files: antecedent_files, meta: antecedent_meta, name: name, partial: config.module }
      paths  = partial_paths( config, testable )

      fresh = fresh_targets( config, paths, record )
      if fresh
        skip_fresh_partial( state, testable, config, fresh, skipped )
        next
      end

      module_contents = @partializer.extract_module_contents( name, config )
      @partializer.validate_config( c_module: module_contents, config: config, name: name )

      @partializer.sanitize( module_contents, include_guard: module_include_guard )

      # Generated once and shared by the implementation and interface headers below (via
      # their own includes lists), so a module tested and mocked in the same test file gets
      # exactly one C definition of each of its typedefs and aggregate types. A module with no
      # typedefs or aggregate definitions gets none, and one an earlier build left is removed.
      # The filename is computed the same deterministic way GeneratorPartials#generate_types
      # computes it, so the includes remapping below knows what to #include.
      types_header = module_contents.types? ? @file_path_utils.form_partial_types_header_filename( config.module ) : nil
      discard_leftover_types( paths[:types] ) if types_header.nil?

      includes = remap_partial_includes( config, testable.partials.configs, types_header, name, spelled )

      # The implementation and interface include the types header, so each vouches for it
      types_target = types_header && paths[:types]

      if types_header
        unchanged = generate_when_stale( target: types_target, kind: :types, **record ) do
          @generator.generate_partial_types(
            name:          name,
            partial:       config.module,
            c_module:      module_contents,
            output_path:        testable.paths[:partials],
            includes:           includes[:types].leading,
            following_includes: includes[:types].following,
            include_guard:      module_include_guard
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
            test: name, c_module: module_contents, impl: implementation, interface: interface,
            header_guarded: !module_include_guard.nil?, config: config
          )

          @generator.generate_partial_implementation(
            test:                      name,
            partial:                   config.module,
            function_definitions:      implementation,
            c_module:                  module_contents,
            header_includes:           includes[:impl_header].leading,
            header_following_includes: includes[:impl_header].following,
            source_includes:           includes[:impl_source],
            output_path:               testable.paths[:partials],
            include_guard:             module_include_guard,
            carry:                     carry,
            suppress_redundant_decls:  @configurator.partials_suppress_redundant_decls,
            extern_variables:          @configurator.partials_extern_variables
          )
        end

        state.lock.synchronize do
          skipped[:implementation] += 1 if unchanged
          testable.partials.tests << config.module
        end
      end

      unless interface.nil?
        extras = implementation.nil? ? plan_extras( name, config, module_contents, interface, module_include_guard ) : nil
        explain_tested_mock( testable, config, module_contents, interface, module_include_guard ) unless implementation.nil?
        extras_target = (extras.nil? or extras.empty?) ? nil : paths[:extras]
        discard_leftover_extras( paths[:extras] ) if extras_target.nil?

        outputs   = [types_target, extras_target].compact
        unchanged = generate_when_stale( target: paths[:interface], outputs: outputs, kind: :interface, **record ) do
          @generator.generate_partial_interface(
            test:                  name,
            partial:               config.module,
            function_declarations: interface,
            includes:              includes[:interface].leading,
            following_includes:    includes[:interface].following,
            c_module:              module_contents,
            output_path:           testable.paths[:partials],
            include_guard:         module_include_guard,
            extras:                extras
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

  # How FilePathUtils names each file a Partial generates
  PARTIAL_FILENAMES = {
    types:          :form_partial_types_header_filename,
    implementation: :form_partial_implementation_source_filename,
    impl_header:    :form_partial_implementation_header_filename,
    interface:      :form_partial_interface_header_filename,
    extras:         :form_partial_extras_header_filename
  }.freeze unless const_defined?(:PARTIAL_FILENAMES, false)

  # Where each file a Partial generates lives
  def partial_paths(config, testable)
    dir = testable.paths[:partials]
    return PARTIAL_FILENAMES.transform_values { |form| File.join( dir, @file_path_utils.public_send( form, config.module ) ) }
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

  # A mock-only Partial's interface stands in for its real header, so the rest of that header
  # comes along in an extras header. A module the test also tests carries what its own code
  # uses through its implementation instead, so it plans none.
  def plan_extras(name, config, module_contents, interface, include_guard)
    return @partializer.plan_interface_extras(
      test: name, c_module: module_contents, interface: interface, header_guarded: !include_guard.nil?, config: config
    )
  end

  def explain_tested_mock(testable, config, module_contents, interface, include_guard)
    @partializer.explain_tested_mock(
      test: testable.name, c_module: module_contents, interface: interface, header_guarded: !include_guard.nil?, config: config,
      partials: testable.partials.configs
    )
  end

  # An interface that keeps nothing includes no extras header. One an earlier build left would
  # only sit beside it.
  def discard_leftover_extras(path)
    @file_wrapper.rm_f( path ) if @file_wrapper.exist?( path )
  end

  # A module joins the test's list for each side of its Partial that exists
  def join_partial_lists(partials, partial_module, kinds)
    partials.tests << partial_module if kinds.include?( :implementation )
    partials.mocks << partial_module if kinds.include?( :interface )
  end

  # A Partial's original header and source, and the preprocessed copies of each that generation
  # reads. Extraction parses the assembled copy and the expanded code. Inline marking and the
  # incomplete-type search read the raw directives-only copy, which holds every header the file
  # includes. A declaration-only Partial has no source file, and a file preprocessed in fallback
  # has no raw copy. Those paths are nil and compacted out, since path normalization expects
  # real paths only.
  def partial_antecedent_files(config)
    return [config.header, config.source].flat_map do |file|
      [file.filepath, file.assembled_filepath, file.expansion_filepath, file.raw_directives_only_filepath]
    end.compact.uniq
  end

  # The includes of each file this module's Partial can generate, keyed by file. The impl and
  # interface headers carry the shared types header when the module has one. Each generated
  # header gets its includes in groups (Partials::IncludeGroups), split where the source
  # includes the module's header.
  def remap_partial_includes(config, partials, types_header, test, spelled)
    common = { name: config.module, partials: partials, test: test }
    split  = { **common, source_includes: spelled[:source], header_includes: spelled[:header] }

    return {
      types:       @partializer.remap_types_header_includes( **split ),
      impl_header: @partializer.remap_implementation_header_includes( **split, types_header: types_header ),
      impl_source: @partializer.remap_implementation_source_includes( **common, includes: spelled[:source] + spelled[:header] ),
      interface:   @partializer.remap_interface_header_includes( **split, types_header: types_header )
    }
  end

  # A Partial's #includes, each by a spelling the test's search paths reach its header by (see
  # HeaderSearch on spellings), so a generated file reaches it from the Partials directory, and
  # modules are matched by that header
  def spell_partial_includes(config, search)
    return {
      source: spelled_includes( config.source, search ),
      header: spelled_includes( config.header, search )
    }
  end

  # One module file's #includes. Fallback's text scan holds each as written, which names a header
  # beside the file first. The preprocessor's hold the path it found each header by.
  def spelled_includes(file_info, search)
    from = file_info.filepath && File.dirname( file_info.filepath )
    return file_info.includes.map { |include| include.spelled_by( search, from: from, resolved: !file_info.fallback ) }
  end

  # Build threads finish in any order. Each test's Partial modules return to its configuration
  # order, which its link and mock lists follow, so an unchanged build sees unchanged lists.
  def order_partials(testables)
    testables.each do |testable|
      order = testable.partials.configs.values.map( &:module )
      testable.partials.tests.sort_by! { |_module| order.index( _module ) }
      testable.partials.mocks.sort_by! { |_module| order.index( _module ) }
    end
  end

end
