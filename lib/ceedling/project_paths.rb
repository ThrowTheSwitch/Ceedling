# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'pathname'
require 'rbconfig'

# One spelling for every path a project names.
#
# A place can be written many ways: relative or absolute, with `./`, `..`, `~`, backslashes,
# or through a symlink. Intake spells each path once, relative to the working directory
# (`canonical`). Comparisons then use whole directories, never text prefixes (`contains?`).
# BuildSubpath places build files from these spellings.
#
# Pure functions over strings, except where a function says it reads the disk, and no
# dependency on DIY, so the launcher in bin/ shares it.
module ProjectPaths

  DECORATOR = /\A[+-]:/
  WINDOWS   = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|msys|ucrt/i) ? true : false

  @lock         = Mutex.new
  @working_dirs = {}
  @absolutes    = {}

  # The working directory with every symlink resolved. Reads the disk once per directory.
  def self.working_dir
    pwd = Dir.pwd
    return @lock.synchronize { @working_dirs[pwd] ||= File.realpath( pwd ) }
  end

  # A path written as a project file writes it, in Ceedling's form: trimmed, `/`-separated,
  # with no trailing separator, and `~` read as the home directory. A `+:`/`-:` decorator is
  # kept. `~user` is left as written.
  def self.standardize(path)
    path = path.to_s.strip.tr( '\\', '/' )
    decorator = path[DECORATOR] || ''
    path = expand_home( path.delete_prefix( decorator ).strip )
    path = path.sub( %r{/+\z}, '' ) unless path.match?( %r{\A(?:[A-Za-z]:)?/+\z} )
    return decorator + path
  end

  # `path` as an absolute path, its `..` and `.` resolved against the working directory
  # without reading the disk. A drive letter is upper case. Remembered for each working
  # directory and home directory, since a build compares the same few roots many times.
  def self.absolute(path)
    return path if clean_absolute?( path )

    key    = [Dir.pwd, Dir.home, path.to_s]
    cached = @lock.synchronize { @absolutes[key] }
    return cached unless cached.nil?

    absolute = absolute_of( path ).freeze
    return @lock.synchronize { @absolutes[key] = absolute }
  end

  # The one spelling intake records for `path`: relative to the working directory, with the
  # symlinks along its existing part resolved. A path with no relative form (another drive,
  # a UNC share) stays absolute. Reads the disk.
  def self.canonical(path)
    return relative( real_absolute( path ) )
  end

  # `absolute` with the symlinks along its existing part resolved. Reads the disk.
  def self.real_absolute(path)
    return real( absolute( path ) )
  end

  # `absolute` relative to the working directory, or absolute when it has no relative form.
  # The working directory itself is `.`.
  def self.relative(absolute)
    return absolute if unc?( absolute )

    # Most paths lie below the working directory, which needs no Pathname walk
    base = working_dir
    return '.' if same?( absolute, base )
    return absolute[(base.length + 1)..] if clean_absolute?( absolute ) and starts_with?( absolute, "#{base}/" )

    return Pathname.new( absolute ).relative_path_from( Pathname.new( base ) ).to_s
  rescue ::ArgumentError
    return absolute
  end

  # Whether `path` is `root` or lies below it, compared as whole directories. Windows folds case.
  def self.contains?(root, path)
    return !subdir_below( root, path ).nil?
  end

  # The directories from `root` down to `path`: '' for `root` itself, or nil when `path`
  # doesn't lie below `root`. Never holds `..`, and is never absolute.
  def self.subdir_below(root, path)
    base = absolute( root )
    full = absolute( path )
    return '' if same?( base, full )

    prefix = base.end_with?( '/' ) ? base : "#{base}/"
    return nil unless starts_with?( full, prefix )

    return full[prefix.length..]
  end

  # A path's segments, `.` and empty segments dropped
  def self.segments(path)
    return path.to_s.split( %r{[\\/]} ).reject { |segment| segment.empty? || segment == '.' }
  end

  def self.absolute?(path)
    return path.start_with?( '/' ) || path.match?( %r{\A[A-Za-z]:/} )
  end

  # A Windows share. Elsewhere a doubled leading separator is the filesystem root.
  def self.unc?(path)
    return WINDOWS && path.start_with?( '//' )
  end

  # Whether two spellings are the same text, folding case on Windows
  def self.same?(a, b)
    return WINDOWS ? a.casecmp?( b ) : a == b
  end

  def self.starts_with?(path, prefix)
    return WINDOWS ? path.downcase.start_with?( prefix.downcase ) : path.start_with?( prefix )
  end

  # Already absolute as `absolute` would spell it: rooted (with an upper case drive on
  # Windows), with no `.` or `..` segment, doubled or trailing `/`, or backslash
  def self.clean_absolute?(path)
    return false unless path.is_a?( String )
    return false unless WINDOWS ? path.match?( %r{\A[A-Z]:/} ) : path.start_with?( '/' )

    return !path.match?( %r{//|/\.\.?(?:/|\z)|\\} ) && (path.length <= 3 || !path.end_with?( '/' ))
  end

  # A `~user` path names a directory of that name, which File.expand_path would read as the
  # user's home (or raise for no such user). A share's `..` never leaves the share.
  def self.absolute_of(path)
    path = standardize( path )
    return unc_absolute( path ) if unc?( path )

    path = "./#{path}" if path.start_with?( '~' )
    return File.expand_path( path, working_dir ).squeeze( '/' ).sub( /\A[a-z](?=:)/ ) { |drive| drive.upcase }
  end

  def self.unc_absolute(path)
    server, share, *rest = path.split( '/' ).reject { |segment| segment.empty? || segment == '.' }
    kept = rest.each_with_object( [] ) { |segment, resolved| segment == '..' ? resolved.pop : resolved.push( segment ) }
    return "//#{[server, share, *kept].compact.join( '/' )}"
  end

  def self.expand_home(path)
    return path unless path == '~' || path.start_with?( '~/' )

    return Dir.home + path.delete_prefix( '~' )
  end

  # The real path of the longest existing part of `absolute`, with the rest appended
  def self.real(absolute)
    return File.realpath( absolute ) if File.exist?( absolute )

    existing = absolute
    missing  = []
    until File.exist?( existing ) || existing == File.dirname( existing )
      missing.unshift( File.basename( existing ) )
      existing = File.dirname( existing )
    end

    return absolute unless File.exist?( existing )

    return File.join( File.realpath( existing ), *missing )
  end

  private_class_method :clean_absolute?, :absolute_of, :unc_absolute, :expand_home, :real

end
