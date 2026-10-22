# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Stages files away from their neighbors so a quoted #include cannot reach one.
#
# C's `#include "..."` checks the including file's own directory before any -I search
# path. A file staged alone in a fresh directory has no neighbors there, so its quoted
# includes fall through to the search paths. Mocks and Partials substitute a header only
# by search-path order, so Ceedling stages a file whenever a real header beside it would
# otherwise win (see test_invoker/HEADER_COLLISIONS.md).
#
# Callers decide when isolation applies and which search paths follow it. This class
# owns staging, release, and mapping a copy's path back to its original. It keeps no
# state between calls, so one instance serves every thread.
class QuoteIncludeIsolator

  constructor :file_wrapper, :loginator

  # One staged directory and the originals copied into it, keyed original => copy.
  Isolation = Struct.new( :dir, :copies ) do
    def copy_of(original)
      copies.fetch( original )
    end

    # Replaces every copy's path in `text` with its original's.
    #
    # gcc writes a space in a dependency path as `\ `, so the escaped form is replaced
    # too. Paths take on `text`'s own encoding so binary file content stays comparable.
    def restore_paths(text)
      copies.reduce( text ) do |restored, (original, copy)|
        restored = replace( restored, make_escaped( copy ), make_escaped( original ) )
        replace( restored, copy, original )
      end
    end

    private

    def make_escaped(path)
      path.gsub( ' ' ) { '\\ ' }
    end

    # A block replacement keeps backslashes in a Windows path literal.
    def replace(text, from, to)
      text.gsub( from.dup.force_encoding( text.encoding ) ) { to.dup.force_encoding( text.encoding ) }
    end
  end

  # Copies each of `files` alone into one fresh directory nested inside `parent`.
  #
  # A copy is named by basename alone so the directory holds nothing but what was staged.
  # `preserve_location` opens each copy with a `#line` directive naming its original.
  # Diagnostics, `__FILE__`, debug info and coverage data then report the original file
  # at its original line numbers. The caller releases the result.
  def isolate(parent:, files:, preserve_location: false)
    dir    = @file_wrapper.mkdir_tmp( nil, parent )
    copies = files.to_h { |file| [file, stage_copy( file, dir, preserve_location )] }

    return Isolation.new( dir, copies )
  end

  # Stages `files` for the duration of the block alone.
  def within(parent:, files:, preserve_location: false)
    isolation = isolate( parent: parent, files: files, preserve_location: preserve_location )
    yield isolation
  ensure
    release( isolation.dir ) if isolation
  end

  def release(dir)
    @loginator.log( "Removing isolated directory '#{dir}'", Verbosity::DEBUG )
    @file_wrapper.rm_rf( dir )
  end

  # Rewrites a dependency file so it names each original rather than its copy.
  #
  # A compiler records the file it was handed, which for an isolated compile is the copy.
  # The copy disappears on release, so a dependency list still naming it would read as a
  # vanished antecedent on the next build. Bytes are preserved, line endings included.
  def restore_dependencies(isolation, filepath)
    return unless @file_wrapper.exist_with_retry?( filepath )

    content  = @file_wrapper.read_binary( filepath )
    restored = isolation.restore_paths( content )

    @file_wrapper.write( filepath, restored, 'wb' ) unless restored == content
  end

  # Whether `file` quote-includes a header named `basename`.
  #
  # This is the mechanism that lets `file` reach a real header beside it. A path prefix
  # ahead of the name still matches. The scan is literal text, with no macro expansion
  # and no conditional evaluation, so a computed #include can be missed and one behind a
  # false condition can match. Either miss only changes whether a rare case is isolated.
  # It never invents a substitution risk where none exists.
  def includes_by_name?(file, basename)
    return false unless @file_wrapper.exist?( file )

    content = @file_wrapper.read( file )
    content.match?( /#include\s*"(?:[^"]*\/)?#{Regexp.escape( basename )}"/ )
  end

  private

  def stage_copy(file, dir, preserve_location)
    copy = File.join( dir, File.basename( file ) )

    if preserve_location
      @file_wrapper.write( copy, line_directive( file ) + @file_wrapper.read_binary( file ), 'wb' )
    else
      @file_wrapper.cp( file, copy )
    end

    @loginator.log( "Staged isolated copy: '#{file}' -> '#{copy}'", Verbosity::DEBUG )
    copy
  end

  # A C string literal needs its backslashes and quotes escaped, as in a Windows path.
  def line_directive(file)
    escaped = file.gsub( '\\' ) { '\\\\' }.gsub( '"' ) { '\\"' }
    "#line 1 \"#{escaped}\"\n".b
  end

end
