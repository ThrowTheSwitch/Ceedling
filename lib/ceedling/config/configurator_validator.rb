# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/file_path_utils'  # for glob handling class methods
require 'ceedling/config/config_matchinator'


class ConfiguratorValidator

  constructor :config_walkinator, :file_wrapper, :loginator, :reportinator, :tool_validator

  # Walk into config hash verify existence of data at key depth
  def exists?(config, *keys)
    hash, _ = @config_walkinator.fetch_value( *keys, hash:config )
    return true unless hash.nil?

    log_error( "Required config file entry #{@reportinator.generate_config_walk( keys )} does not exist." )
    return false
  end

  # Walk into config hash. verify existence of path(s) at given key depth.
  # Paths are either full simple paths or a simple portion of a path up to a glob.
  def validate_path_list(config, *keys)
    list, depth = @config_walkinator.fetch_value( *keys, hash:config )
    return false if list.nil?

    # Trimming add/subtract notation and glob specifiers leaves nothing of a path that
    # begins with a glob, so there is nothing to check
    paths   = list.map { |path| FilePathUtils::no_decorators( path ) }
    missing = paths.reject { |path| path.empty? or @file_wrapper.exist?( path ) }

    walk = @reportinator.generate_config_walk( keys, depth )
    missing.each { |path| log_error( "Config path #{walk} => '#{path}' does not exist in the filesystem." ) }

    return missing.empty?
  end


  # Validate :paths entries, exercising each entry as Ceedling directory glob (variation of Ruby glob)
  def validate_paths_entries(config, key)
    list, _ = @config_walkinator.fetch_value( :paths, key, hash:config )
    return false if list.nil?

    walk = @reportinator.generate_config_walk( [:paths, key] )
    return list.map { |path| valid_paths_entry?( FilePathUtils::no_aggregation_decorators( path ), walk ) }.all?
  end


  # Validate :files entries, exercising each entry as FileList glob
  def validate_files_entries(config, key)
    list, _ = @config_walkinator.fetch_value( :files, key, hash:config )
    return false if list.nil?

    walk = @reportinator.generate_config_walk( [:files, key] )
    return list.map { |path| valid_files_entry?( FilePathUtils::no_aggregation_decorators( path ), walk ) }.all?
  end


  # Simple path verification
  def validate_filepath_simple(path, *keys)
    return true if @file_wrapper.exist?( path )

    walk = @reportinator.generate_config_walk( keys, keys.size )
    log_error( "Config path '#{path}' associated with #{walk} does not exist in the filesystem." )
    return false
  end

  def validate_tool(config:, key:, respect_optional:true)
    # Get tool
    walk = [:tools, key]
    tool, _ = @config_walkinator.fetch_value( *walk, hash:config )

    arg_hash = {
      tool: tool,
      name: @reportinator.generate_config_walk( walk ),
      extension: config[:extension][:executable],
      respect_optional: respect_optional
    }

    return @tool_validator.validate( **arg_hash )
  end


  # Raises with the reason a matcher is malformed
  def validate_matcher(matcher)
    return validate_regex_matcher( matcher ) if ConfigMatchinator.regex_form?( matcher )

    # A substring or wildcard matcher allows only these characters
    invalid = matcher.gsub( /[a-z0-9 \/\.\-_\*]/i, '' ).chars.uniq
    return if invalid.empty?

    raise "invalid substring or wildcard characters #{invalid.map { |char| "'#{char}'" }.join( ', ' )}"
  end

  ### Private ###

  private

  # A path naming a file is ignored with a warning. Any other entry must yield directories,
  # except a subdirectories glob of a directory that has none.
  def valid_paths_entry?(path, walk)
    if @file_wrapper.exist?( path ) and !@file_wrapper.directory?( path )
      log_complaint( "#{walk} => '#{path}' is a filepath and will be ignored (FYI :paths is directory-oriented while :files is file-oriented)" )
      return true
    end

    return true if globbed_directories?( path ) or path =~ /\/\*{1,2}$/

    log_error( "#{walk} => '#{path}' yielded no directories -- matching glob is malformed or directories do not exist" )
    return false
  end

  # #104 -- FilePathUtils.subdirectory_glob escapes literal brackets in the path, so they
  # are matched rather than read as a glob character class
  def globbed_directories?(path)
    return @file_wrapper.directory_listing( FilePathUtils.subdirectory_glob( path ) ).any? { |entry| @file_wrapper.directory?( entry ) }
  end

  # A path naming a directory is ignored with a warning. Any other entry must yield files.
  def valid_files_entry?(path, walk)
    if @file_wrapper.exist?( path ) and @file_wrapper.directory?( path )
      log_complaint( "#{walk} => '#{path}' is a directory path and will be ignored (FYI :files is file-oriented while :paths is directory-oriented)" )
      return true
    end

    # #104 -- literal brackets are escaped so they are matched rather than read as a glob
    return true unless @file_wrapper.instantiate_file_list( FilePathUtils.escape_glob_brackets( path ) ).size.zero?

    log_error( "#{walk} => '#{path}' yielded no files -- matching glob is malformed or files do not exist" )
    return false
  end

  def validate_regex_matcher(matcher)
    Regexp.compile( matcher[1..-2] )
  rescue RegexpError => ex
    raise "invalid regular expression: #{ex.message}"
  end

  def log_error(message)
    @loginator.log( message, Verbosity::ERRORS )
  end

  def log_complaint(message)
    @loginator.log( message, Verbosity::COMPLAIN )
  end

end
