# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'rake' # .ext()
require 'ceedling/includes/includes'
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_runtime'
require 'ceedling/c_extractor/c_extractor'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_types'
require 'ceedling/constants'
require 'ceedling/path_mirror'
require 'ceedling/encodinator'
require 'ceedling/exceptions'

class Partializer

  # Enough of a header to reach its include guard. The guard pair sits at the top of a header by
  # construction, so a bounded read beats loading a large file to find it.
  GUARD_SCAN_BYTES = 2048

  include Partials

  constructor :configurator, :partializer_helper, :file_finder, :c_extractor, :file_path_utils,
              :preprocessinator_reconstructor, :file_wrapper, :reportinator, :loginator

  def setup()
    # Alias
    @helper = @partializer_helper
  end

  def validate_config(c_module:, config:, name:, fallback: false)
    msg = @reportinator.generate_progress("Validating Partial config for '#{name}'")
    @loginator.log(msg, Verbosity::DEBUG)
    @helper.validate_function_names_exist(c_module, config, name)
    @helper.validate_no_additions_subtractions_overlap(config, name)
    @helper.validate_additions_subtractions_visibility(c_module, config, name)

    # Fallback preprocessing resolves strictly less than the accurate pass, and two module
    # shapes are knowably beyond it. Reading the original text happens here, at the I/O edge,
    # so the check itself stays pure.
    return unless fallback

    @helper.validate_fallback_sufficiency(
      name: name,
      module_name: config.module,
      files: _module_file_texts(config)
    )
  end

  def sanitize(c_module)
    # Remove macro definitions that contain the CEEDLING_GENERATED sentinel string.
    # These are include-guard and boilerplate macros injected into Ceedling-generated header files.
    removed = c_module.macro_definitions.select { |m| m.text.include?(CEEDLING_GENERATED) }
    # Remove from both the macro_definitions list and the element_sequence that references it
    c_module.macro_definitions.reject! { |m| m.text.include?(CEEDLING_GENERATED) }
    c_module.element_sequence.reject!  { |e| removed.include?(e) }
  end

  def validate_extracted_functions(name:, partial:, impl:, interface:)
    # Validation is only meaningful and possible if both references are non-nil.
    return if impl.nil? || interface.nil?

    # Validation is only meaningful if both lists have content.
    return if impl.empty? || interface.empty?

    impl_names      = Set.new(impl.map(&:name))
    interface_names = Set.new(interface.map(&:name))

    msg = @reportinator.generate_module_progress(
      module_name: name,
      filename: partial,
      operation: 'Validating Partial functions for'
    )
    @loginator.log(msg, Verbosity::DEBUG)

    # Report the first overlap and abort. An `each` here would read as though
    # every offending function gets reported, which it cannot -- the raise ends
    # the build on the first one.
    overlap = impl_names & interface_names
    unless overlap.empty?
      raise CeedlingException.new(
        "#{name}: Partial '#{partial}' ⏩️ Function '#{overlap.first}' cannot be both testable and mockable"
      )
    end
  end

  # A Partial module is resolved the way every other file reference in a test is, by
  # matching trailing path segments. Two things make that correct here.
  #
  # `collection` is the ordered header list this one test would search, so a
  # TEST_INCLUDE_PATH() in that test decides which module it gets. Resolving against
  # one project-wide collection instead lets two modules sharing a basename collapse
  # to whichever appears first, no matter which test asked.
  #
  # The source is then found by way of the resolved header, so a bare module name
  # cannot pair one module's header with another module's source.
  def populate_filepaths(configs, collection: nil, test_filepath: nil)
    configs.each do |_module, config|
      # Every partial involves processing header files
      config.header.filepath = @file_finder.find_header_file(_module, :ignore, collection: collection)

      _validate_named_directory_resolved!(_module, config.header.filepath, test_filepath)

      # Source file not needed only when mocking public functions exclusively
      unless !config.tests.present? && config.mocks.type == PUBLIC
        config.source.filepath = _find_module_source(_module, config.header.filepath)
      end
    end

    return configs
  end

  # A module named by directory was spelled out by its author, so it is looked up
  # verbatim with no fallback. A bare name is narrowed by its resolved header's own
  # directory, which is what keeps one module's header from pairing with another
  # module's source. The fallback after that serves a project whose source and include
  # trees do not mirror one another, where a header sits under a directory its source
  # does not.
  def _find_module_source(_module, header_filepath)
    return @file_finder.find_source_file(_module, :ignore) if _names_directory?(_module)

    subdir = header_filepath.nil? ? '' : PathMirror.relative_subdir(header_filepath, _header_roots)

    unless subdir.empty?
      found = @file_finder.find_source_file(File.join(subdir, _module), :ignore)
      return found unless found.nil?
    end

    return @file_finder.find_source_file(_module, :ignore)
  end

  # Roots a header can sit beneath, which is what its mirrored directory is measured
  # against. The same three the project-wide header collection is built from.
  def _header_roots
    @configurator.paths_test + @configurator.paths_support + @configurator.paths_include
  end

  # Either separator counts. The qualifier validation already rejects a backslash-rooted
  # absolute path, so a backslash reaching here is a relative directory like any other.
  def _names_directory?(_module)
    _module.match?( %r{[\\/]} )
  end

  # A bare module name that matches nothing keeps its older behavior, generating a
  # degenerate Partial. A directory that matches nothing is a typo worth saying so,
  # since naming the directory was a deliberate act and no older behavior is at stake.
  def _validate_named_directory_resolved!(_module, header_filepath, test_filepath)
    return unless _names_directory?(_module)
    return unless header_filepath.nil?

    location = test_filepath.nil? ? '' : " referenced in #{test_filepath}"

    raise CeedlingException.new(
      "Partial module '#{_module}'#{location} matches no files. " \
      "A Partial's directory is matched against the trailing end of a module's path, " \
      "so check the spelling of both the directory and the module."
    )
  end

  # Includes for the generated implementation header. This module's own header is replaced by
  # the shared types header at its original list position; every other partialized module's
  # include is dropped.
  #
  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_implementation_header_includes(name:, includes:, partials:, types_header: nil, test: nil)
    _remap_includes(
      name:        name,
      includes:    includes,
      partials:    partials,
      replacement: types_header,
      others:      :drop,
      noun:        'Header includes to inject for testable Partial',
      test:        test
    )
  end

  # Includes for the generated mockable interface header. Same treatment as the implementation
  # header: both files carry the shared types header, which is how a module tested and mocked
  # in one test file still gets exactly one definition of each of its types.
  #
  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_interface_header_includes(name:, includes:, partials:, types_header: nil, test: nil)
    _remap_includes(
      name:        name,
      includes:    includes,
      partials:    partials,
      replacement: types_header,
      others:      :drop,
      noun:        'Header includes to inject for mockable Partial',
      test:        test
    )
  end

  # Includes for the generated implementation source. This module's own header is replaced by
  # the generated implementation header, which carries the types header internally. Another
  # partialized module that is mocked is redirected to its generated interface header; one that
  # is not mocked keeps its real header, which the generated code still needs.
  #
  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_implementation_source_includes(name:, includes:, partials:, test: nil)
    _remap_includes(
      name:        name,
      includes:    includes,
      partials:    partials,
      replacement: @file_path_utils.form_partial_implementation_header_filename(name),
      others:      :mock_or_keep,
      noun:        'Source includes to inject for testable Partial',
      test:        test
    )
  end

  # Includes the shared types header carries so the extracted types resolve wherever that file
  # lands. Nothing replaces this module's own header here -- the types header cannot include
  # itself -- so it is simply dropped. Another partialized module is redirected to its generated
  # interface header when mocked and dropped otherwise: its real header would reintroduce the
  # very content that module's own Partial replaced.
  #
  # When `test:` is provided, logs the resulting includes at OBNOXIOUS.
  def remap_types_header_includes(name:, includes:, partials:, test: nil)
    _remap_includes(
      name:        name,
      includes:    includes,
      partials:    partials,
      replacement: nil,
      others:      :mock_or_drop,
      noun:        'Dependency includes to carry into the shared types header for Partial',
      test:        test
    )
  end

  # The include guard macro the module's real header defines, or nil when it has none.
  #
  # Read from the original header rather than from the reconstituted copy or from extracted
  # macros. The reconstituted copy carries a synthetic guard that #sanitize strips, and the
  # fallback preprocessing path deliberately excludes a guard from the macros it recovers, so
  # neither is a dependable source. A nil return means the header guards itself some other way
  # -- `#pragma once` -- and offers no macro for a generated file to spoof.
  def extract_module_include_guard(filepath)
    return nil if filepath.nil?

    text = @file_wrapper.read( filepath, GUARD_SCAN_BYTES ).clean_encoding
    @preprocessinator_reconstructor.extract_include_guard( text )
  end

  # Extracts and combines C code contents from a Partial config's header and source files
  #
  # This method uses CExtractor to parse C files and extract their contents including
  # function definitions, function declarations, and variable declarations. If both
  # header and source files are provided, their contents are merged into a single
  # CModule structure.
  #
  # @param name [String] The test this extraction is running for (log/error context).
  # @param config [Partials::ModuleConfig] The Partial's own config, carrying `header`/
  #   `source` (each a ConfigFileInfo) and `module`, the module name.
  # @param fallback [Boolean] Passed through to `associate_function_line_numbers` --
  #   whether to fall back to plain (non-directives-only) line-number association.
  #
  # @return [CExtractorTypes::CModule] A merged CModule containing all extracted contents
  #   from both files. The structure includes:
  #   - function_definitions: Array of function definitions with full implementations
  #   - function_declarations: Array of function declarations (prototypes)
  #   - variable_declarations: Array of variable declarations
  #
  # @note The method always starts with an empty CModule and merges in contents
  #   from any provided files using the CModule's + operator for combining structures.
  def extract_module_contents(name, config, fallback:)
    # Array for CModule structs
    contents = [CExtractorTypes::CModule.new()]

    # Process the C module source and/or header associated with the Partial config
    [config.header, config.source].zip(['header', 'source']).each do |c_file, file_type|
      # Do nothing if there's no directives-only preprocessed filepath (e.g. no source only header for a Partial mock)
      next unless c_file.directives_only_filepath

      c_module = @c_extractor.from_file( c_file.directives_only_filepath )

      _log_module_contents(name, config.module, file_type, c_module)

      # Update function signatures from fully preprocessed output when available.
      # Replaces signature/decorators/signature_stripped (but NOT code_block) so that
      # macros wrapping `static` and `inline` are resolved before visibility filtering.
      if c_file.full_expansion_filepath
        @helper.update_signatures_from_full_expansion(
          funcs:                   c_module.function_definitions,
          full_expansion_filepath: c_file.full_expansion_filepath,
          name:                    name,
          module_name:             config.module,
          file_type:               file_type
        )
      end

      # Align extracted function definitions with line markers in preprocessor output.
      # This perfectly remaps functions found in expanded preprocessor output with 
      # original source location.
      # This routine depends on original, unaltered function definitions.
      @helper.associate_function_line_numbers(
        name: name,
        funcs: c_module.function_definitions,
        filepath: c_file.filepath,
        fallback: fallback
      )

      # 1. Find any function-scope static variable declarations.
      # 2. Replace them in function definitions with no-ops (for proper coverage reporting).
      # 3. Promote the function-scoped variables to be module-level variables.
      decls = @helper.extract_function_scope_static_vars(
        c_module.function_definitions,
        name: name, module_name: config.module, file_type: file_type
      )
      c_module.variable_declarations.concat(decls)
      c_module.element_sequence.concat(decls) unless decls.empty?

      contents << c_module
    end

    # Use `+` operator for CModule to merge everything
    contents = contents.reduce(&:+)

    return contents
  end

  # Returns Array<Partials::FunctionDefinition> for the testable partial implementation.
  #
  # Processes the `tests` PartialFunctions config against extracted C function definitions:
  #   PUBLIC     -- initial list is all non-private functions; additions inject named private functions
  #   PRIVATE    -- initial list is all private functions; additions inject named public functions
  #   ACCUMULATE -- initial list is empty; additions fill it entirely
  #   nil        -- returns nil
  # Subtractions remove named functions from the assembled list.
  # Any functions in mocks.additions are also removed from the final result.
  # Parameters are expected to be pre-validated (no unknown names, no overlap, etc.).
  #
  # @param test        [String] Test file name (for log messages)
  # @param partial     [String] Partial module name (for log messages)
  # @param definitions [Array<CFunctionDefinition>] Extracted function definitions
  # @param config      [PartializerConfig::Config] Full partial config for the module
  # @return [Array<Partials::FunctionDefinition>]
  def extract_implementation_functions(test:, partial:, definitions:, config:)
    pf = config.tests
    return nil if pf.type.nil?

    @loginator.log(
      "Extracting testable Partial functions for #{test}::#{partial}: " \
      "type=#{pf.type} additions=#{pf.additions} subtractions=#{pf.subtractions}",
      Verbosity::DEBUG
    )

    # Build initial list by visibility; ACCUMULATE yields []
    funcs = @helper.filter_and_transform_funcs(definitions, pf.type, :impl)

    # Additions: only search definitions — code_block required for impl transform
    pf.additions.each do |name|
      next if funcs.any? { |f| f.name == name }
      func = @helper.find_and_transform_func(
        name:            name,
        primary_funcs:   definitions,
        secondary_funcs: [],
        output_type:     :impl
      )
      funcs << func if func
    end

    # Subtractions: remove named functions from list
    result = @helper.subtract_funcs(funcs: funcs, names: pf.subtractions)
    if !funcs.empty? && result.empty?
      @loginator.log(
        "Partial #{test}::#{partial} ⏩️ Subtractions left no testable functions",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )
    end

    # Remove any functions explicitly claimed by the mock side
    result = @helper.subtract_funcs(funcs: result, names: config.mocks.additions)

    _log_impl_functions(test, partial, result)

    return result
  end

  # Returns Array<Partials::FunctionDeclaration> for the mockable partial interface.
  #
  # Processes the `mocks` PartialFunctions config against extracted C functions:
  #   PUBLIC     -- initial list is all non-private functions; additions inject named private functions
  #   PRIVATE    -- initial list is all private functions; additions inject named public functions
  #   ACCUMULATE -- initial list is empty; additions fill it entirely
  #   nil        -- returns nil
  # Subtractions remove named functions from the assembled list.
  # Any functions in tests.additions are also removed from the final result.
  # Parameters are expected to be pre-validated (no unknown names, no overlap, etc.).
  # Additions search definitions first, then declarations; only the first match is used.
  #
  # @param test         [String] Test file name (for log messages)
  # @param partial      [String] Partial module name (for log messages)
  # @param definitions  [Array<CFunctionDefinition>] Extracted function definitions
  # @param declarations [Array<CFunctionDeclaration>] Extracted function declarations
  # @param config       [PartializerConfig::Config] Full partial config for the module
  # @return [Array<Partials::FunctionDeclaration>]
  def extract_interface_functions(test:, partial:, definitions:, declarations:, config:)
    pf = config.mocks
    return nil if pf.type.nil?

    @loginator.log(
      "Extracting mockable Partial functions for #{test}::#{partial}: " \
      "type=#{pf.type} additions=#{pf.additions} subtractions=#{pf.subtractions}",
      Verbosity::DEBUG
    )

    # A mock interface only ever needs a signature, never a body, so a declaration-only
    # function (no body found anywhere in this module's merged content) is just as valid a
    # candidate as one with a definition -- unlike extract_implementation_functions, which
    # needs real code to inject and so stays definitions-only. A function named in both
    # (declared in the header, defined in the paired source) is only counted once.
    candidates = definitions + declarations.reject { |d| definitions.any? { |f| f.name == d.name } }

    # Build initial list by visibility; ACCUMULATE yields []
    funcs = @helper.filter_and_transform_funcs(candidates, pf.type, :interface)

    # Additions: search definitions first, then declarations
    pf.additions.each do |name|
      next if funcs.any? { |f| f.name == name }
      func = @helper.find_and_transform_func(
        name:            name,
        primary_funcs:   definitions,
        secondary_funcs: declarations,
        output_type:     :interface
      )
      funcs << func if func
    end

    # Subtractions: remove named functions from list
    result = @helper.subtract_funcs(funcs: funcs, names: pf.subtractions)
    if !funcs.empty? && result.empty?
      @loginator.log(
        "Partial #{test}::#{partial} ⏩️ Subtractions left no mockable signatures",
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )
    end

    # Remove any functions explicitly claimed by the test side
    result = @helper.subtract_funcs(funcs: result, names: config.tests.additions)

    _log_interface_functions(test, partial, result)

    return result
  end

  private

  # Log all user-defined (non-function) C content extracted from a module's source/header at OBNOXIOUS level.
  # Covers the four categories that are injected into generated Partial files:
  # variable declarations, type definitions, macro definitions, and aggregate definitions
  # (structs, unions, enums not wrapped in a typedef).
  def _log_module_contents(name, module_name, source, contents)
    _vars = contents.variable_declarations.map { |v| "`#{v.text}`" }
    @loginator.log_list(
      _vars,
      "Variable declarations for Partial #{name}::#{module_name} from #{source}:",
      Verbosity::OBNOXIOUS
    )

    _types = contents.type_definitions.map { |t| "`#{t.text}`" }
    @loginator.log_list(
      _types,
      "Type definitions for Partial #{name}::#{module_name} from #{source}:",
      Verbosity::OBNOXIOUS
    )

    _macros = contents.macro_definitions.map { |m| "`#{m.text}`" }
    @loginator.log_list(
      _macros,
      "Macro definitions for Partial #{name}::#{module_name} from #{source}:",
      Verbosity::OBNOXIOUS
    )

    _aggregates = contents.aggregate_definitions.map { |a| "`#{a.text}`" }
    @loginator.log_list(
      _aggregates,
      "Aggregate definitions (structs/unions/enums) for Partial #{name}::#{module_name} from #{source}:",
      Verbosity::OBNOXIOUS
    )
  end

  # Log testable (implementation) functions at OBNOXIOUS level.
  def _log_impl_functions(test, partial, funcs)
    _funcs = funcs.nil? ? [] : funcs.map { |f| "`#{f.signature}`" }
    @loginator.log_list(
      _funcs,
      "Testable functions for Partial #{test}::#{partial}:",
      Verbosity::OBNOXIOUS
    )
  end

  # Log mockable (interface) functions at OBNOXIOUS level.
  def _log_interface_functions(test, partial, funcs)
    _funcs = funcs.nil? ? [] : funcs.map { |f| "`#{f.signature}`" }
    @loginator.log_list(
      _funcs,
      "Mockable functions for Partial #{test}::#{partial}:",
      Verbosity::OBNOXIOUS
    )
  end

  # The module's own header and source text, keyed by filepath. A declaration-only Partial has
  # no paired source, which leaves that filepath legitimately nil.
  def _module_file_texts(config)
    [config.header, config.source].filter_map do |file_info|
      next if file_info.nil? || file_info.filepath.nil?

      [file_info.filepath, @file_wrapper.read( file_info.filepath ).clean_encoding]
    end.to_h
  end

  # One body behind all four public remaps. Each differs only in what replaces this module's
  # own header, what becomes of other partialized modules, and the noun it logs under -- the
  # splice, the sanitize, and the logging are identical in every case.
  #
  # `others` selects the treatment of every OTHER partialized module in the same test file:
  #   :drop         -- remove its include outright, with no substitute
  #   :mock_or_keep -- redirect to its interface header when mocked, else leave its real header
  #   :mock_or_drop -- redirect to its interface header when mocked, else drop it
  def _remap_includes(name:, includes:, partials:, replacement:, others:, noun:, test: nil)
    _includes = includes.clone()

    # A nil replacement strips this module's own header and substitutes nothing.
    _includes = splice_in_replacement( includes: _includes, name: name, replacement: replacement )

    _includes =
      case others
      when :drop
        remove_matching_includes( includes: _includes, modules: (partials.keys - [name]) )
      when :mock_or_keep, :mock_or_drop
        _redirect_mocked_partials(
          includes: _includes,
          original: includes,
          name: name,
          partials: partials,
          drop_unmocked: (others == :mock_or_drop)
        )
      else
        raise CeedlingException.new( "Unknown partialized module treatment ':#{others}'" )
      end

    # Remove any duplicates
    Includes.sanitize!(_includes)

    @loginator.log_list(
      _includes,
      "#{noun} #{test}::#{name}:",
      Verbosity::OBNOXIOUS
    ) if test

    return _includes
  end

  # Appends the generated interface header for every other partialized module the original list
  # named and that is mocked, then removes the real headers those replaced.
  #
  # Any real (non-nil) mock mode counts. PUBLIC/PRIVATE alone once covered every mode that
  # existed, but DEDUCT (MOCK_PARTIAL_ALL_MODULE) and ACCUMULATE (MOCK_PARTIAL_MODULE) were
  # added later without updating the check, so a module mocked via either was silently never
  # redirected: its real header, and any static inline or static function bodies in it, stayed
  # #include'd verbatim and compiled straight past the mock.
  def _redirect_mocked_partials(includes:, original:, name:, partials:, drop_unmocked:)
    _includes = includes
    retired = []

    partials.each do |_module, config|
      next if _module == name
      next unless original.any? { |include| include.filename.ext().downcase() == _module.downcase() }

      if config.mocks.type.nil?
        retired << _module if drop_unmocked
      else
        _includes << UserInclude.new(
          @file_path_utils.form_partial_interface_header_filename(_module)
        )
        retired << _module
      end
    end

    remove_matching_includes( includes: _includes, modules: retired )
  end

  # Swaps `name`'s own header include for `replacement` at that same list position,
  # instead of stripping it out and appending the replacement at the very end.
  #
  # Both call sites' generated replacements (the shared types header; the generated
  # implementation header, which itself carries the types header) spoof the real
  # header's own include guard (a top-of-file `#define <ORIGINAL_GUARD>`) so that if the
  # real header is *also* reached a second way -- e.g. a transitively-included,
  # differently-named header that itself does a genuine `#include` of this module's
  # real header -- the real header's guard is already
  # tripped and its content (a second, conflicting copy of the same typedefs/structs)
  # never gets processed. That only works if the spoofing macro is defined *before*
  # such a transitive re-inclusion is reached, not after. Appending at the very end put
  # it after any such re-inclusion instead of before it. Keeping the replacement at the
  # original header's own list position preserves everything the generated content
  # depends on that came before it in the source's own working include order (e.g. a
  # shared Types.h), while still landing ahead of anything transitively re-reaching the
  # real header afterward.
  def splice_in_replacement(includes:, name:, replacement:)
    return remove_matching_includes(includes: includes, modules: [name]) unless replacement

    replaced = false
    spliced = includes.map do |include|
      if !replaced && module_basename( name ) == include.filename.ext().downcase()
        replaced = true
        UserInclude.new(replacement)
      else
        include
      end
    end
    # This module's own header wasn't in the includes list at all -- no original
    # position to preserve, so fall back to appending.
    spliced << UserInclude.new(replacement) unless replaced

    # A duplicate/case-variant entry beyond the first match (e.g. both 'module.h' and
    # 'MODULE.H' present) has no meaningful position of its own to preserve -- drop it
    # like remove_matching_includes always has.
    spliced = remove_matching_includes(includes: spliced, modules: [name])
    spliced
  end

  # Remove includes that match the given module names (case-insensitive)
  # Returns a new array with matching includes removed
  def remove_matching_includes(includes:, modules:)
    normalized_modules = modules.map { |_module| module_basename( _module ) }

    # Filter out includes (minus extension) that match any module name
    return includes.reject do |include|
      normalized_modules.include?(include.filename.ext().downcase())
    end
  end

  # A module name reduced to what an #include actually carries. An #include names a
  # file, not a module, so a module named by directory still has to be recognized by
  # the basename its own header include spells out.
  def module_basename(_module)
    File.basename( _module ).ext().downcase()
  end

end