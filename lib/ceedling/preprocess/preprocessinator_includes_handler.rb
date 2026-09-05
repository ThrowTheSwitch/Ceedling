# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes/includes'
require 'ceedling/path_matcher'
require 'ceedling/preprocess/preprocessinator_bare_includes_extractor'
require 'ceedling/preprocess/preprocessinator_line_marker_includes_extractor'
require 'ceedling/preprocess/c_preprocessor_conditionals'
require 'ceedling/exceptions'

class PreprocessinatorIncludesHandler

  constructor(
    :configurator,
    :preprocessinator_line_marker_includes_extractor,
    :include_factory,
    :tool_executor,
    :file_wrapper,
    :file_path_utils,
    :yaml_wrapper,
    :parsing_parcels,
    :loginator,
    :reportinator
  )

  def setup()
    # Aliases
    @line_marker_includes_extractor = @preprocessinator_line_marker_includes_extractor
  end

  def extract_bare_includes(test:, filepath:, search_paths:, flags:, defines:)
    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting bare #includes via preprocessing from",
      module_name: test,
      filename: filename
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Creation:
    #  - This output is created with the -MM -MG -MP command line options.
    #  - Limited search paths are used towards shallow extracting of only the user #include statements of the file.
    #    This preprocessor mode assumes any includes discovered outside of a search path will be generated.
    #
    # Notes:
    #  - This approach can have gaps with advacnced user-level macros like `#include <MACRO>`.
    #    By including Ceedling's vendor search path, we support Partials macros of this sort.
    #  - Gaps can be minimized with proper defines in the project file. However, needed, complex macros
    #    located in other header files could still gum up the works.
    #  - Many errors can occur but may not necessarily prevent usable results.
    #
    # GCC's quoted #include resolution always checks the directory of the file it's currently
    # processing, independent of search paths -- a real sibling header on disk is opened and
    # recursed into regardless of the restricted search paths above. Staging an isolated,
    # sibling-free copy of the file being scanned keeps this pass's output limited to genuine
    # top-level #include statements only. The isolation directory is minted directly inside the
    # test's own preprocess-files build directory (already created in an earlier build stage) --
    # no dedicated subdirectory or filename-based naming, to keep the resulting path as short as
    # possible for platforms with tight path length limits.
    isolation_parent = @file_path_utils.form_test_preprocess_files_path( test )
    isolation_dir = @file_wrapper.stage_isolated_copies( parent: isolation_parent, files: [filepath] )
    isolated_filepath = File.join( isolation_dir, filename )

    begin
      msg = @reportinator.generate_module_progress(
        operation: "Isolating a sibling-free copy for bare-includes extraction at",
        module_name: test,
        filename: isolated_filepath
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS )

      command =
        @tool_executor.build_command_line(
          @configurator.tools_test_bare_includes_preprocessor,
          # No additional arguments
          [],
          # Argument replacement
          isolated_filepath,
          defines,
          flags,
          search_paths
        )

      # Assume possible errors so we have best shot at extracting results from preprocessing.
      # Full code compilation will catch any breaking code errors
      command[:options][:boom] = false
      shell_result = @tool_executor.exec( command )
    ensure
      @file_wrapper.remove_isolated_copies( isolation_dir )
    end

    make_rules = shell_result[:output]

    # Do not check exit code for success. In some error conditions we still get usable output.
    # Look for the first line of the make rule output.
    if not make_rules =~ PreprocessinatorBareIncludesExtractor::MAKE_RULE_MATCHER
      @loginator.lazy( Verbosity::DEBUG ) do
        "Preprocessor bare #include extraction failed: #{shell_result[:output]}"
      end
      return []
    end

    includes = PreprocessinatorBareIncludesExtractor.extract_includes( make_rules )
    includes = clean_self_reference(filepath, includes)

    header = "Extracted bare #includes from #{filepath}:"
    @loginator.log_list( includes, header, Verbosity::DEBUG )

    return includes
  end

  # Scan the original file's own text for every #include line, unconditionally --
  # no #if/#ifdef tracking at all, just literal presence. Supplements the gcc-based
  # bare pass (`extract_bare_includes`), which runs against an isolated, sibling-free
  # copy of the file and so can never open another header to resolve a conditional
  # that depends on a macro that header defines (e.g. `#if SOME_MACRO_FROM_ANOTHER_HEADER`)
  # -- GCC treats the macro as undefined there and silently drops the #include line
  # from that pass's output even though it's a perfectly ordinary, real, top-level
  # #include once actually evaluated with the real file in place. This method's result
  # is meant to be unioned with the gcc-based bare pass's own result (see
  # Preprocessinator#preprocess_file_includes_common), not used on its own -- an
  # `Includes.reconcile` call downstream still only keeps an entry here if the
  # accurate directives-only pass also reports it, so unconditionally capturing every
  # literal #include line (regardless of whether its own guard is really true) is
  # safe: it can only ever let back in an entry the accurate pass already confirmed,
  # never introduce a spurious one on its own. A supplement, not a replacement --
  # the gcc pass can still do something this literal scan structurally can't: resolve
  # an #include whose own target is a macro rather than a literal filename.
  def extract_bare_includes_from_text(filepath:)
    includes = []

    # Open in binary mode: code_lines cleans the whole buffer via clean_encoding
    # before ever splitting into lines, but a text-mode read could itself raise
    # on invalid byte sequences before clean_encoding gets the chance.
    @file_wrapper.open(filepath, 'rb') do |input|
      @parsing_parcels.code_lines( input ) do |line|
        _include = @include_factory.user_include_from_directive( line ) ||
                   @include_factory.system_include_from_directive( line )
        includes << Include.new( _include.filepath ) if !_include.nil?
      end
    end

    return clean_self_reference( filepath, includes )
  end

  def extract_user_includes_preprocess(name:, filepath:, preprocessed_filepath:)
    includes = []

    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting user #includes from preprocessed output",
      module_name: name,
      filename: filename
    )
    @loginator.log(msg, Verbosity::OBNOXIOUS)

    includes =
      @line_marker_includes_extractor.extract_includes_from_file(
        preprocessed_filepath,
        PreprocessinatorLineMarkerIncludesExtractor::USER,
        # Note: No limit to max depth to search for user includes
        test: name
      )

    return clean_self_reference( filepath, includes )
  end

  def extract_user_includes_from_text(name:, filepath:, defines: [])
    includes = []

    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting user #includes from original file using fallback method",
      module_name: name,
      filename: filename
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

    cond_tracker = CPreprocessorConditionals.new( defines )

    # Open in binary mode: code_lines cleans the whole buffer via clean_encoding
    # before ever splitting into lines, but a text-mode read could itself raise
    # on invalid byte sequences before clean_encoding gets the chance.
    @file_wrapper.open(filepath, 'rb') do |input|
      @parsing_parcels.code_lines( input ) do |line|
        cond_tracker.process_directive( line )
        next unless cond_tracker.active?
        _include = @include_factory.user_include_from_directive( line )
        includes << _include.anchored( File.dirname( filepath ) ) if !_include.nil?
      end
    end

    return clean_self_reference( filepath, includes )
  end

  def extract_system_includes_preprocess(name:, filepath:, preprocessed_filepath:)
    includes = []

    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting system #includes from preprocessed output",
      module_name: name,
      filename: filename
    )
    @loginator.log(msg, Verbosity::OBNOXIOUS)

    includes = 
      @line_marker_includes_extractor.extract_includes_from_file(
        preprocessed_filepath,
        PreprocessinatorLineMarkerIncludesExtractor::SYSTEM,
        5 # Practical max depth limit for system headers (to avoid noisy length)
      )

    return clean_self_reference( filepath, includes )
  end

  def extract_system_includes_from_text(name:, filepath:, defines: [])
    includes = []

    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting system #includes from original file using fallback method",
      module_name: name,
      filename: filename
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

    cond_tracker = CPreprocessorConditionals.new( defines )

    # Open in binary mode: code_lines cleans the whole buffer via clean_encoding
    # before ever splitting into lines, but a text-mode read could itself raise
    # on invalid byte sequences before clean_encoding gets the chance.
    @file_wrapper.open(filepath, 'rb') do |input|
      @parsing_parcels.code_lines( input ) do |line|
        cond_tracker.process_directive( line )
        next unless cond_tracker.active?
        _include = @include_factory.system_include_from_directive( line )
        includes << _include.anchored( File.dirname( filepath ) ) if !_include.nil?
      end
    end

    return clean_self_reference( filepath, includes )
  end

  # Write to disk a yaml representation of a list of includes
  def write_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, Includes.to_hashes(list))
  end

  def load_includes_list(filepath)
    loaded = begin
      @yaml_wrapper.load( filepath )
    rescue YamlLoadException => e
      raise YamlLoadException.new(
        reason: e.reason, source: e.source, original_error: e.original_error,
        message: "Cached #include list is corrupted or unreadable ⏩️ #{e.message}"
      )
    end

    # Note: It's possible empty YAML content returns nil so ensure empty list
    return Includes.from_hashes( loaded || [] )
  end

  ### Private ###
  private

  # Remove any filepath in the includes list that is identical to the filepath being processed.
  # We want to prevent an includes list containing an unnecessary self-reference.
  # Use normalized paths for comparison to handle variations (relative vs absolute, different separators, etc.)
  def clean_self_reference(filepath, includes)
    _filepath = File.expand_path(filepath)
    Includes.sanitize!(includes) do |include, _|
      _filepath == File.expand_path(include.filepath)
    end
    return includes
  end

end
