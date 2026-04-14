# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class CExtractorDefinitions

  constructor :c_extractor_code_text

  # Tracks brace depth but terminates on ';' rather than '}' — not suitable for collect_balanced()
  # Try to extract a C typedef declaration from the scanner.
  # Called as a feature extractor by CExtractor#extract_next_feature.
  # Collects everything from the `typedef` keyword through the terminating `;`
  # (handling nested braces for struct/union/enum bodies, string literals,
  # and comments) and returns it as a raw string including any trailing newline.
  # Comments are replaced with a single space; string literals are verbatim.
  #
  # @param scanner [StringScanner] positioned at the start of potential typedef
  # @return [Array(Boolean, String)]
  #   [true,  "typedef struct { int x; } Point;\n"] — full typedef text
  #   [false, nil                                  ] — no typedef keyword here; nothing consumed
  def try_extract_typedef(scanner)
    return [false, nil] unless scanner.check(/typedef\b/)

    text  = +''
    depth = 0   # brace nesting — typedef body terminates only at depth == 0

    until scanner.eos?
      ch = scanner.peek(1)

      if ch == '"' || ch == "'"
        # Capture string/char literals verbatim — a ';' inside must not terminate
        before = scanner.pos
        @c_extractor_code_text.skip_c_string(scanner, ch)
        text << scanner.string[before...scanner.pos]

      elsif scanner.check(%r{/[/*]})
        # Replace comment with a single space — a ';' inside must not terminate
        @c_extractor_code_text.skip_comment(scanner)
        text << ' '

      elsif scanner.scan(/\{/)
        depth += 1
        text  << '{'

      elsif scanner.scan(/\}/)
        depth -= 1
        text  << '}'

      elsif depth == 0 && scanner.scan(/;/)
        text << ';'
        text << (scanner.scan(/[ \t]*\n/) || '')  # absorb optional trailing newline
        return [true, text]

      else
        text << scanner.getch
      end
    end

    [false, nil]   # EOF without finding ';'
  end

  # Tracks brace depth and uses post-body lookahead to distinguish type definitions from
  # variable declarations — not suitable for collect_balanced()
  #
  # Try to extract a file-scope struct, enum, or union type definition (non-typedef form).
  # Called as a feature extractor by CExtractor#extract_next_feature.
  # Collects standalone aggregate type definitions (body required, ';' follows '}' directly
  # with only optional whitespace/comments between) as raw text.
  # Comments are replaced with a single space; string literals are verbatim.
  #
  # Handles:
  #   struct [tag] { member-list };
  #   enum   [tag] { enumerator-list };
  #   union  [tag] { member-list };
  #
  # Does NOT handle (returns [false, nil], scanner unchanged):
  #   struct/enum/union { ... } declarator;  — variable declaration; falls to variable extractor
  #   struct/enum/union tag;                 — forward declaration without body; not collected
  #
  # @param scanner [StringScanner] positioned at potential aggregate definition
  # @return [Array(Boolean, String|nil)]
  #   [true,  "struct Foo { int x; };\n"] — full verbatim aggregate definition text
  #   [false, nil                        ] — not a standalone aggregate definition; scanner unchanged
  def try_extract_aggregate_definition(scanner)
    return [false, nil] unless scanner.check(/(?:struct|enum|union)\b/)

    start_pos = scanner.pos
    text      = +''
    depth     = 0

    until scanner.eos?
      ch = scanner.peek(1)

      if ch == '"' || ch == "'"
        # Capture string/char literals verbatim — ';' or '{'/'}' inside must not affect state
        before = scanner.pos
        @c_extractor_code_text.skip_c_string(scanner, ch)
        text << scanner.string[before...scanner.pos]

      elsif scanner.check(%r{/[/*]})
        # Replace comment with a single space — ';' inside must not terminate
        @c_extractor_code_text.skip_comment(scanner)
        text << ' '

      elsif scanner.scan(/\{/)
        depth += 1
        text  << '{'

      elsif scanner.scan(/\}/)
        depth -= 1
        text  << '}'

        if depth == 0
          # Body closed. Speculatively advance past whitespace/comments to peek at next char.
          # Do NOT commit whitespace to text yet — we may need to rollback entirely.
          ws_start = scanner.pos
          loop do
            init = scanner.pos
            scanner.skip(/\s+/)
            @c_extractor_code_text.skip_comment(scanner) if scanner.check(%r{/[/*]})
            break if scanner.pos == init
          end

          if scanner.peek(1) == ';'
            # Standalone type definition — commit
            text << scanner.string[ws_start...scanner.pos]  # include whitespace before ';'
            text << scanner.scan(/;/)
            text << (scanner.scan(/[ \t]*\n/) || '')         # absorb optional trailing newline
            return [true, text]
          else
            # Declarator present (variable name, '*', '[', etc.) — not a standalone type definition.
            # Rollback entirely so the variable extractor sees the full text.
            scanner.pos = start_pos
            return [false, nil]
          end
        end

      elsif depth == 0 && scanner.scan(/;/)
        # Hit ';' at depth 0 before any '{' — forward declaration or variable declaration.
        # Neither is a standalone aggregate type definition; rollback.
        scanner.pos = start_pos
        return [false, nil]

      else
        text << scanner.getch
      end
    end

    # EOF without completing extraction — rollback
    scanner.pos = start_pos
    [false, nil]
  end

end
