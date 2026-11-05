# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'securerandom'
require 'ceedling/exceptions'

# Windows' path length limits, and a probe of how far past the classic 260 characters
# this Ruby process can actually work.
#
# Windows lifts the 260-character limit for a program only when the host has long paths
# enabled (`LongPathsEnabled` = 1) and the program's manifest declares itself
# long-path-aware. Every RubyInstaller Ruby declares it, yet Ruby before 4.0 still cannot
# list a directory past 260 characters: globs, `Dir.children`, and recursive copies and
# removals fail there, or silently leave entries out, while single files work. The probe
# tests that behavior directly instead of reading version numbers.
#
# The registry is read only to explain a failure, through `query:`: a callable returning
# `reg query` output and whether the query succeeded. WinPathProber runs it as a Ceedling
# tool. `win32/registry` needs Fiddle, which stops being a default gem after Ruby 3.4.
#
# Every filesystem touch goes through `disk:` and every registry read through `query:`,
# so the logic can be specified with no disk at all.
module WinLongPaths

  LIMITS = {
    max_path:      260,    # MAX_PATH, the terminating NUL included
    max_directory: 248,    # CreateDirectory leaves room for an 8.3 file name
    long_paths:    32_767  # The longest path a UNICODE_STRING holds
  }.freeze

  REGISTRY_KEY   = 'HKLM\\SYSTEM\\CurrentControlSet\\Control\\FileSystem'.freeze
  REGISTRY_VALUE = 'LongPathsEnabled'.freeze
  ENABLED        = /LongPathsEnabled\s+REG_DWORD\s+0x1\b/

  # Each probe directory name is this long, so the deep path stays far below Windows'
  # 255-character limit on a single path component
  SEGMENT    = 40
  PROBE_FILE = 'probe.txt'.freeze
  CONTENT    = 'Ceedling long path probe'.freeze

  # The probe's only contact with the filesystem
  module Disk
    def self.mkdir_p(path)     = FileUtils.mkdir_p( path )
    def self.write(path, text) = File.write( path, text )
    def self.read(path)        = File.read( path )
    def self.delete(path)      = File.delete( path )
    def self.rmdir(path)       = Dir.rmdir( path )
    def self.children(path)    = Dir.children( path )
    def self.glob(pattern)     = Dir.glob( pattern )
  end

  # Whether the host has long paths enabled. A missing value, a failed query, or a query
  # that could not run at all reads as disabled.
  def self.registry_enabled?(query:)
    return registry_state( query )[:state] == :enabled
  end

  # Writes, reads, and lists a file in a directory below `root` nested past 260
  # characters, then removes it all. Returns one of:
  #  - `{ support: :full }`: files and directory listings both work
  #  - `{ support: :files_only }`: files work, but listing a directory that deep fails
  #  - `{ support: :none, cause: }`: files fail. The cause comes from the registry, since
  #    Windows reports only "No such file or directory" whatever the reason:
  #    `:registry_disabled`, `:process_not_aware`, or `:probe_failed` (with `error:`) when
  #    the registry can't be read.
  def self.probe(root, query:, disk: Disk)
    directories = probe_directories( File.expand_path( root ) )
    deep        = directories.last
    file        = File.join( deep, PROBE_FILE )

    begin
      return no_support( query ) unless files_work?( disk, deep, file )
      return { support: listings_work?( disk, deep ) ? :full : :files_only }
    ensure
      clean_up( disk, directories, file )
    end
  end

  # A uniquely named directory below `root`, then nested directories until the deepest
  # passes 260 characters by a full segment. Outermost first.
  def self.probe_directories(root)
    directories = [File.join( root, "long_path_probe_#{Process.pid}_#{SecureRandom.hex( 4 )}" )]

    while directories.last.length <= (LIMITS[:max_path] + SEGMENT)
      name = format( '%02d', directories.length ).ljust( SEGMENT, 'x' )
      directories << File.join( directories.last, name )
    end

    return directories
  end

  def self.files_work?(disk, deep, file)
    disk.mkdir_p( deep )
    disk.write( file, CONTENT )
    return disk.read( file ) == CONTENT
  rescue SystemCallError
    return false
  end

  # Checks what the listings return, not only that they return. Ruby 3.0's glob leaves a
  # deep entry out without raising.
  def self.listings_work?(disk, deep)
    return false unless disk.children( deep ).include?( PROBE_FILE )

    return disk.glob( File.join( deep, '*' ) ).any? { |path| File.basename( path ) == PROBE_FILE }
  rescue SystemCallError
    return false
  end

  def self.no_support(query)
    registry = registry_state( query )

    case registry[:state]
    when :enabled  then return { support: :none, cause: :process_not_aware }
    when :disabled then return { support: :none, cause: :registry_disabled }
    else                return { support: :none, cause: :probe_failed, error: registry[:error] }
    end
  end

  # A query that could not run raises a CeedlingException, such as ToolExecutor's
  # ShellException for a missing executable. Its message, on one line, names the reason.
  def self.registry_state(query)
    output, success = query.call
    return { state: (success && output.match?( ENABLED )) ? :enabled : :disabled }
  rescue CeedlingException => e
    return { state: :unknown, error: e.message.split.join( ' ' ) }
  end

  # Ruby before 4.0 can't remove a tree this deep recursively, and it can't list one
  # either, so the probe removes exactly what it made: its file, then each directory,
  # deepest first. Anything already gone, or never made, is skipped.
  def self.clean_up(disk, directories, file)
    begin
      disk.delete( file )
    rescue SystemCallError
      nil
    end

    directories.reverse_each do |directory|
      disk.rmdir( directory )
    rescue SystemCallError
      next
    end
  end

  private_class_method :probe_directories, :files_work?, :listings_work?, :no_support, :registry_state, :clean_up

end
