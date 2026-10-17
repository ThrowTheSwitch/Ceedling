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
    :quote_include_isolator,
    :loginator,
    :reportinator
  )

  def setup()
    # Aliases
    @line_marker_includes_extractor = @preprocessinator_line_marker_includes_extractor
  end

  # GCC's make rule (-M -MG -MP) for an isolated copy of `filepath`, listing every header
  # the file names. Only Ceedling's vendor paths are searched, which serves a Partials
  # directive macro, and a header not found is taken as one to be generated. A macro
  # another header defines is invisible here, so an #include it guards can drop out; the
  # text scan and computed #includes make up for that. Nil when the run gives no rule at
  # all: errors in the file's own code still give one, so the tool itself failed.
  def extract_bare_includes(test:, filepath:, search_paths:, flags:, defines:)
    _log_extraction_progress( 'Extracting bare #includes via preprocessing from', test, filepath )
    output = run_bare_includes_preprocessor( test, filepath, [defines, flags, search_paths] )
    return log_bare_failure( filepath, output ) unless output.to_s.match?( PreprocessinatorBareIncludesExtractor::MAKE_RULE_MATCHER )

    includes = clean_self_reference( filepath, PreprocessinatorBareIncludesExtractor.extract_includes( output ) )
    @loginator.log_list( includes, "Extracted bare #includes from #{filepath}:", Verbosity::DEBUG )
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

  # User and system extraction are the same shape twice over -- once against the
  # accurate directives-only line-marker stream, once against the original file's own
  # text as a fallback. The public methods below stay as the four call sites callers
  # and specs know; the two private helpers hold the body each pair shares.

  def extract_user_includes_preprocess(name:, filepath:, preprocessed_filepath:)
    _log_extraction_progress( 'Extracting user #includes from preprocessed output', name, filepath )

    # No depth limit: a user include matters however deeply it nests. `test:` lets the
    # extractor strip this test's own mock subdirectory off a resolved mock include.
    includes = @line_marker_includes_extractor.extract_includes_from_file(
      preprocessed_filepath,
      PreprocessinatorLineMarkerIncludesExtractor::USER,
      test: name
    )

    clean_self_reference( filepath, includes )
  end

  def extract_system_includes_preprocess(name:, filepath:, preprocessed_filepath:)
    _log_extraction_progress( 'Extracting system #includes from preprocessed output', name, filepath )

    # A practical ceiling: system headers nest deeply through their own wrappers and
    # everything past a handful of levels is noise, not a project dependency.
    includes = @line_marker_includes_extractor.extract_includes_from_file(
      preprocessed_filepath,
      PreprocessinatorLineMarkerIncludesExtractor::SYSTEM,
      SYSTEM_INCLUDE_MAX_DEPTH
    )

    clean_self_reference( filepath, includes )
  end

  # The user files a preprocessor's output entered, from its line markers. Any output
  # that keeps them serves: directives-only output, or a full -E expansion.
  def extract_preprocessed_dependencies(preprocessed_filepath:)
    return @line_marker_includes_extractor.extract_entered_files_from_file( preprocessed_filepath )
  end

  # Resolve every `#include` in the original file whose target is a macro invocation
  # rather than a literal `"..."` / `<...>` filename. Neither bare pass above can see
  # such a directive: the gcc dep pass runs against an isolated copy and can't evaluate
  # a sibling-header guard around it, and the text scan has no literal filename to
  # match. A real preprocessor pass DID resolve it -- it opened the header and emitted
  # an ordinary entering line marker. That pass is directives-only output, or for a test
  # file in fallback, a plain expansion read as a best effort. This method finds each
  # non-literal `#include`'s source line, then asks the line-marker extractor which
  # header the preprocessor entered at that line, and returns those as base `Include`
  # objects to union into `bare` (see Preprocessinator#preprocess_file_includes_common).
  # Meaningful only with line-marker output to read; a nil `directives_only_filepath`
  # (a header in fallback, or a per-file failure) yields an empty list -- a documented
  # limitation.
  #
  # @return [Array<Include>] base Include objects, one per resolved computed #include
  def extract_computed_includes(filepath:, directives_only_filepath:)
    return [] if directives_only_filepath.nil?

    computed_lines = computed_include_source_lines( filepath )
    return [] if computed_lines.empty?

    resolved = @line_marker_includes_extractor.resolve_computed_includes(
      preprocessed_filepath: directives_only_filepath,
      source_basename:       File.basename( filepath ),
      source_lines:          computed_lines
    )

    includes = resolved.values.map { |path| Include.new( path ) }
    clean_self_reference( filepath, includes )
  end

  def extract_user_includes_from_text(name:, filepath:, defines: [])
    _extract_includes_from_text( :user_include_from_directive, 'user', name: name, filepath: filepath, defines: defines )
  end

  def extract_system_includes_from_text(name:, filepath:, defines: [])
    _extract_includes_from_text( :system_include_from_directive, 'system', name: name, filepath: filepath, defines: defines )
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

  # GCC's quoted #include resolution always checks the directory of the file it is
  # processing, whatever the search paths say, so a real sibling header would be opened and
  # followed. An isolated, sibling-free copy keeps the rule to the file's own #includes.
  # The copy sits directly in the test's preprocess directory, with no name drawn from the
  # file, to keep paths short where their length is limited.
  def run_bare_includes_preprocessor(test, filepath, tool_args)
    output = nil
    @quote_include_isolator.within( parent: @file_path_utils.form_test_preprocess_files_path( test ), files: [filepath] ) do |isolation|
      output = exec_bare_includes_tool( test, isolation.copy_of( filepath ), tool_args )
    end
    return output
  end

  # Errors in the file's own code still leave a usable rule, so a failing run's output is
  # read all the same
  def exec_bare_includes_tool(test, isolated_filepath, tool_args)
    operation = 'Isolating a sibling-free copy for bare-includes extraction at'
    @loginator.log( @reportinator.generate_module_progress( operation: operation, module_name: test, filename: isolated_filepath ), Verbosity::OBNOXIOUS )

    command = @tool_executor.build_command_line( @configurator.tools_test_bare_includes_preprocessor, [], isolated_filepath, *tool_args )
    command[:options][:boom] = false
    return @tool_executor.exec( command )[:output]
  end

  # The tool's own output, since the command line alone wouldn't say why it failed
  def log_bare_failure(filepath, output)
    @loginator.log( "Failed to extract bare #includes (text-scan #includes will stand in) for #{filepath}:\n#{output.to_s.strip}", Verbosity::OBNOXIOUS, LogLabels::ERROR )
    return nil
  end

  # Practical max depth for the system-header line-marker walk (see
  # extract_system_includes_preprocess).
  SYSTEM_INCLUDE_MAX_DEPTH = 5 unless const_defined?(:SYSTEM_INCLUDE_MAX_DEPTH, false)

  # Fallback text scan for user or system includes -- identical but for which directive
  # form IncludeFactory recognizes. `#if`/`#ifdef` state is tracked so a guarded include
  # is only kept when its guard is actually true given `defines`.
  def _extract_includes_from_text(directive_method, noun, name:, filepath:, defines:)
    _log_extraction_progress(
      "Extracting #{noun} #includes from original file using fallback method",
      name, filepath, label: LogLabels::WARNING
    )

    includes = active_includes_in_text( directive_method, filepath, CPreprocessorConditionals.new( defines ) )
    clean_self_reference( filepath, includes )
  end

  # Binary read: code_lines runs clean_encoding over the whole buffer, but a text-mode
  # read can raise on an invalid byte sequence before that ever happens.
  def active_includes_in_text(directive_method, filepath, conditionals)
    includes = []
    @file_wrapper.open( filepath, 'rb' ) do |input|
      @parsing_parcels.code_lines( input ) do |line|
        conditionals.process_directive( line )
        next unless conditionals.active?
        include = @include_factory.public_send( directive_method, line )
        includes << include.anchored( File.dirname( filepath ) ) unless include.nil?
      end
    end
    return includes
  end

  # An `#include` directive with an argument of some kind. `\S` after the whitespace
  # rejects a malformed `#include` with nothing after it.
  INCLUDE_DIRECTIVE = /^\s*#\s*include\s+\S/ unless const_defined?(:INCLUDE_DIRECTIVE, false)

  # 1-indexed source line numbers of every `#include` in `filepath` whose argument is
  # a bare token rather than a literal `"..."` or `<...>` -- i.e. a macro the
  # preprocessor must expand before any filename exists. `code_lines_with_num` has
  # already stripped comments and folded backslash continuations, so a commented-out
  # or string-embedded `#include` never reaches here.
  #
  # The line reported is the directive's ENDING physical line, not its first --
  # `-fdirectives-only` attributes a consumed multi-line directive's own entering
  # marker to the last physical line it spans (the marker literally replaces that
  # line in the output stream; see PreprocessinatorLineMarkerIncludesExtractor's own
  # correlation walk and preprocess/README.md), so this must name the same line or
  # resolve_computed_includes never finds a match. For an ordinary, single-line
  # directive the start and end line are identical, so this is a no-op there.
  def computed_include_source_lines(filepath)
    lines = []

    # Binary read for the same reason the sibling text scans use it: a text-mode read
    # can raise on an invalid byte sequence before code_lines' encoding cleanup runs.
    @file_wrapper.open( filepath, 'rb' ) do |input|
      @parsing_parcels.code_lines_with_num( input ) do |line, _line_num, end_line_num|
        next unless line.match?( INCLUDE_DIRECTIVE )
        next if line.match?( PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME )
        next if line.match?( PATTERNS::SYSTEM_INCLUDE_DIRECTIVE_FILENAME )
        lines << end_line_num
      end
    end

    lines
  end

  # Shared progress line for the four extraction methods above.
  def _log_extraction_progress(operation, name, filepath, label: nil)
    msg = @reportinator.generate_module_progress(
      operation: operation, module_name: name, filename: File.basename( filepath )
    )
    args = [msg, Verbosity::OBNOXIOUS]
    args << label unless label.nil?
    @loginator.log( *args )
  end

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
