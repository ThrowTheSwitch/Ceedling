# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Mixinator

  constructor :mixin_standardizer, :merginator, :path_validator, :yaml_wrapper, :loginator

  def setup
    # Aliases
    @standardinator = @mixin_standardizer
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
    # === Pass 1: Build combined list in deduplication-priority order ===
    #
    # uniq! (used below) keeps the first occurrence of each mixin and drops
    # later duplicates. To give higher-priority sources the "winning" entry
    # on a collision, we put them first in this pass:
    #
    #   1. Command line --mixin flags    (first → highest dedup priority)
    #   2. CEEDLING_MIXIN_# env vars     (ascending numeric order)
    #   3. Project configuration :enabled mixins (last → lowest dedup priority)
    #
    dedup = []
    cmdline.each {|mixin| dedup << {'command line' => mixin}}
    dedup += env
    config.each  {|mixin| dedup << {'project configuration' => mixin}}

    # Remove duplicate mixins, keeping the highest-priority (first) occurrence.
    # Filepaths are expanded to absolute paths so two relative paths that point
    # to the same file are recognised as duplicates even if written differently.
    # Simple mixin names (no path separators or extension) are compared as-is.
    dedup.uniq! do |entry|
      mixin = entry.values.first
      @path_validator.filepath?( mixin ) ? File.expand_path( mixin ) : mixin
    end

    # === Pass 2: Re-partition into merge order ===
    #
    # Re-group the deduplicated entries by source (preserving within-group
    # order), then concatenate in lowest-to-highest-priority order so that the
    # later (higher-priority) merges win single-value conflicts and so that
    # higher-priority list entries are prepended to appear first:
    #
    #   1. Project configuration :enabled mixins  (merged first — lowest priority)
    #   2. CEEDLING_MIXIN_# environment variables  (ascending numeric order)
    #   3. Command line --mixin flags              (merged last — highest priority)
    #
    config_entries  = dedup.select {|e| e.keys.first == 'project configuration'}
    env_entries     = dedup.select {|e| e.keys.first.start_with?('CEEDLING_MIXIN_')}
    cmdline_entries = dedup.select {|e| e.keys.first == 'command line'}

    return config_entries + env_entries + cmdline_entries
  end

  def mixin(builtins:, config:, mixins:)
    mixins.each do |mixin|
      source = mixin.keys.first
      filepath = mixin.values.first

      _mixin = {} # Empty initial value

      # Load mixin from filepath if it is a filepath
      if @path_validator.filepath?( filepath )
        _mixin = @yaml_wrapper.load( filepath )

        # Log what filepath we used for this mixin
        @loginator.lazy( Verbosity::OBNOXIOUS ) { " + Merging #{'(empty) ' if _mixin.nil?}#{source} mixin using #{filepath}" }

      # Reference mixin from built-in hash-based mixins
      else
        _mixin = builtins[filepath.to_sym()]

        # Log built-in mixin we used
        @loginator.lazy( Verbosity::OBNOXIOUS ) { " + Merging built-in mixin '#{filepath}' from #{source}" }
      end

      # Hnadle an empty mixin (it's unlikely but logically coherent and a good safety check)
      _mixin = {} if _mixin.nil?

      # Nested :mixins sections are not supported — warn and strip before merging
      if _mixin.key?(:mixins)
        msg = "Mixin from #{source} '#{filepath}' contains a `:mixins` section ➡️ Nested mixins are not supported and will be ignored."
        @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::WARNING )
        _mixin.delete(:mixins)
      end

      # Prevent mixin files from injecting their own :history entries
      _mixin.delete(:history)

      # Run special handling using knowledge of Ceedling configuration conventions
      notices = []
      if @standardinator.smart_standardize( config:config, mixin:_mixin, notices:notices )
        notices.each { |msg| @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE ) }
      end

      warnings = []
      if !@merginator.merge( config:config, mixin:_mixin, warnings:warnings )
        msg = "Mixin values from #{filepath} will replace configuration values for incompatible merges..."
        @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
        warnings.each { |msg| @loginator.log( msg, Verbosity::COMPLAIN ) }
      end

      # Record this mixin in the configuration history
      label = case source
              when 'command line'          then '--mixin'
              when 'project configuration' then ':mixins'
              else source # environment variable name (e.g. CEEDLING_MIXIN_1)
              end

      config[:history] ||= {}
      config[:history][:config] ||= []
      if @path_validator.filepath?( filepath )
        config[:history][:config] << "#{filepath} (#{label})"
      else
        config[:history][:config] << "#{filepath} (built-in, #{label})"
      end
    end

    # Validate final configuration
    # Exclude :history — it is internal bookkeeping added by this method and
    # should not be counted as meaningful user configuration content.
    msg = "Final configuration is empty"
    raise msg if (config.keys - [:history]).empty?
  end

end
