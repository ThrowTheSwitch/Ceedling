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
    path = expand_home( path.delete_prefix( decorator ) )
    path = path.chomp( '/' ) unless path.match?( %r{\A(?:[A-Za-z]:)?/\z} )
    return decorator + path
  end

  # `path` as an absolute path, its `..` and `.` resolved against the working directory
  # without reading the disk. A drive letter is upper case.
  def self.absolute(path)
    path = standardize( path )
    absolute = unc?( path ) ? path.squeeze( '/' ).sub( %r{\A/}, '//' ) : File.expand_path( path, working_dir )
    return absolute.sub( /\A[a-z](?=:)/ ) { |drive| drive.upcase }
  end

  # The one spelling intake records for `path`: relative to the working directory, with the
  # symlinks along its existing part resolved. A path with no relative form (another drive,
  # a UNC share) stays absolute. Reads the disk.
  def self.canonical(path)
    return relative( real( absolute( path ) ) )
  end

  # `absolute` relative to the working directory, or absolute when it has no relative form.
  # The working directory itself is `.`.
  def self.relative(absolute)
    return absolute if unc?( absolute )

    return Pathname.new( absolute ).relative_path_from( Pathname.new( working_dir ) ).to_s
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

  def self.unc?(path)
    return path.start_with?( '//' )
  end

  # Whether two spellings are the same text, folding case on Windows
  def self.same?(a, b)
    return WINDOWS ? a.casecmp?( b ) : a == b
  end

  def self.starts_with?(path, prefix)
    return WINDOWS ? path.downcase.start_with?( prefix.downcase ) : path.start_with?( prefix )
  end

  def self.expand_home(path)
    return path unless path == '~' || path.start_with?( '~/' )

    return Dir.home + path.delete_prefix( '~' )
  end

  # The real path of the longest existing part of `absolute`, with the rest appended
  def self.real(absolute)
    existing = absolute
    missing  = []
    until File.exist?( existing ) || existing == File.dirname( existing )
      missing.unshift( File.basename( existing ) )
      existing = File.dirname( existing )
    end

    return absolute unless File.exist?( existing )

    return File.join( File.realpath( existing ), *missing )
  end

  private_class_method :expand_home, :real

end
