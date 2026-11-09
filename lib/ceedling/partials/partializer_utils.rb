# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_runtime'
require 'ceedling/c_extractor/c_extractor_constants'
require 'ceedling/c_extractor/c_extractor_functions'

class PartializerUtils

  # The C11 specifier and the GNU and C23 attributes that each say a function never returns
  NORETURN_MARKINGS = /(?<!\w)_Noreturn(?!\w)|__attribute__\s*\(\(\s*(?:__noreturn__|noreturn)\s*\)\)|\[\[\s*(?:_Noreturn|noreturn)\s*\]\]/ unless const_defined?(:NORETURN_MARKINGS, false)

  include Partials

  constructor :preprocessinator_code_finder, :loginator

  def setup()
    # Aliases
    @code_finder = @preprocessinator_code_finder
  end

  # Check if function decorators match the desired visibility
  def matches_visibility?(decorators, visibility)
    case visibility
    when PUBLIC
      return !is_function_private?(decorators)
    when PRIVATE
      return is_function_private?(decorators)
    else
      PartializerRuntime.raise_on_option(visibility)
    end
  end

  # Transform function to appropriate output format `FunctionDefinition` or `FunctionDeclaration`
  def transform_function(func, signature, output_type)
    case output_type
    when :impl      then return testable_definition( func, signature )
    when :interface then return mockable_declaration( func, signature )
    end

    PartializerRuntime.raise_on_option(output_type)
  end

  # Strip decorators from the front of code_block and count how many newlines were removed.
  # Adjust line_num upward so that emitted #line directives remain accurate.
  def testable_definition(func, signature)
    new_code_block, stripped_newlines = extract_code_block(func.code_block, func.decorators, func.name)

    return Partials.manufacture_function_definition(
      name:            func.name,
      signature:       signature,
      source_filepath: func.source_filepath,
      line_num:        adjust_line_num(func.line_num, stripped_newlines),
      code_block:      new_code_block
    )
  end

  # A signature sourced from a CFunctionDefinition never carries a trailing semicolon (it's
  # followed by a body, not one), but a signature sourced from a CFunctionDeclaration always does
  # (it's a bare prototype). Strip it here so callers can render "#{signature};" uniformly
  # regardless of which kind of function this interface entry came from. A mock always returns,
  # so a mock declared never to return would contradict itself. Every noreturn marking stays behind.
  def mockable_declaration(func, signature)
    return Partials.manufacture_function_declaration(
      name:      func.name,
      signature: without_noreturn( signature ).strip.sub(/;\s*\z/, '')
    )
  end

  def without_noreturn(signature)
    stripped = signature.gsub( NORETURN_MARKINGS, '' )
    return stripped == signature ? signature : stripped.squeeze( ' ' )
  end

  # Replace a C variable declaration in a text block with a no-op expression.
  #
  # Substitutes the first occurrence of `original_decl` in `text` with:
  #   (void)0; /* <placeholder> */
  # The caller supplies a unique `placeholder` token for the comment slot. Once every
  # rename is done, the caller restores `original_decl` in place of the placeholder, so no
  # rename can reach the restored text.
  #
  # Block form of `sub` is used so that `\` and `&` in the declaration are not
  # interpreted as regex replacement backreferences.
  #
  # @param text          [String] Code text to modify (e.g., a function code_block or body)
  # @param original_decl [String] Declaration text to replace (should be stripped of surrounding whitespace)
  # @param placeholder   [String] Opaque token to embed in the comment (caller replaces it afterwards)
  # @return [String] Modified text with declaration replaced by a no-op expression
  def replace_declaration_with_noop(text, original_decl, placeholder)
    replace_compound_declaration_with_noops(text, original_decl, placeholder, 1)
  end

  # Replace a C compound variable declaration with N no-op expressions and a single comment.
  #
  # Generates `count` `(void)0;` expressions where the final one carries a comment
  # containing `placeholder`. The result replaces the first occurrence of `original_decl`
  # in `text`. The caller supplies `count` = number of variables in the compound statement
  # and a single unique `placeholder` token. After all variable renames are complete, the
  # caller restores `original_decl` by replacing the placeholder with the original text.
  #
  # Block form of `sub` is used so that `\` and `&` in the declaration are not interpreted
  # as regex replacement backreferences.
  #
  # @param text          [String] Code text to modify (e.g., a function code_block or body)
  # @param original_decl [String] Declaration text to replace (should be stripped of surrounding whitespace)
  # @param placeholder   [String] Opaque token to embed in the single trailing comment
  # @param count         [Integer] Number of no-op expressions to insert (one per variable)
  # @return [String] Modified text
  def replace_compound_declaration_with_noops(text, original_decl, placeholder, count)
    noops   = "(void)0; " * (count - 1)
    comment = "(void)0; /* `#{placeholder}` replaced with no-op plus variable renamed & promoted to module-scope */"
    text.sub(original_decl) { noops + comment }
  end

  # Rename C identifiers throughout a text block, each as a whole token.
  #
  # Renaming `count` changes `count = 0`, `(count)`, `count==5`, `*count` and `count[0]`, but
  # not `count_down`, `up_count` or `recount`. A literal's text is data the program uses, such
  # as a format string naming the variable, so it stays, and so does a comment. A member or a
  # tag sharing the name stays too. See Partials.rename_identifiers.
  #
  # @param text    [String] Code text to process
  # @param renames [Hash{String => String}] Each identifier to replace, with its replacement
  # @return [String] Modified text with every mapped identifier renamed
  def rename_c_identifiers(text, renames)
    return Partials.rename_identifiers( text, renames )
  end

  # Stamp the originating source filepath onto each function in a collection.
  #
  # Mutates each element of `funcs` in place by assigning `filepath` to its
  # `source_filepath` field. Called before any line-number search so the field
  # is always populated regardless of whether a line number is ultimately found.
  #
  # @param funcs    [Array<CFunctionDefinition>] Functions to annotate
  # @param filepath [String] Path to the originating C source file
  def stamp_source_filepaths(funcs, filepath)
    funcs.each { |func| func.source_filepath = filepath }
  end

  # Locate each function's line number by searching the original C source file once.
  #
  # Used when the global fallback mode is active — i.e., preprocessed output is
  # unavailable for all functions in the current context.
  #
  # @param code_blocks [Array<String>] Function definition texts to search for
  # @param filepath    [String] Path to the C source file to search
  # @return [Array<Integer, nil>] Each 1-indexed source line number, or nil where not found
  def locate_functions_in_source(code_blocks:, filepath:)
    return @code_finder.find_all_in_c_file( filepath, code_blocks )
  end

  # Locate each declaration's line number in the text of the file it came from.
  #
  # The original file holds only its own lines, so a match there can't belong to a header it
  # includes. Preprocessed output can't promise that, since it carries every included header.
  #
  # Comments are blanked first, newlines kept, so a commented-out copy of a declaration is
  # never taken for it. Blanking passes over the whole file, so it happens once for them all.
  #
  # @param signatures [Array<String>] Declaration texts as extracted, each ending in its semicolon
  # @param text       [String] Full text of the original header or source file
  # @return [Array<Integer, nil>] Each declaration's 1-indexed line number, or nil if not found
  def locate_declarations_in_text(signatures:, text:)
    code = _without_comments( text )
    return signatures.map { |signature| @code_finder.find_in_c_string( code, signature ) }
  end

  # Locate each function's line number using preprocessed output with C source fallback.
  #
  # Two-strategy lookup, each file read once for all the functions it serves:
  #   1. Search the GCC-preprocessed directives-only file, whose line markers give original lines.
  #   2. Search the original C source file for each function step 1 didn't find.
  #
  # @param code_blocks           [Array<String>] Function definition texts to search for
  # @param filepath              [String] Path to the original C source file (fallback target)
  # @param preprocessed_filepath [String] Path to the preprocessed directives-only file
  # @return [Array<Integer, nil>] Each 1-indexed source line number, or nil where neither search finds it
  def locate_functions_via_preprocessed(code_blocks:, filepath:, preprocessed_filepath:)
    lines   = @code_finder.find_all_in_preprocessed_file( preprocessed_filepath, code_blocks )
    missing = lines.each_index.select { |index| lines[index].nil? }
    return lines if missing.empty?

    msg = "Using fallback C function location search for #{filepath}"
    missing.each { @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING ) }

    found = @code_finder.find_all_in_c_file( filepath, missing.map { |index| code_blocks[index] } )
    missing.zip( found ) { |index, line_num| lines[index] = line_num }

    return lines
  end

  # Format per-function line-number results as a list of human-readable strings.
  #
  # Produces one entry per function in the form `"name(): <line_num>"`.
  # Functions with no resolved line number are rendered with `'N/A'`.
  # The returned array is passed directly to `@loginator.log_list` for debug output.
  #
  # @param funcs [Array<CFunctionDefinition>] Functions with `name` and `line_num` fields
  # @return [Array<String>]
  def format_line_number_list(funcs)
    funcs.map do |func|
      "#{func.name}(): #{func.line_num.nil? ? 'N/A' : func.line_num.to_s()}"
    end
  end

  private

  # A literal stays, since a comment marker inside one starts no comment
  def _without_comments(text)
    return text.gsub( Partials::LITERAL_OR_COMMENT ) { |found| found.start_with?( '/' ) ? found.gsub( /[^\n]/, ' ' ) : found }
  end

  # Does any decorator in a list matche any private keyword (case-insensitive)
  def is_function_private?(decorators)
    return decorators.any? do |decorator|
      CExtractorConstants::PRIVATE_KEYWORDS.any? { |keyword| decorator.downcase == keyword.downcase }
    end
  end

  # Strip decorator keywords from the front of code_block and count leading newlines removed.
  #
  # Decorators live only in the text before the function's name. Each is removed there as a
  # whole token, so the same word inside the name, an attribute string or the body stays. Leading
  # whitespace is then trimmed. Returns the trimmed code block and a count of the newlines
  # removed from the leading portion. The caller adjusts line_num with that count so that
  # emitted #line directives in generated source remain accurate.
  #
  # @param code_block  [String]        Raw function source text (decorators + signature + body)
  # @param decorators  [Array<String>] Decorator keywords from CFunctionDefinition#decorators
  # @param name        [String]        Function name, which ends the decorator region
  # @return [Array(String, Integer)]   [trimmed_code_block, leading_newline_count]
  def extract_code_block(code_block, decorators, name)
    cut      = CExtractorFunctions.name_position( code_block, name ) || 0
    stripped = CExtractorFunctions.remove_tokens( code_block[0...cut], decorators ) + code_block[cut..]
    leading  = stripped[/\A\s*/]
    stripped = stripped.lstrip
    return stripped, leading.count("\n")
  end

  # Offset a source line number by the count of newlines stripped from the front of a code block.
  #
  # When decorator keywords occupy one or more lines before the function's return type, those
  # lines are removed from the emitted code_block. The #line directive must be bumped forward
  # by the same count so it still points at the return type in the original source file.
  #
  # Returns nil unchanged when line_num was not resolved.
  def adjust_line_num(line_num, stripped_newlines)
    return line_num if line_num.nil?
    line_num + stripped_newlines
  end

end