# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_runtime'
require 'ceedling/c_extractor/c_extractor_constants'

class PartializerUtils

  constructor :preprocessinator_code_finder, :loginator

  def setup()
    # Aliases
    @code_finder = @preprocessinator_code_finder
  end

  # Check if function decorators match the desired visibility
  def matches_visibility?(decorators, visibility)
    case visibility
    when :public
      return !is_function_private?(decorators)
    when :private
      return is_function_private?(decorators)
    else
      PartializerRuntime.raise_on_option(visibility)
    end
  end

  # Transform function to appropriate output format `FunctionDefinition` or `FunctionDeclaration`
  def transform_function(func, signature, output_type)
    case output_type
    when :impl
      Partials.manufacture_function_definition(
        name: func.name,
        signature: signature,
        source_filepath: func.source_filepath,
        line_num: func.line_num,
        # Extract code block as beginning with the signature to end of original code block.
        # This omits any decorators before signature in original code_block and preserves 
        # original whitespace (i.e. indentation & newlines including connecting signature to body).
        code_block: extract_code_block(func.code_block, signature)
      )
    when :interface
      Partials.manufacture_function_declaration(
        name: func.name,
        signature: signature
      )
    else
      PartializerRuntime.raise_on_option(output_type)
    end
  end

  # Replace a C variable declaration in a text block with a no-op expression.
  #
  # Substitutes the first occurrence of `original_decl` in `text` with:
  #   (void)0; /* <placeholder> */
  # The caller supplies a unique `placeholder` token for the comment slot. This
  # allows subsequent rename operations (which use simple token-bounded substitution
  # with no comment awareness) to run without touching the comment. After all renames
  # are complete, the caller restores `original_decl` by replacing the placeholder.
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

  # Rename a C identifier throughout a text block with token-bounded substitution.
  #
  # Replaces all occurrences of `old_name` that are bounded by C identifier boundaries
  # with `new_name`. Token boundaries use Ruby `\b` (word boundary between
  # `\w` = `[a-zA-Z0-9_]` and `\W`), which exactly matches C identifier boundaries.
  # For example, renaming `count`:
  #   - Matches:     `count = 0`, `(count)`, `count==5`, `*count`, `count[0]`
  #   - No match:    `count_down`, `up_count`, `recount`
  #
  # Note: This method has no comment-awareness. Callers that need comment content
  # preserved verbatim (e.g., no-op placeholders) should use `replace_declaration_with_noop`
  # with an opaque placeholder and restore the original text after renaming.
  #
  # @param text     [String] Code text to process
  # @param old_name [String] Identifier to replace
  # @param new_name [String] Replacement identifier
  # @return [String] Modified text with all token-bounded occurrences renamed
  def rename_c_identifier(text, old_name, new_name)
    text.gsub(/\b#{Regexp.escape(old_name)}\b/, new_name)
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

  # Locate a function's line number by searching the original C source file.
  #
  # Used when the global fallback mode is active — i.e., preprocessed output is
  # unavailable for all functions in the current context. Delegates directly to
  # `code_finder.find_in_c_file`.
  #
  # @param code_block  [String] Function definition text to search for
  # @param filepath    [String] Path to the C source file to search
  # @return [Integer, nil] 1-indexed source line number, or nil if not found
  def locate_function_in_source(code_block:, filepath:)
    @code_finder.find_in_c_file(filepath, code_block)
  end

  # Locate a function's line number using preprocessed output with C source fallback.
  #
  # Two-strategy lookup for a single function:
  #   1. Try the GCC-preprocessed directives-only file — exact match preserving line markers.
  #   2. If that yields nil, fall back to the original C source file.
  #
  # Returns line number or nil if neither approach succeeds.
  #
  # @param code_block            [String] Function definition text to search for
  # @param filepath              [String] Path to the original C source file (fallback target)
  # @param preprocessed_filepath [String] Path to the preprocessed directives-only file
  # @return [Integer, nil] 1-indexed source line number, or nil if not found
  def locate_function_via_preprocessed(code_block:, filepath:, preprocessed_filepath:)
    line_num = @code_finder.find_in_preprpocessed_file(preprocessed_filepath, code_block)
    return line_num unless line_num.nil?

    msg = "Using fallback C function location search for #{filepath}"
    @loginator.log( msg, Verbosity::OBNOXIOUS, LogLabels::WARNING )

    return @code_finder.find_in_c_file(filepath, code_block)
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

  # Does any decorator in a list matche any private keyword (case-insensitive)
  def is_function_private?(decorators)
    return decorators.any? do |decorator|
      CExtractorConstants::PRIVATE_KEYWORDS.any? { |keyword| decorator.downcase == keyword.downcase }
    end
  end

  # Extract code block starting from signature to end of original, omitting any decorators before signature.
  # Preserves original function indentation and newlines.
  def extract_code_block(code_block, signature)
    start_index = code_block.index(signature)
    
    # Handle case where signature is not found in code_block
    if start_index.nil?
      # Raise Ruby ArgumentError not Constructor
      raise ::ArgumentError, "Signature '#{signature}' not found in code block"
    end
    
    # Return code block minus any decorators before signature
    return code_block[start_index..-1]
  end

end