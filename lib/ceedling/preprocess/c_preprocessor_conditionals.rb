# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/encodinator'

##
## Lightweight C Preprocessor Conditional Block Tracker
## =====================================================
##
## Tracks the active/inactive state of C conditional blocks
## (`#ifdef`/`#ifndef`/`#if`/`#elif`/`#else`/`#endif`) against a list of
## defined macro names. Intended for use in text-only (fallback) preprocessing
## paths where a real C preprocessor is unavailable.
##
## Feed one logical line at a time to `process_directive`. After each call,
## `active?` returns whether the current position is inside an active block.
## Nesting is fully tracked via a stack.
##
## Evaluation rules:
##   #ifdef  MACRO          → active when MACRO is in defines list
##   #ifndef MACRO          → active when MACRO is NOT in defines list
##   #if 0                  → always inactive
##   #if 1                  → always active
##   #if defined(MACRO)     → active when MACRO in defines list
##   #if !defined(MACRO)    → active when MACRO NOT in defines list
##   #elif defined(MACRO)   → active when prior branch was inactive AND MACRO in defines
##   #else                  → active when all prior branches were inactive
##   #endif                 → pops the innermost stack frame
##   Complex #if expression → treated as active (conservative: include the block)
##
## Expects lines pre-cleaned by `code_lines` / `clean_encoding` (comments
## stripped, continuations joined). Does not raise on multi-byte characters.
##
## Known limitation: A `#ifdef` appearing inside a multi-line C block comment
## may be misidentified as a real directive if the caller uses raw (non-comment-
## stripped) lines. This is an accepted limitation of lightweight text processing.
##
class CPreprocessorConditionals

  def initialize(defines)
    # Normalize defines array: strip leading -D, strip =value suffix, keep name only
    @defined_macros = normalize_defines(defines)
    @stack = []  # Each frame: {active: bool, seen_true_branch: bool}
  end

  # Feed one logical, comment-stripped, continuation-joined line.
  # Updates the conditional block state.
  def process_directive(line)
    _line = line.clean_encoding.lstrip

    case _line
    when /^#\s*ifdef\s+(\w+)/
      push( macro_defined?($1) )

    when /^#\s*ifndef\s+(\w+)/
      push( !macro_defined?($1) )

    when /^#\s*if\s+0\b/
      push( false )

    when /^#\s*if\s+1\b/
      push( true )

    when /^#\s*if\s+!\s*defined\s*\(\s*(\w+)\s*\)/
      push( !macro_defined?($1) )

    when /^#\s*if\s+defined\s*\(\s*(\w+)\s*\)/
      push( macro_defined?($1) )

    when /^#\s*if\b/
      # Complex or unrecognized #if expression — treat as active (conservative)
      push( true )

    when /^#\s*elif\s+!\s*defined\s*\(\s*(\w+)\s*\)/
      handle_elif( !macro_defined?($1) )

    when /^#\s*elif\s+defined\s*\(\s*(\w+)\s*\)/
      handle_elif( macro_defined?($1) )

    when /^#\s*elif\s+0\b/
      handle_elif( false )

    when /^#\s*elif\s+1\b/
      handle_elif( true )

    when /^#\s*elif\b/
      # Complex or unrecognized #elif expression — treat as active (conservative)
      handle_elif( true )

    when /^#\s*else\b/
      handle_else

    when /^#\s*endif\b/
      @stack.pop unless @stack.empty?
    end
  end

  # True when the current position is inside an active conditional block
  # (or outside all blocks, which is always active).
  def active?
    # If outside all blocks, active by default.
    # Otherwise, the innermost frame must be active.
    return true if @stack.empty?
    @stack.last[:active]
  end

  # Reset state for reuse (e.g. across multiple files)
  def reset
    @stack.clear
  end

  ### Private ###

  private

  def normalize_defines(defines)
    return [] if defines.nil?
    defines.map do |d|
      # Strip leading -D if present, then strip =value suffix
      name = d.to_s.sub(/\A-D/, '')
      name.split('=').first.strip
    end.reject(&:empty?).uniq
  end

  def macro_defined?(name)
    @defined_macros.include?( name.strip )
  end

  # When pushing a new frame, "outer" is the frame we're currently inside
  # (the last frame before the push). If the stack is empty we are at the
  # top level, which is always active.
  def push(condition)
    enclosing_active = @stack.empty? ? true : @stack.last[:active]
    active = enclosing_active && condition
    @stack.push( {active: active, seen_true_branch: active} )
  end

  # For #elif/#else, "outer" is the frame ENCLOSING the current block —
  # one level above the frame being mutated. If there is no enclosing
  # frame the current block is at the outermost level, which is always active.
  def enclosing_active?
    @stack.size <= 1 ? true : @stack[-2][:active]
  end

  def handle_elif(condition)
    return if @stack.empty?
    frame = @stack.last
    # An elif branch activates only if: no prior true branch was seen, the
    # enclosing block is active, and this branch's condition is true.
    if !frame[:seen_true_branch] && enclosing_active? && condition
      frame[:active] = true
      frame[:seen_true_branch] = true
    else
      frame[:active] = false
    end
  end

  def handle_else
    return if @stack.empty?
    frame = @stack.last
    # else activates only if no prior true branch AND enclosing block is active
    frame[:active] = !frame[:seen_true_branch] && enclosing_active?
    frame[:seen_true_branch] = true if frame[:active]
  end

end
