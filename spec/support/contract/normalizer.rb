# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'contract/contract'

module Contract

  # Turns the paths a build or a compiler writes into one comparable spelling.
  #
  # A normalized path is relative to the project root, with forward slashes and no `.`
  # segments. A path beside the project keeps its `../`, one in the far directory starts
  # `%{far}/`, and one in this checkout starts `%{ceedling}/`. Anything else outside the
  # workspace is a system file, `<system>`. Temporary directory names a build makes are
  # written `<tmp>`, so two runs compare equal.
  class Normalizer

    SYSTEM = '<system>'.freeze

    # Dir.mktmpdir names, as Ruby forms them
    TMPNAME = /d\d{8}-\d+-[0-9a-z]+/.freeze

    def initialize(workspace)
      @roots = [
        [workspace.app,  ''],
        [workspace.far,  '%{far}/'],
        [workspace.root, '../'],
        [CHECKOUT,       '%{ceedling}/']
      ].map { |dir, prefix| [Normalizer.slashed( dir ), prefix] }
    end

    # One path in the comparable spelling
    def path(raw)
      text = Normalizer.slashed( Normalizer.unquote( raw.to_s.strip ) )
      return text if text.empty?

      if Normalizer.absolute?( text )
        root, prefix = @roots.find { |dir, _| Normalizer.within?( text, dir ) }
        return SYSTEM if root.nil?

        text = prefix + text[root.length..-1].delete_prefix( '/' )
      end

      return Normalizer.clean( text ).gsub( TMPNAME, '<tmp>' )
    end

    # A path with the workspace and checkout prefixes replaced, its separators and `./`
    # kept as written
    def raw(text)
      text = text.to_s.strip
      @roots.each do |dir, prefix|
        [dir, dir.tr( '/', '\\' )].uniq.each do |spelling|
          text = text.gsub( "#{spelling}/", prefix ).gsub( "#{spelling}\\", prefix.tr( '/', '\\' ) ).gsub( spelling, prefix.chomp( '/' ) )
        end
      end
      return text.gsub( TMPNAME, '<tmp>' )
    end

    # Free text, such as an error line, with every workspace path made relative. Times
    # and a linker's section offsets, which vary with nothing a row controls, are masked.
    def text(line)
      return raw( line )
        .gsub( /\b\d+(\.\d+)? (milliseconds|seconds|sec)\b/, '<time>' )
        .gsub( /\(All: [^)]*\)/, '(<time>)' )
        .gsub( /\+0x\h+/, '+<offset>' )
    end

    # -------------------------------------------------------------------------

    def self.slashed(path)
      return path.tr( '\\', '/' )
    end

    def self.unquote(path)
      return path[1..-2] if path.length >= 2 && path.start_with?( '"' ) && path.end_with?( '"' )
      return path
    end

    def self.absolute?(path)
      return path.start_with?( '/' ) || path.match?( %r{\A[A-Za-z]:/} )
    end

    # Whether `path` is `dir` or below it. Windows paths compare without letter case.
    def self.within?(path, dir)
      return false if dir.empty?

      if path.match?( %r{\A[A-Za-z]:/} )
        path = path.downcase
        dir  = dir.downcase
      end
      return path == dir || path.start_with?( "#{dir.chomp( '/' )}/" )
    end

    # Drops empty and `.` segments. `..` stays, since a lexical climb can name a symlink's
    # parent rather than the parent written.
    def self.clean(path)
      lead     = path.start_with?( '/' ) ? '/' : ''
      segments = path.split( '/' ).reject { |segment| segment.empty? || segment == '.' }
      cleaned  = lead + segments.join( '/' )
      return cleaned.empty? ? '.' : cleaned
    end

    # The prerequisites of every rule in a make dependency file, as written.
    #
    # A `\` before a newline continues the line, and `\ ` is a space in a name. A target
    # ends at the first colon followed by space or the line's end, so a drive letter's
    # colon stays in its name.
    def self.parse_d(text)
      joined = text.to_s.gsub( "\r\n", "\n" ).gsub( /\\\n/, ' ' )
      deps   = []

      joined.each_line do |line|
        line = line.chomp
        next if line.strip.empty?

        separator = line.index( /:(\s|\z)/ )
        next if separator.nil?

        tokens( line[(separator + 1)..-1] ).each { |token| deps << token unless deps.include?( token ) }
      end

      return deps
    end

    # Whitespace-separated make tokens, with `\ ` taken as a space and `$$` as `$`
    def self.tokens(text)
      found   = []
      current = +''
      chars   = text.chars
      index   = 0

      while index < chars.size
        char = chars[index]
        if char == '\\' && chars[index + 1] == ' '
          current << ' '
          index += 2
          next
        end

        if char.match?( /\s/ )
          found << current unless current.empty?
          current = +''
        else
          current << char
        end
        index += 1
      end

      found << current unless current.empty?
      return found.map { |token| token.gsub( '$$', '$' ) }
    end

    # Each filename a preprocessor's line markers name, as the marker's string literal
    # holds it, in order of first appearance. Names in angle brackets, such as
    # `<built-in>`, are left out.
    def self.parse_markers(text)
      names = []
      text.to_s.each_line do |line|
        match = line.match( /\A#\s*(?:line\s+)?\d+\s+"((?:\\.|[^"\\])*)"/ )
        next if match.nil?

        name = match[1]
        next if name.start_with?( '<' )

        names << name unless names.include?( name )
      end
      return names
    end

    # A C string literal's content with its escapes undone, as `\\` to `\`
    def self.unescape_c(literal)
      return literal.gsub( /\\(.)/m ) do
        case Regexp.last_match( 1 )
        when 'n' then "\n"
        when 't' then "\t"
        else Regexp.last_match( 1 )
        end
      end
    end

  end

end
