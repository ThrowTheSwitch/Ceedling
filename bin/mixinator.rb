# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'deep_merge'

class Mixinator

  constructor :path_validator, :yaml_wrapper, :loginator

  def setup
    # ...
  end

  def validate_cmdline_filepaths(paths)
    validated = @path_validator.validate(
      paths: paths,
      source: 'Filepath argument',
    )

    if !validated
      raise 'Mixins command line failed validation'
    end
  end

  def fetch_env_filepaths(env)
    var_names = []

    env.each do |var, filepath|
      # Explicitly ignores CEEDLING_MIXIN_0
      var_names << var if var =~ /CEEDLING_MIXIN_[1-9]\d*/
    end

    # Extract numeric string (guranteed to exist) and convert to integer for ascending sorting
    var_names.sort_by! {|name| name.match(/\d+$/)[0].to_i() }

    _vars = []
    # Iterate over sorted environment variable names
    var_names.each do |name|
      # Duplicate the filepath string to get unfrozen copy
      # Handle any Windows path shenanigans
      # Insert in array {env var name => filepath}
      path = env[name].dup()
      @path_validator.standardize_paths( path )
      _vars << {name => path}
    end

    # Remove any duplicate filepaths by comparing the full absolute path
    # Higher numbered environment variables removed
    _vars.uniq! {|entry| File.expand_path( entry.values.first )}

    return _vars
  end

  def validate_env_filepaths(vars)
    validated = true

    vars.each do |entry|
      validated &= @path_validator.validate(
        paths: [entry.values.first],
        source: "Environment variable `#{entry.keys.first}` filepath",
      )
    end

    if !validated
      raise 'Mixins environment variables failed validation'
    end
  end

  def assemble_mixins(config:, env:, cmdline:)
    assembly = []

    # Build list of hashses in precedence order to facilitate deduplication
    # Any duplicates at greater indexes are removed
    cmdline.each {|mixin| assembly << {'command line' => mixin}}
    assembly += env
    config.each {|mixin| assembly << {'project configuration' => mixin}}

    # Remove duplicates inline
    #  1. Expand filepaths to absolute paths for correct deduplication (skip expanding simple mixin names)
    #  2. Remove duplicates
    assembly.uniq! do |entry|
      # If entry is filepath, expand it, otherwise leave entry untouched (it's a mixin name only)
      mixin = entry.values.first
      @path_validator.filepath?( mixin ) ? File.expand_path( mixin ) : mixin
    end

    # Return the compacted list in merge order
    #  1. Config
    #  2. Environment variable
    #  3. Command line
    # Later merges take precedence (e.g. command line mixins are last merge)
    return assembly.reverse()
  end

  def merge(builtins:, config:, mixins:)
    mixins.each do |mixin|
      source = mixin.keys.first
      filepath = mixin.values.first

      _mixin = {} # Empty initial value

      # Load mixin from filepath if it is a filepath
      if @path_validator.filepath?( filepath )
        _mixin = @yaml_wrapper.load( filepath )

        # Log what filepath we used for this mixin
        @loginator.log( " + Merging #{'(empty) ' if _mixin.nil?}#{source} mixin using #{filepath}", Verbosity::OBNOXIOUS )

      # Reference mixin from built-in hash-based mixins
      else
        _mixin = builtins[filepath.to_sym()]

        # Log built-in mixin we used
        @loginator.log( " + Merging built-in mixin '#{filepath}' from #{source}", Verbosity::OBNOXIOUS )
      end

      # Hnadle an empty mixin (it's unlikely but logically coherent and a good safety check)
      _mixin = {} if _mixin.nil?

      # Sanitize the mixin config by removing any :mixins section (these should not end up in merges)
      _mixin.delete(:mixins)

      # Merge this bad boy
      config.deep_merge( _mixin )
    end

    # Validate final configuration
    msg = "Final configuration is empty"
    raise msg if config.empty?
  end

end
