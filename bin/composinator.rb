# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class Composinator

  constructor :config_walkinator, :projectinator, :mixin_resolvinator, :mixinator

  def loadinate(builtin_load_paths:[], filepath:nil, mixins:[], env:{}, silent:false)
    # Aliases for clarity
    cmdline_filepath = filepath
    cmdline_mixins = mixins || []

    # Load raw config from command line, environment variable, or default filepath
    project_filepath, config = @projectinator.load( filepath:cmdline_filepath, env:env, silent:silent )

    # Extract cfg_enabled_mixins mixins list plus load paths list from config
    cfg_enabled_mixins, cfg_load_paths = @mixin_resolvinator.extract_mixins( config: config )

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
    @mixin_resolvinator.validate_mixin_load_paths( cfg_load_paths )

    # Validate enabled mixins from :mixins section of project configuration
    if not @mixin_resolvinator.validate_mixins(
      mixins: cfg_enabled_mixins,
      load_paths: cfg_load_paths,
      source: 'Config :mixins ↳ :enabled =>',
      yaml_extension: yaml_ext
    )
      raise 'Project configuration file section :mixins failed validation'
    end

    # Validate only file-based cmdline entries; inline YAML is validated separately below
    if not @mixin_resolvinator.validate_mixins(
      mixins: cmdline_file_values,
      load_paths: cfg_load_paths,
      source: 'Mixin',
      yaml_extension: yaml_ext
    )
      raise 'Command line failed validation'
    end

    # Validate inline YAML strings: must parse cleanly and produce a Hash
    @mixinator.validate_cmdline_yaml_strings( cmdline_yaml_values )

    # Find mixins in project file among load paths
    # Return ordered list of filepaths
    config_mixins = @mixin_resolvinator.lookup_mixins(
      mixins: cfg_enabled_mixins,
      load_paths: cfg_load_paths,
      yaml_extension: yaml_ext
    )

    # Pre-build config entries as tagged hashes carrying both the resolved path and
    # the original :enabled name. This preserves the user-provided name for history
    # traceability without losing the resolved path needed by the merge pipeline.
    config_entries = cfg_enabled_mixins.zip(config_mixins).map do |(name, path)|
      {'project configuration' => path, :_input => name}
    end

    # Resolve file-based names/paths to canonical filepaths.
    # Returns values in the same order as the input; zip them back into a hash for
    # O(1) lookup when reconstructing positional order below.
    resolved_file_values = @mixin_resolvinator.lookup_mixins(
      mixins: cmdline_file_values,
      load_paths: cfg_load_paths,
      yaml_extension: yaml_ext
    )
    file_resolution_map = Hash[cmdline_file_values.zip(resolved_file_values)]

    # A repeated raw --mixin value (e.g. `--mixin foo.yml --mixin bar.yml
    # --mixin foo.yml`) must resolve using its LAST occurrence's position, not
    # its first, so the user's actual last-typed flag ends up last (highest
    # priority) -- matching ordinary left-to-right command line override
    # semantics. Record the index of each file value's last occurrence so the
    # reconstruction below can keep only that one.
    last_file_index = {}
    tagged_cmdline.each_with_index do |e, idx|
      last_file_index[e[:value]] = idx if e[:type] == :file
    end

    # Reconstruct the full cmdline sequence in original left-to-right order,
    # replacing stripped file values with their resolved forms and tagging each
    # entry with a source label that mixin() uses to select the load strategy.
    # An earlier occurrence of a file value superseded by a later, identical
    # one is skipped entirely -- only the last occurrence's position survives.
    cmdline_ordered = tagged_cmdline.each_with_index.each_with_object([]) do |(e, idx), arr|
      if e[:type] == :yaml
        # Inline YAML: source label 'command line (inline)' triggers load_string() in mixin()
        # :_input carries the raw YAML string as the original user value for history traceability
        arr << {'command line (inline)' => e[:value], :_input => e[:value]}
      elsif idx == last_file_index[e[:value]]
        # File/name: source label 'command line' triggers existing file/builtin dispatch in mixin()
        # :_input carries the original user-provided value (before load-path resolution) for history
        arr << {'command line' => file_resolution_map[e[:value]], :_input => e[:value]}
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
    @mixinator.mixin( config:config, mixins:mixins_assembled )

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
      # Set key/value in config if it's not set, without disturbing any other
      # existing :project keys
      config[:project] ||= {}
      config[:project][:default_tasks] = default_tasks
    end

    return default_tasks
  end

end