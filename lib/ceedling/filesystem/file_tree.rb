# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'ceedling/constants'
require 'ceedling/exceptions'

# Walks and copies trees of regular files without `lstat`. On some filesystems `lstat`
# reports a regular file as a directory, and any copy that classifies by it puts a directory
# where the file belongs. FileTree lists a directory with `Dir.children`, which reads names
# without glob syntax, and classifies each entry with `File.stat`, which follows links.
#
# Links in a source tree are followed, and a copy holds only regular files and directories.
# A link loop or a dangling link raises rather than copying part of a tree.
#
# This is best effort. It removes the dependence on `lstat`, and trusts `stat` in its place.
module FileTree

  # Errors that clear on their own, such as a scanner or a sync client holding a file open.
  # Any other error fails a copy at once.
  TRANSIENT_ERRORS = %i[EACCES EBUSY EPERM EINTR].filter_map { |name| Errno.const_get( name ) if Errno.const_defined?( name ) }.freeze

  Result = Struct.new( :copied, :unchanged, :healed, keyword_init: true )

  # Yields each regular file below `root` as its path relative to `root` and its full path,
  # sorted within each directory. Returns an Enumerator without a block. An entry whose name
  # `skip` accepts is neither yielded nor entered.
  def self.each_file(root, skip: nil)
    return enum_for( :each_file, root, skip: skip ) unless block_given?

    each_entry( root, skip: skip ) { |relative, path, directory| yield( relative, path ) unless directory }
  end

  # Yields each directory and regular file below `root`, a directory ahead of its contents,
  # as its relative path, its full path, and whether it is a directory
  def self.each_entry(root, skip: nil, &block)
    raise CeedlingException, "'#{root}' is not a directory" unless File.directory?( root )

    walk( root, nil, [real_path( root )], skip, &block )
  end

  # Brings every file below `source` up to date below `destination` and returns a Result. A
  # file that matches its source is left alone. One that differs or is missing is written by
  # `publish`, a callable given the source and destination paths. A directory where a file
  # belongs, or a file where a directory belongs, is removed first. Files `destination` has
  # beyond `source` are left alone.
  #
  # `publish` is retried after each of `retry_delays` on an error in TRANSIENT_ERRORS.
  # `log`, when given, receives a message, a Verbosity, and a LogLabels value.
  def self.sync(source, destination, publish:, retry_delays: [], sleep: Kernel.method( :sleep ), log: nil)
    return Sync.new( publish: publish, retry_delays: retry_delays, sleep: sleep, log: log ).tree( source, destination )
  end

  # As .sync, for one regular file copied into `destination_dir`
  def self.sync_file(source, destination_dir, publish:, retry_delays: [], sleep: Kernel.method( :sleep ), log: nil)
    return Sync.new( publish: publish, retry_delays: retry_delays, sleep: sleep, log: log ).file( source, destination_dir )
  end

  def self.walk(dir, relative, ancestors, skip, &block)
    names_in( dir ).each do |name|
      next if skip&.call( name )

      path  = File.join( dir, name )
      entry = relative ? File.join( relative, name ) : name
      next yield( entry, path, false ) unless directory_entry?( path )

      yield( entry, path, true )
      walk( path, entry, ancestors + [real_directory( path, ancestors )], skip, &block )
    end
  end

  def self.names_in(dir)
    return Dir.children( dir ).sort
  rescue SystemCallError => e
    raise CeedlingException, "'#{dir}' could not be listed ⏩️ #{e.message}"
  end

  # Whether a listed entry is a directory. Anything but a directory or a regular file raises.
  def self.directory_entry?(path)
    status = stat_of( path )
    return true if status.directory?
    return false if status.file?

    raise CeedlingException, "'#{path}' is a #{status.ftype}, not a file or directory"
  end

  def self.stat_of(path)
    return File.stat( path )
  rescue Errno::ENOENT, Errno::ELOOP
    raise CeedlingException, "'#{path}' is a dangling or unresolvable link"
  rescue SystemCallError => e
    raise CeedlingException, "'#{path}' could not be read ⏩️ #{e.message}"
  end

  def self.real_directory(path, ancestors)
    real = real_path( path )
    raise CeedlingException, "Link loop: '#{path}' resolves to its own ancestor '#{real}'" if ancestors.include?( real )

    return real
  end

  # A directory's real path, for finding loops. A path that cannot be resolved stands for
  # itself, so the walk goes on without that safeguard rather than stopping.
  def self.real_path(path)
    return File.realpath( path )
  rescue SystemCallError
    return File.expand_path( path )
  end

  private_class_method :walk, :names_in, :directory_entry?, :stat_of, :real_directory, :real_path

  # One copy's settings and tallies
  class Sync
    def initialize(publish:, retry_delays:, sleep:, log:)
      @publish      = publish
      @retry_delays = retry_delays
      @sleep        = sleep
      @log          = log
      @result       = Result.new( copied: 0, unchanged: 0, healed: 0 )
    end

    def tree(source, destination)
      raise CeedlingException, "'#{source}' is not a directory" unless File.directory?( source )

      directory( destination )
      FileTree.each_entry( source ) do |relative, path, is_directory|
        target = File.join( destination, relative )
        is_directory ? directory( target ) : publish_file( path, target )
      end
      return @result
    end

    def file(source, destination_dir)
      raise CeedlingException, "'#{source}' is not a regular file" unless File.file?( source )

      directory( destination_dir )
      publish_file( source, File.join( destination_dir, File.basename( source ) ) )
      return @result
    end

    private

    # Destination checks follow links, as `stat` does, so they share the source side's view.
    # A dangling link counts as a file.
    def directory(path)
      return if File.directory?( path )

      with_retries( path ) do
        heal( "Replaced a file where the directory '#{path}' belongs" ) { FileUtils.rm_f( path ) || true } if File.exist?( path ) || File.symlink?( path )
        FileUtils.mkdir_p( path )
      end
    end

    # Every step is retried, since a scanner or sync client can hold the destination too
    def publish_file(source, destination)
      with_retries( destination ) do
        if File.directory?( destination )
          heal( "Replaced a directory where the file '#{destination}' belongs" ) { remove_directory( destination ) }
        elsif identical?( source, destination )
          next @result.unchanged += 1
        end

        @publish.call( source, destination )
        @result.copied += 1
      end
    end

    # Counts and logs a heal the block reports it made
    def heal(message)
      return unless yield

      @result.healed += 1
      log( message, Verbosity::COMPLAIN, LogLabels::NOTICE )
    end

    # Whether this removed the directory. Another run healing the same entry may have removed
    # it, or replaced it with a file already, which stays. FileUtils.rm_rf classifies by
    # `lstat`, so it is reached only for a directory with contents. It works on the
    # destination, and never follows a link out of it.
    def remove_directory(path)
      Dir.rmdir( path )
      return true
    rescue Errno::ENOENT, Errno::ENOTDIR
      return false
    rescue Errno::ENOTEMPTY, Errno::EEXIST
      FileUtils.rm_rf( path )
      return true
    end

    def identical?(source, destination)
      return File.file?( destination ) && File.size( source ) == File.size( destination ) && FileUtils.compare_file( source, destination )
    end

    def with_retries(destination)
      delays = @retry_delays.dup
      begin
        yield
      rescue *TRANSIENT_ERRORS => e
        raise_exhausted( destination, e ) if delays.empty?

        log( "Retrying copy to '#{destination}' after a transient error: #{e.message}", Verbosity::DEBUG, LogLabels::AUTO )
        @sleep.call( delays.shift )
        retry
      end
    end

    def raise_exhausted(destination, error)
      message = "Failed to copy to '#{destination}' after #{@retry_delays.size} retries ⏩️ #{error.message}\n" \
                "Try deleting this project's build/ directory and rebuilding -- or, if the error names a " \
                "path under your Ruby gem install, reinstall the ceedling gem."
      log( message, Verbosity::ERRORS, LogLabels::AUTO )
      raise CeedlingException, message
    end

    def log(message, verbosity, label)
      @log&.call( message, verbosity, label )
    end
  end

end
