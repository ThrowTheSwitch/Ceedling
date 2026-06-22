# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
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

  def validate_cmdline_yaml_strings(yaml_strings)
    # Validate a list of inline YAML strings from --mixin "=..." command line arguments.
    # Errors are accumulated so the user sees all problems before the run aborts.
    # Raises on any validation failure (mirrors validate_mixins behavior for file entries).
    validated = true

    yaml_strings.each_with_index do |str, idx|
      label = "Inline YAML mixin ##{idx + 1}"  # 1-based, matches user's command line order

      # Empty string means the user typed --mixin "=" with nothing after the sigil
      if str.nil? || str.strip.empty?
        @loginator.log( "#{label} is empty", Verbosity::ERRORS, LogLabels::ERROR )
        validated = false
        next
      end

      begin
        parsed = @yaml_wrapper.load_string( str )

        # A Ceedling configuration must be a Hash at the top level; arrays and scalars
        # cannot be merged into config and indicate a user error in the YAML string
        unless parsed.is_a?( Hash )
          @loginator.log(
            "#{label} did not produce a configuration Hash after parsing (got #{parsed.class})",
            Verbosity::ERRORS, LogLabels::ERROR
          )
          validated = false
        end
      rescue => e
        # YAML parse failure: surface the parser message so the user can fix their string
        @loginator.log( "#{label} YAML parse error: #{e.message}", Verbosity::ERRORS, LogLabels::ERROR )
        validated = false
      end
    end

    raise 'Command line --mixin inline YAML failed validation' unless validated
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
    # cmdline entries are pre-tagged {source_label => value} hashes from configinator;
    # they carry either 'command line' (file/builtin) or 'command line (inline)' (YAML string)
    cmdline.each {|mixin| dedup << mixin}
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
    # Include both 'command line' (file/builtin) and 'command line (inline)' (YAML string) entries;
    # relative order within this group is preserved from Pass 1 (original left-to-right cmdline order)
    cmdline_entries = dedup.select {|e| e.keys.first.start_with?('command line')}

    return config_entries + env_entries + cmdline_entries
  end

  def mixin(builtins:, config:, mixins:)
    mixins.each do |mixin|
      source = mixin.keys.first
      filepath = mixin.values.first

      _mixin = {} # Empty initial value

      # Dispatch on source label to select the appropriate load strategy.
      # Inline YAML entries carry source label 'command line (inline)' and hold the raw
      # YAML string in the filepath slot (named for the common case; dual-purposed here).
      if source == 'command line (inline)'
        # Inline YAML: parse the string directly instead of reading a file
        _mixin = @yaml_wrapper.load_string( filepath )
        @loginator.lazy( Verbosity::OBNOXIOUS ) { " + Merging command line inline YAML mixin" }

      # Load mixin from filepath if it is a filepath
      elsif @path_validator.filepath?( filepath )
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

      # Normalize String keys to Symbol keys: YAML flow mappings ({key: value}) produce
      # String keys, but Ceedling config uses Symbol keys throughout. Converting here
      # makes flow-style inline YAML merge correctly without requiring the invalid {: key:} syntax.
      _mixin = deep_symbolize_keys( _mixin )

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

      # Record this mixin in the configuration history.
      # Map source labels to the flag name shown in history output.
      # Inline YAML gets a distinct label so history clearly distinguishes it from files.
      label = case source
              when 'command line'          then '--mixin'
              when 'command line (inline)' then '--mixin (inline YAML)'
              when 'project configuration' then ':mixins'
              else source # environment variable name (e.g. CEEDLING_MIXIN_1)
              end

      config[:history] ||= {}
      config[:history][:config] ||= []
      # Record the mixin in config history with a format matching the source type.
      # Inline YAML has no filepath to display, so use a descriptive placeholder instead.
      if source == 'command line (inline)'
        config[:history][:config] << "(inline YAML, #{label})"
      elsif @path_validator.filepath?( filepath )
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

  private

  # Recursively convert all String keys in a nested Hash/Array structure to Symbol keys.
  # This normalizes YAML flow mappings ({key: value} → String keys) to match Ceedling's
  # Symbol-keyed configuration ({:key => value}), enabling correct deep merging.
  # Safe to call on Hash structures already using Symbol keys — it's a no-op for those.
  def deep_symbolize_keys(obj)
    case obj
    when Hash
      # Rebuild the hash with Symbol keys, recursing into values
      obj.each_with_object({}) do |(k, v), memo|
        memo[k.is_a?( String ) ? k.to_sym : k] = deep_symbolize_keys( v )
      end
    when Array
      # Recurse into arrays in case they contain hashes (e.g. :tools sections)
      obj.map { |el| deep_symbolize_keys( el ) }
    else
      # Scalars (strings, integers, booleans, nil) are returned unchanged
      obj
    end
  end

end
