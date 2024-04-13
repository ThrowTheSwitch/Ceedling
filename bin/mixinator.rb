require 'deep_merge'

class Mixinator

  constructor :path_validator, :yaml_wrapper, :logger

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

    # Build list of hashses to facilitate deduplication
    cmdline.each {|filepath| assembly << {'command line' => filepath}}
    assembly += env
    config.each {|filepath| assembly << {'project configuration' => filepath}}

    # Remove duplicates inline
    #  1. Expand filepaths to absolute paths for correct deduplication
    #  2. Remove duplicates
    assembly.uniq! {|entry| File.expand_path( entry.values.first )}

    # Return the compacted list (in merge order)
    return assembly
  end

  def merge(config:, mixins:, silent:)
    mixins.each do |mixin|
      source = mixin.keys.first
      filepath = mixin.values.first

      _mixin = @yaml_wrapper.load( filepath )

      # Hnadle an empty mixin (it's unlikely but logically coherent)
      _mixin = {} if _mixin.nil?

      # Sanitize the mixin config by removing any :mixins section (these should not end up in merges)
      _mixin.delete(:mixins)

      # Merge this bad boy
      config.deep_merge( _mixin )

      # Log what filepath we used for this mixin
      @logger.log( " + Merged #{'(empty) ' if _mixin.empty?}#{source} mixin using #{filepath}" ) if !silent
    end

    # Validate final configuration
    msg = "Final configuration is empty"
    raise msg if config.empty?
  end

end