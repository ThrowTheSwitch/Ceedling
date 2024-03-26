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

  def fetch_env_filepaths(vars)
    var_names = []

    vars.each do |var, filepath|
      # Explicitly ignores CEEDLING_MIXIN_0
      var_names << var if var =~ /CEEDLING_MIXIN_[1-9]\d*/
    end

    # Extract numeric string (guranteed to exist) and convert to integer for ascending sorting
    var_names.sort_by! {|name| name.match(/\d+$/)[0].to_i() }

    _vars = []
    # Iterate over sorted environment variable names
    var_names.each do |name|
      # Insert in array {env var name => filepath}
      _vars << {name => vars[name]}
    end

    # Remove any duplicate filepaths by comparing the full absolute path
    _vars.uniq! {|entry| File.expand_path( entry.values[0] )}

    return _vars
  end

  def validate_env_filepaths(vars)
    validated = true

    vars.each do |entry|
      validated &= @path_validator.validate(
        paths: [entry.values[0]],
        source: "Environment variable `#{entry.keys[0]}` filepath",
      )
    end

    if !validated
      raise 'Mixins environment variables failed validation'
    end
  end

  def dedup_mixins(config:, env:, cmdline:)
    # Remove duplicates
    #  1. Invert the merge order to yield the precedence of mixin selections
    #  2. Expand filepaths to absolute paths for correct deduplication
    #  3. Remove duplicates
    filepaths = (cmdline + env + config).uniq {|entry| File.expand_path( entry )}

    # Return the compacted list in merge order
    return filepaths.reverse()
  end

  def merge(config:, filepaths:)
    filepaths.each do |filepath| 
      mixin = @yaml_wrapper.load( filepath )

      # Report if the mixin was blank or otherwise produced no hash
      raise "Empty mixin configuration in #{filepath}" if config.nil?

      # Sanitize the mixin config by removing any :mixins section (we ignore these in merges)
      mixin.delete(:mixins) if mixin[:mixins]

      # Merge this bad boy
      config.deep_merge( mixin )

      # Log what filepath we used for this mixin
      @logger.log( "Merged mixin configuration from #{filepath}" )
    end
  end

end