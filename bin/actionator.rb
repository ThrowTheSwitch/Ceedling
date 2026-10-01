# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'

# Actionator performs the file operations behind `ceedling new`, `ceedling example`,
# `ceedling upgrade`, and the vendoring of Ceedling into a project. It replaces the
# narrow slice of Thor::Actions that Ceedling used, reached previously through an
# ActionsWrapper mixin.
#
# Thor::Actions was dropped to remove the `erb` gem as a Ceedling dependency.
# Thor loads `erb` at require time for its own template action, which Ceedling never
# called. Thor itself remains Ceedling's CLI framework. Only the Actions mixin is gone.
#
# Status line output is deliberately byte-compatible with what Thor::Actions emitted,
# so upgrading Ceedling does not change the appearance of these commands. The one
# intentional difference is the policy deciding whether to colorize. Thor consulted
# the stream and the TERM and NO_COLOR environment variables. Actionator consults
# Ceedling's own decorator policy, which honors CEEDLING_DECORATORS, and additionally
# requires a terminal so redirected output stays free of escape sequences.
#
# Two Thor behaviors are deliberately not reproduced. Thor prompted on stdin when a
# destination file existed with differing content and neither force nor skip was
# given, which would hang a build. Actionator raises instead. Thor also interpolated
# `%method%` sequences found in destination paths by calling the named method.
# Destination paths here are user-supplied project names, so that behavior is a
# hazard rather than a feature.
class Actionator

  constructor :file_wrapper, :loginator

  JUNK_FILE_EXCLUDE_REGEX = /(\.DS_Store)|(thumbs\.db)/

  BOLD  = "\e[1m"
  CLEAR = "\e[0m"

  # Thor's own verb-to-color assignments, preserved so status lines are unchanged.
  VERB_COLORS = {
    :create    => "\e[32m", # green
    :exist     => "\e[34m", # blue
    :identical => "\e[34m", # blue
    :force     => "\e[33m", # yellow
    :remove    => "\e[31m", # red
    :chmod     => "\e[32m", # green
    :gsub      => "\e[32m", # green
  }.freeze

  # Width Thor right-justified its status verbs to, followed by a two space gutter.
  VERB_WIDTH = 12

  attr_accessor :source_root, :destination_root

  # Captured once rather than read per call. A later Dir.chdir must not change how
  # relative destinations resolve or how status line paths are shortened partway
  # through a command.
  def setup
    @source_root = nil
    @destination_root = @file_wrapper.get_expanded_path( '.' )
  end


  def copy_file(source, destination, force: false, verbose: true)
    src  = resolve_source( source )
    dest = resolve_destination( destination )

    if !@file_wrapper.exist?( dest )
      write_file( src, dest )
      status( :create, dest, verbose )
      return
    end

    if @file_wrapper.compare( src, dest )
      status( :identical, dest, verbose )
      return
    end

    unless force
      raise CeedlingException.new(
        "Refusing to overwrite differing file #{relative_destination( dest )} without force"
      )
    end

    status( :force, dest, verbose )
    write_file( src, dest )
  end


  def copy_directory(source, destination, force: false, verbose: true,
                     exclude_pattern: JUNK_FILE_EXCLUDE_REGEX)
    # Trailing separators arrive from the vendored component paths in cli_helper.
    # They would otherwise survive into the glob and into the rebasing below.
    src  = resolve_source( source ).sub( /\/+\z/, '' )
    dest = resolve_destination( destination )

    # Thor reported the destination directory itself ahead of its contents.
    make_directory( dest, verbose: verbose )

    # FileWrapper#directory_listing does not escape glob metacharacters, and a
    # Ceedling install path can contain them. See issue #104.
    listing = @file_wrapper.directory_listing( File.join( escape_globs( src ), '**', '*' ) )

    listing.each do |entry|
      next if @file_wrapper.directory?( entry )
      next if entry.match( exclude_pattern )

      copy_file( entry, rebase( entry, src, dest ), force: force, verbose: verbose )
    end
  end


  def make_directory(destination, verbose: true)
    dest = resolve_destination( destination )
    existed = @file_wrapper.exist?( dest )

    @file_wrapper.mkdir( dest ) unless existed
    status( existed ? :exist : :create, dest, verbose )
  end


  # Reports before testing for existence, matching Thor. The upgrade path removes a
  # vendor directory that legitimately may not be there, and its output has always
  # named the directory either way.
  def remove_directory(path, verbose: true)
    dest = resolve_destination( path )

    status( :remove, dest, verbose )
    @file_wrapper.rm_rf( dest ) if @file_wrapper.exist?( dest )
  end


  # Prints nothing. This never went through Thor, so it never produced a status line.
  def touch_file(path)
    @file_wrapper.touch( path )
  end


  def chmod(path, mode, verbose: true)
    dest = resolve_destination( path )

    status( :chmod, dest, verbose )
    @file_wrapper.chmod( dest, mode )
  end


  # Does not raise when the pattern matches nothing, matching Thor's non-bang
  # variant. Both call sites stamp conditionally, so no match is a legitimate result.
  def gsub_file(path, pattern, replacement, verbose: true)
    dest = resolve_destination( path )

    status( :gsub, dest, verbose )

    contents = @file_wrapper.read_binary( dest )
    @file_wrapper.write( dest, contents.gsub( pattern, replacement ), 'wb' )
  end

  ### Private ###

  private

  def resolve_source(source)
    raise CeedlingException.new( 'Actionator source root has not been set' ) if @source_root.nil?

    # An absolute source is returned unchanged, which matters because cli_helper
    # passes absolute paths for gathered documentation and license files while
    # cli_handler passes paths relative to the Ceedling installation.
    src = File.expand_path( source, @source_root )

    unless @file_wrapper.exist?( src )
      raise CeedlingException.new(
        "Could not find '#{source}' relative to Ceedling source root '#{@source_root}'"
      )
    end

    return src
  end


  def resolve_destination(destination)
    return File.expand_path( destination, @destination_root )
  end


  # Binary mode is required. A text-mode write translates line endings on Windows,
  # which corrupts the vendored ceedling launch script and vendored source files.
  def write_file(source, destination)
    @file_wrapper.mkdir( @file_wrapper.dirname( destination ) )
    @file_wrapper.write( destination, @file_wrapper.read_binary( source ), 'wb' )
  end


  def rebase(entry, source_dir, destination_dir)
    return File.join( destination_dir, entry.sub( source_dir, '' ) )
  end


  def escape_globs(path)
    return path.gsub( /[*?{}\[\]]/ ) { |char| '\\' + char }
  end


  def status(verb, path, verbose)
    return unless verbose

    label = verb.to_s.rjust( VERB_WIDTH )
    label = BOLD + VERB_COLORS[verb] + label + CLEAR if colorize?

    @loginator.console( "#{label}  #{relative_destination( path )}", LogLabels::NONE )
  end


  def colorize?
    return @loginator.decorators && $stdout.tty?
  end


  # Shortens a path that sits under the destination root, so `ceedling new` reports
  # myproject/src rather than an absolute path the user never typed.
  def relative_destination(path)
    root = @destination_root
    return path unless path.start_with?( root )

    remainder = path[root.size..]
    return '' if remainder.nil? || remainder.empty?
    return path unless remainder.start_with?( File::SEPARATOR )

    return remainder[1..]
  end

end
