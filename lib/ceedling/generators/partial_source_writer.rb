# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'

# Writes a Partial's implementation source one item at a time.
#
# GeneratorPartials decides what each item is. The writer keeps the state that spans items: an
# open run of carried prototypes inside its GCC pragmas, a #line that points at another file,
# the blank lines between functions, and the functions already written.
#
# A #line ties generated code back to its original file and line, so debuggers, compiler
# messages and gcov coverage all point at the real file. After a located item, a #line hands
# attribution back to this file before the next item without a location of its own. That only
# holds if this file's line count matches what each #line promises, which is why the file is
# written in binary mode and every line written here is counted.
class PartialSourceWriter

  # Carried prototypes can repeat a declaration a header already made. These pragmas keep GCC's
  # -Wredundant-decls quiet for just those lines. Compilers that don't define __GNUC__ never see them.
  REDUNDANT_DECLS_PUSH = "#if defined(__GNUC__)\n#pragma GCC diagnostic push\n#pragma GCC diagnostic ignored \"-Wredundant-decls\"\n#endif\n" unless const_defined?(:REDUNDANT_DECLS_PUSH, false)
  REDUNDANT_DECLS_POP  = "#if defined(__GNUC__)\n#pragma GCC diagnostic pop\n#endif\n" unless const_defined?(:REDUNDANT_DECLS_POP, false)

  # Passes writes through and counts the lines written, so a #line can name this file's own next line
  class LineCountingIO
    attr_reader :lines

    def initialize(io)
      @io    = io
      @lines = 0
    end

    def <<(text)
      text = text.to_s
      @io << text
      @lines += text.count( "\n" )
      return self
    end
  end

  # @param io                       [IO]          Output file handle
  # @param filepath                 [String, nil] This file's own path, named when attribution returns to it
  # @param suppress_redundant_decls [Boolean]     Whether carried prototypes sit inside GCC pragmas
  def initialize(io:, filepath:, suppress_redundant_decls:)
    @io        = LineCountingIO.new( io )
    @filepath  = filepath
    @suppress  = suppress_redundant_decls
    @wrapped   = false # a run of prototypes is open inside its pragmas
    @anchored  = false # the last #line named another file
    @last_was_function = false
    @written   = false
    @functions = Set.new
  end

  def preamble(includes)
    @io << "// Ceedling generated file\n"
    includes.each { |include| @io << "#{include}\n" }
    @io << "\n"
  end

  # A line of text with no location of its own, such as a variable or bare macro invocation
  def text(text)
    _close_run
    _hand_back
    @io << text
    _wrote( function: false )
  end

  # A carried prototype, written as the user spelled it, so `extern inline` keeps making this
  # file hold the external definition
  def prototype(decl)
    _open_run
    _attribute( decl )
    @io << decl.signature.strip << "\n"
    _wrote( function: false )
  end

  # A selected function or carried helper. A name already written is skipped.
  def function(func)
    return if func.nil? or @functions.include?( func.name )

    _close_run
    # Blank line before a function when preceded by a non-function item
    @io << "\n" if @written and !@last_was_function
    _attribute( func )
    @io << func.code_block << "\n\n"
    @functions << func.name
    _wrote( function: true )
  end

  def finish
    _close_run
  end

  private

  def _open_run
    return if @wrapped or !@suppress

    @io << REDUNDANT_DECLS_PUSH
    @wrapped = true
  end

  def _close_run
    @io << REDUNDANT_DECLS_POP if @wrapped
    @wrapped = false
  end

  # A located item takes a #line naming its own file and line. Any other item belongs to this file.
  def _attribute(item)
    return _hand_back unless item.line_num and item.source_filepath

    @io << _line_marker( item.line_num, item.source_filepath )
    @anchored = true
  end

  # What follows a located item belongs to this file again. The directive itself takes a line,
  # so the next line is two past the count so far.
  def _hand_back
    @io << _line_marker( @io.lines + 2, @filepath ) if @anchored and @filepath
    @anchored = false
  end

  # Forward slashes, since a backslash in a #line string starts an escape sequence
  def _line_marker(line_num, filepath)
    return "#line #{line_num} \"#{filepath.tr( '\\', '/' )}\"\n"
  end

  def _wrote(function:)
    @last_was_function = function
    @written           = true
  end
end
