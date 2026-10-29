# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/file_path_utils'  # for glob handling class methods
require 'ceedling/project_paths'
require 'ceedling/config/build_root_policy'

# Checks the paths a project file names against the filesystem: each :paths and :files
# entry, and paths named singly
class ConfiguratorPathsValidator

  constructor :config_walkinator, :file_wrapper, :loginator, :reportinator

  # Walk into config hash. verify existence of path(s) at given key depth.
  # Paths are either full simple paths or a simple portion of a path up to a glob.
  def validate_path_list(config, *keys)
    list, depth = @config_walkinator.fetch_value( *keys, hash:config )
    return false if list.nil?

    # Trimming add/subtract notation and glob specifiers leaves nothing of a path that
    # begins with a glob, so there is nothing to check
    missing = checked_bases( list ).reject { |path| path.empty? or @file_wrapper.exist?( path ) }

    walk = @reportinator.generate_config_walk( keys, depth )
    missing.each { |path| log_error( "Config path #{walk} => '#{path}' does not exist in the filesystem." ) }

    return missing.empty?
  end


  # Validate :paths entries, exercising each entry as Ceedling directory glob (variation of Ruby glob)
  def validate_paths_entries(config, key)
    return validate_entries( config, :paths, key ) { |entry, walk, build_root| valid_paths_entry?( entry, walk, build_root ) }
  end


  # Validate :files entries, exercising each entry as FileList glob
  def validate_files_entries(config, key)
    return validate_entries( config, :files, key ) { |entry, walk, build_root| valid_files_entry?( entry, walk, build_root ) }
  end


  # A build root of its own, warning of each :paths and :files entry within it (BuildRootPolicy)
  def validate_build_root(config)
    root    = config[:project][:build_root].to_s
    problem = BuildRootPolicy.problem( root )
    log_error( BuildRootPolicy.message( root, problem ) ) unless problem.nil?
    return false unless problem.nil?

    BuildRootPolicy.warnings( root, config ) { |keys| @reportinator.generate_config_walk( keys ) }.each { |warning| log_complaint( warning ) }
    return true
  end


  # Simple path verification
  def validate_filepath_simple(path, *keys)
    return true if @file_wrapper.exist?( path )

    walk = @reportinator.generate_config_walk( keys, keys.size )
    log_error( "Config path '#{path}' associated with #{walk} does not exist in the filesystem." )
    return false
  end

  ### Private ###

  private

  # Each entry of one :paths or :files list, usable and passing `check`
  def validate_entries(config, section, key)
    list, _ = @config_walkinator.fetch_value( section, key, hash:config )
    return false if list.nil?

    walk       = @reportinator.generate_config_walk( [section, key] )
    build_root = config.dig( :project, :build_root )
    return list.map { |entry| usable_entry?( entry, walk ) && yield( entry, walk, build_root ) }.all?
  end

  # Each additive entry's path up to its first glob. An entry YAML read as something other
  # than a string, and a `-:` entry, which may name nothing, are left to the entries validation.
  def checked_bases(list)
    return list.grep( String ).select { |path| FilePathUtils.add_path?( path ) }.map { |path| FilePathUtils::no_decorators( path ) }
  end

  # A :paths or :files entry that names no path, or wraps its path in quotes, usually
  # quotes only the path after its decoration. YAML keeps those quote marks as part of
  # the value, so the hint points at quoting the whole entry. YAML also reads an unquoted
  # decoration with nothing after it (`- -:`) as a one-key mapping rather than a string.
  ENTRY_QUOTING_HINT = 'Quote the whole entry, decoration included (e.g. "-:path/to/file.c"), ' +
                       'not only the path after its +: or -: decoration.'

  def usable_entry?(entry, walk)
    path = entry.is_a?( String ) ? FilePathUtils::no_aggregation_decorators( entry ) : ''

    problem =
      if !entry.nil? and !entry.is_a?( String ) then "is not a path (YAML read it as a #{entry.class})"
      elsif path.empty? then 'names no path'
      elsif path.start_with?( '"', "'" ) then 'wraps its path in quotes'
      end
    return true if problem.nil?

    log_error( "#{walk} => '#{entry}' #{problem}" )
    log_error( ENTRY_QUOTING_HINT )
    return false
  end

  # A path naming a file is ignored with a warning. Any other entry must yield directories,
  # except a subdirectories glob of a directory that has none, and a `-:` entry.
  def valid_paths_entry?(entry, walk, build_root)
    path = FilePathUtils::no_aggregation_decorators( entry )

    if @file_wrapper.exist?( path ) and !@file_wrapper.directory?( path )
      log_complaint( "#{walk} => '#{path}' is a filepath and will be ignored (FYI :paths is directory-oriented while :files is file-oriented)" )
      return true
    end

    return valid_subtraction?( entry, path, walk, build_root ) unless FilePathUtils.add_path?( entry )
    return true if globbed_directories?( path ) or path =~ /\/\*{1,2}$/

    log_error( "#{walk} => '#{path}' yielded no directories -- matching glob is malformed or directories do not exist" )
    return false
  end

  # A `-:` entry leaves out what it names, or warns of naming nothing. A subdirectories glob
  # names its directory too.
  def valid_subtraction?(entry, path, walk, build_root)
    named = path.match?( %r{/\*{1,2}\z} ) ? @file_wrapper.exist?( FilePathUtils.no_decorators( entry ) ) : @file_wrapper.exist?( path )
    return true if named or globbed_directories?( path )

    return subtracts_nothing( entry, walk, build_root, 'directory' )
  end

  # A `-:` entry names what a build leaves out, so naming nothing is no error. Below the build
  # root, where nothing exists before a first build, it passes without a word.
  def subtracts_nothing(entry, walk, build_root, kind)
    unless build_root and ProjectPaths.contains?( build_root, FilePathUtils.no_decorators( entry ) )
      log_complaint( "#{walk} => '#{entry.strip}' leaves out nothing; no #{kind} matches it" )
    end

    return true
  end

  # #104 -- FilePathUtils.subdirectory_glob escapes literal brackets in the path, so they
  # are matched rather than read as a glob character class
  def globbed_directories?(path)
    return @file_wrapper.directory_listing( FilePathUtils.subdirectory_glob( path ) ).any? { |entry| @file_wrapper.directory?( entry ) }
  end

  # A path naming a directory is ignored with a warning. Any other entry must yield files,
  # except a `-:` entry.
  def valid_files_entry?(entry, walk, build_root)
    path = FilePathUtils::no_aggregation_decorators( entry )

    if @file_wrapper.exist?( path ) and @file_wrapper.directory?( path )
      log_complaint( "#{walk} => '#{path}' is a directory path and will be ignored (FYI :files is file-oriented while :paths is directory-oriented)" )
      return true
    end

    # #104 -- literal brackets are escaped so they are matched rather than read as a glob
    return true unless @file_wrapper.instantiate_file_list( FilePathUtils.escape_glob_brackets( path ) ).size.zero?
    return subtracts_nothing( entry, walk, build_root, 'file' ) unless FilePathUtils.add_path?( entry )

    log_error( "#{walk} => '#{path}' yielded no files -- matching glob is malformed or files do not exist" )
    return false
  end

  def log_error(message)
    @loginator.log( message, Verbosity::ERRORS )
  end

  def log_complaint(message)
    @loginator.log( message, Verbosity::COMPLAIN )
  end

end
