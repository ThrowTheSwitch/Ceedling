# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for FileList
require 'fileutils'
require 'pathname'
require 'tmpdir'
require 'ceedling/constants'
require 'ceedling/system_wrapper'


class FileWrapper

  constructor :loginator, :verbosinator

  # Platform practical filepath length ceilings, used only as a diagnostic heuristic --
  # neither Ruby nor the host OS exposes a portable, runtime-queryable API for this.
  # POSIX pathconf(2) is the real mechanism (PATH_MAX can vary by filesystem/mount
  # point, so it's a per-path query, not a system-wide sysconf() value), but Ruby's Etc
  # module defines the PC_PATH_MAX/PC_NAME_MAX pathconf constants without exposing a
  # pathconf method to use them. Windows has no Ruby-accessible equivalent at all
  # without an FFI dependency. These are the stable, documented OS/libc defaults
  # instead: Windows' legacy MAX_PATH, and macOS/Linux's PATH_MAX from their own libc
  # headers (a project can opt into longer paths on some platforms, but that's not
  # safely assumable here, so these stay conservative).
  PATH_LENGTH_LIMITS = {
    windows: 260,
    macos:   1024,
    linux:   4096,
  }.freeze

  def self.generate_include_guard(name)
    # abc-XYZ.h --> _ABC_XYZ_H_
    base = File.basename(name, '.*') # Remove any extension
    guard = '__' + CEEDLING_GENERATED + '_' + base.gsub(/\W/, '_').upcase + '_H__'
    return guard
  end

  def get_expanded_path(path)
    return File.expand_path(path)
  end

  def basename(path, extension=nil)
    return File.basename(path, extension) if extension
    return File.basename(path)
  end

  def exist?(filepath)
    return true if (filepath == NULL_FILE_PATH)
    return File.exist?(filepath)
  end

  def extname(filepath)
    return File.extname(filepath)
  end

  # Is path a directory and does it exist?
  def directory?(path)
    return File.directory?(path)
  end

  def relative?(path)
    return Pathname.new( path).relative?
  end

  def dirname(path)
    return File.dirname(path)
  end

  def directory_listing(glob)
    # Note: `sort()` to ensure platform-independent directory listings (Github Issue #860)
    # FNM_PATHNAME => Case insensitive globs
    return Dir.glob(glob, File::FNM_PATHNAME).sort()
  end

  def rm_f(filepath, options={})
    FileUtils.rm_f(filepath, **options)
  end

  def rm_r(filepath, options={})
    FileUtils.rm_r(filepath, **options={})
  end

  def rm_rf(path, options={})
    FileUtils.rm_rf(path, **options={})
  end

  def cp(source, destination, options={})
    check_path_length(destination, origin: 'FileWrapper#cp')
    FileUtils.cp(source, destination, **options)
  end

  def cp_r(source, destination, options={})
    FileUtils.cp_r(source, destination, **options)
  end

  def mv(source, destination, options={})
    FileUtils.mv(source, destination, **options)
  end

  def compare(from, to)
    return FileUtils.compare_file(from, to)
  end

  # Is filepath A newer than B?
  def newer?(filepathA, filepathB)
    return false unless File.exist?(filepathA)
    return false unless File.exist?(filepathB)

    return (File.mtime(filepathA) > File.mtime(filepathB))
  end

  def open(filepath, flags)
    # Only writing/creating/appending can run into a platform's filepath length ceiling --
    # a read-mode open is against a path that (if it exists) already fit on disk.
    check_path_length(filepath, origin: 'FileWrapper#open') if flags.to_s =~ /[wa+]/
    File.open(filepath, flags) do |file|
      yield(file)
    end
  end

  def read(filepath, length=nil)
    return File.read(filepath, length)
  end

  # Reads raw bytes with no text-mode translation. `File.read`'s default text
  # mode silently converts CRLF to LF on Windows but not on Unix-like
  # platforms, so the same on-disk bytes can read back differently depending
  # on the host OS. Callers needing a deterministic, platform-independent view
  # of a file's actual bytes -- content hashing chief among them -- use this
  # instead.
  def read_binary(filepath)
    return File.binread(filepath)
  end

  def touch(filepath, options={})
    FileUtils.touch(filepath, **options)
  end

  def write_blank_file(filepath)
    check_path_length(filepath, origin: 'FileWrapper#write_blank_file')
    File.open(filepath, 'w') do |file|
      file.write("// Ceedling intentionally blank file\n\n")
    end
  end

  def write(filepath, contents, flags='w')
    check_path_length(filepath, origin: 'FileWrapper#write')
    File.open(filepath, flags) do |file|
      file.write(contents)
    end
  end

  def readlines(filepath)
    return File.readlines(filepath)
  end

  def instantiate_file_list(files=[])
    return FileList.new(files)
  end

  def mkdir(folder)
    check_path_length(folder, origin: 'FileWrapper#mkdir')
    return FileUtils.mkdir_p(folder)
  end

  # Creates a uniquely-named, empty directory nested inside `parent` and returns its path.
  # `parent` must already exist. Collision-free even across concurrent callers targeting
  # the same `parent` -- Dir.mktmpdir retries internally on name clash.
  def mkdir_tmp(prefix, parent)
    path = Dir.mktmpdir(prefix, parent)
    check_path_length(path, origin: 'FileWrapper#mkdir_tmp')
    return path
  end

  # Warn as a path's length approaches its platform's practical ceiling, and flag if it
  # reaches or exceeds it. Logging only -- never raises or blocks the caller's own
  # operation, which will surface its own real failure on its own if the OS actually
  # rejects the path. The calling context (`origin:`) is only included at DEBUG
  # verbosity -- otherwise the message stays plain, since the path itself is normally
  # enough and repeated origin labels add noise at everyday verbosity levels.
  def check_path_length(path, origin:)
    limit  = path_length_limit
    length = File.expand_path(path).length

    prefix = @verbosinator.should_output?(Verbosity::DEBUG) ? "#{origin} ⏩️ " : ''

    if length >= limit
      @loginator.log(
        "#{prefix}Path length (#{length}) reaches or exceeds this platform's practical limit (#{limit}): #{path}",
        Verbosity::ERRORS
      )
    elsif length >= (limit * 0.95)
      @loginator.log(
        "#{prefix}Path length (#{length}) is approaching this platform's practical limit (#{limit}): #{path}",
        Verbosity::COMPLAIN
      )
    end
  end

  private

  def path_length_limit
    return PATH_LENGTH_LIMITS[:windows] if SystemWrapper.windows?
    return PATH_LENGTH_LIMITS[:macos] if SystemWrapper.macos?
    return PATH_LENGTH_LIMITS[:linux]
  end

end
