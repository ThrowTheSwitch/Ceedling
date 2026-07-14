# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'deep_merge'
require 'ceedling/constants'

class Configinator

  constructor :config_walkinator, :projectinator, :mixinator

  def loadinate(builtin_mixins:, builtin_load_paths:[], filepath:nil, mixins:[], env:{}, silent:false)
    # Aliases for clarity
    cmdline_filepath = filepath
    cmdline_mixins = mixins || []

    # Load raw config from command line, environment variable, or default filepath
    project_filepath, config = @projectinator.load( filepath:cmdline_filepath, env:env, silent:silent )

    # Extract cfg_enabled_mixins mixins list plus load paths list from config
    cfg_enabled_mixins, cfg_load_paths = @projectinator.extract_mixins( config: config )

    # Get our YAML file extension
    yaml_ext = @projectinator.lookup_yaml_extension( config:config )

    # Remove any silly redundancies
    cfg_enabled_mixins.uniq!
    # Append project directory then built-in load paths so precedence is:
    #   user :load_paths → project directory → unity/targets
    cfg_load_paths += [File.dirname(project_filepath)] + builtin_load_paths
    # Use absolute path to ensure proper deduplication
    cfg_load_paths.uniq! { |path| File.expand_path(path) }

    # Parse sigils from each raw --mixin value to tag entries as file-based or inline YAML.
    # This tagging happens before any validation or lookup so that each type is routed
    # to the appropriate validator. Positional order is captured here in tagged_cmdline
    # and must be preserved through the pipeline so that left-to-right merge semantics
    # on the command line are honored (later entries win on scalar conflicts).
    #
    # Sigil conventions:
    #   '=' prefix  → inline YAML string (strip the sigil, treat value as YAML content)
    #   '@' prefix  → explicit file/name reference (strip the sigil, existing behavior)
    #   no prefix   → file/name reference, backwards-compatible with existing usage
    tagged_cmdline = cmdline_mixins.map do |m|
      if    m.start_with?(MIXIN_SIGIL_INLINE_YAML) then {type: :yaml, value: m[1..]}
      elsif m.start_with?(MIXIN_SIGIL_FILEPATH)    then {type: :file, value: m[1..]}
      else                          {type: :file, value: m}
      end
    end

    # Pull out the two streams for type-specific processing
    cmdline_file_values = tagged_cmdline.select {|e| e[:type] == :file}.map {|e| e[:value]}
    cmdline_yaml_values = tagged_cmdline.select {|e| e[:type] == :yaml}.map {|e| e[:value]}

    # Deduplicate file values only; inline YAML is deduplicated later
    cmdline_file_values.uniq!

    # Validate :cfg_load_paths from :mixins section of project configuration
    @projectinator.validate_mixin_load_paths( cfg_load_paths )

    # Validate enabled mixins from :mixins section of project configuration
    if not @projectinator.validate_mixins(
      mixins: cfg_enabled_mixins,
      load_paths: cfg_load_paths,
      builtins: builtin_mixins,
      source: 'Config :mixins ↳ :enabled =>',
      yaml_extension: yaml_ext
    )
      raise 'Project configuration file section :mixins failed validation'
    end

    # Validate only file-based cmdline entries; inline YAML is validated separately below
    if not @projectinator.validate_mixins(
      mixins: cmdline_file_values,
      load_paths: cfg_load_paths,
      builtins: builtin_mixins,
      source: 'Mixin',
      yaml_extension: yaml_ext
    )
      raise 'Command line failed validation'
    end

    # Validate inline YAML strings: must parse cleanly and produce a Hash
    @mixinator.validate_cmdline_yaml_strings( cmdline_yaml_values )

    # Find mixins in project file among load paths or built-in mixins
    # Return ordered list of filepaths or built-in mixin names
    config_mixins = @projectinator.lookup_mixins(
      mixins: cfg_enabled_mixins,
      load_paths: cfg_load_paths,
      builtins: builtin_mixins,
      yaml_extension: yaml_ext
    )

    # Pre-build config entries as tagged hashes carrying both the resolved path and
    # the original :enabled name. This preserves the user-provided name for history
    # traceability without losing the resolved path needed by the merge pipeline.
    config_entries = cfg_enabled_mixins.zip(config_mixins).map do |(name, path)|
      {'project configuration' => path, :_input => name}
    end

    # Resolve file-based names/paths to canonical filepaths (or built-in keys).
    # Returns values in the same order as the input; zip them back into a hash for
    # O(1) lookup when reconstructing positional order below.
    resolved_file_values = @projectinator.lookup_mixins(
      mixins: cmdline_file_values,
      load_paths: cfg_load_paths,
      builtins: builtin_mixins,
      yaml_extension: yaml_ext
    )
    file_resolution_map = Hash[cmdline_file_values.zip(resolved_file_values)]

    # Reconstruct the full cmdline sequence in original left-to-right order,
    # replacing stripped file values with their resolved forms and tagging each
    # entry with a source label that mixin() uses to select the load strategy.
    # File entries that were deduplicated (absent from map after first use) are
    # skipped — delete after first fetch enforces single-use per unique value.
    cmdline_ordered = tagged_cmdline.each_with_object([]) do |e, arr|
      if e[:type] == :yaml
        # Inline YAML: source label 'command line (inline)' triggers load_string() in mixin()
        # :_input carries the raw YAML string as the original user value for history traceability
        arr << {'command line (inline)' => e[:value], :_input => e[:value]}
      elsif (resolved = file_resolution_map[e[:value]])
        # File/name: source label 'command line' triggers existing file/builtin dispatch in mixin()
        # :_input carries the original user-provided value (before load-path resolution) for history
        arr << {'command line' => resolved, :_input => e[:value]}
        file_resolution_map.delete(e[:value])  # consume so duplicate raw values are skipped
      end
    end

    # Fetch CEEDLING_MIXIN_# environment variables
    # Sort into ordered list of hash tuples [{env variable => filepath}...]
    env_mixins = @mixinator.fetch_env_filepaths( env )
    @mixinator.validate_env_filepaths( env_mixins )

    # Eliminate duplicate mixins and return list of mixins in merge order
    # [{source => filepath}...]
    # cmdline_ordered is pre-tagged and positionally ordered; assemble_mixins preserves
    # relative order within each tier (config → env → cmdline)
    mixins_assembled = @mixinator.assemble_mixins(
      config: config_entries,
      env: env_mixins,
      cmdline: cmdline_ordered
    )

    # Merge mixins
    @mixinator.mixin( builtins:builtin_mixins, config:config, mixins:mixins_assembled )

    return project_filepath, config
  end

  def default_tasks(config:, default_tasks:)
    #  1. If :default_tasks set in config, use it
    #  2. Otherwise use the function argument (most likely a default set in the first moments of startup)
    value, _ = @config_walkinator.fetch_value( :project, :default_tasks, hash:config )
    if value
      # Update method parameter to config value
      default_tasks = value.dup()
    else
      # Set key/value in config if it's not set
      config.deep_merge( {:project => {:default_tasks => default_tasks}} )
    end

    return default_tasks
  end

end