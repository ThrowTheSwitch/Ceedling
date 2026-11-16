# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/c_extractor/c_extractor_declarator'
require 'ceedling/c_extractor/c_extractor_functions'

module Partials

  # A selected definition's head written from its signature, when a macro hides a decorator the
  # written head can't be stripped of. The implementation header declares that signature, so
  # the definition agrees with it.
  #
  # The head through its declarator's last ')' becomes the signature on one line, followed by
  # the newlines that stood between the name and that ')'. The declarator's ')' ends the
  # parameter list or a GNU attribute after it. Every body line keeps its line, and the name's
  # line is where #line points. What follows stays as written, such as a C23 attribute or a
  # comment. A bare attribute macro there appears twice, expanded in the signature and as
  # written after it, which compilers accept.
  #
  # Some heads stay as written. A K&R definition declares its parameters ahead of the body, each
  # ending in ';'. A brace inside the parameter list hides where the body opens. A signature
  # holding a directive, as a `_Pragma` expands to, can't share a line with the head.
  module DefinitionHead
    # Gives the rewritten code block and how many lines the head held ahead of the name, or nil
    # when nothing is hidden or the head can't be split
    def self.rewrite(func, signature)
      return nil if Array( func.hidden_decorators ).empty? or signature.match?( /^[ \t]*#/ )

      code   = func.code_block
      points = _split_points( code, func.name )
      return nil if points.nil?

      name, close   = points
      ahead, within = _head_lines( code, name, close )
      return _one_line( signature ) + ("\n" * within) + code.byteslice( close.. ), ahead
    end

    # Where the name starts, as a character index, and the byte just past the parameter list.
    # The name is looked for in the head alone, since the body may call the function.
    def self._split_points(code, name)
      close = CExtractorFunctions.signature_end( code )
      return nil if close.nil?

      # The gap is nil when a brace inside the list opens ahead of the declarator's end. A ';'
      # in it ends a K&R parameter declaration.
      gap = code.byteslice( close, CExtractorFunctions.body_start( code ) - close )
      return nil if gap.nil? or _blanked( gap ).include?( ';' )

      at = CExtractorFunctions.name_position( _blanked( code.byteslice( 0, close ) ), name )
      return at && [at, close]
    end

    # Literals and comments as spaces, character for character, so nothing in one passes for
    # code while every character keeps its place. Fallback leaves comments in the text.
    def self._blanked(text)
      return text.gsub( CExtractorDeclarator::LITERAL_OR_COMMENT ) { |found| found.gsub( /[^\n]/, ' ' ) }
    end

    # The lines a head holds ahead of its name, and between its name and its list's ')'
    def self._head_lines(code, name, close)
      ahead = code[0...name]
      return ahead.count( "\n" ), code.byteslice( ahead.bytesize, close - ahead.bytesize ).count( "\n" )
    end

    def self._one_line(text)
      return text.gsub( /[ \t]*\r?\n[ \t]*/, ' ' ).strip
    end
  end

end
