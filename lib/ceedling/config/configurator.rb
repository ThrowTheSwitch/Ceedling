# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/defaults'
require 'ceedling/constants'
require 'ceedling/file_path_utils'
require 'ceedling/exceptions'
require 'ceedling/rake_app/rakefile_component_resolver'
require 'ceedling/tool_executor'
require 'deep_merge'

class Configurator

  attr_reader :project_config_hash, :programmatic_plugins, :rake_plugins
  attr_accessor :project_logging, :sanity_checks, :include_test_case, :exclude_test_case, :force_test_rerun

  constructor :configurator_setup, :configurator_builder, :configurator_plugins, :config_walkinator, :yaml_wrapper, :system_wrapper, :loginator, :reportinator, :ruby_expandinator

  # Validations of the sections everything else depends on. Configuration can reference
  # environment variables that are evaluated early, so :environment is among them.
  ESSENTIAL_VALIDATIONS = [:validate_required_sections, :validate_required_section_values, :validate_environment_vars].freeze

  # Validations of the completed configuration
  FINAL_VALIDATIONS = [
    :validate_paths, :validate_tools, :validate_test_runner_generation, :validate_defines, :validate_flags,
    :validate_test_preprocessor, :validate_backtrace, :validate_threads, :validate_partials, :validate_plugins
  ].freeze

  # CMock and Unity options that test runner generation also reads
  RUNNER_CMOCK_OPTIONS = [:mock_prefix, :mock_suffix, :enforce_strict_ordering].freeze
  RUNNER_UNITY_OPTIONS = [:use_param_tests, :shuffle_tests].freeze

  # A minimal subset of the directives-only preprocessor tool: no defines, no include paths,
  # and output to stdout, so no platform-specific null device. It is enough to detect
  # -fdirectives-only support by a warning or exit code.
  DIRECTIVES_ONLY_PROBE_ARGUMENTS = ['-E', '-fdirectives-only', '-x c', "\"${1}\""].freeze

  def setup()
    # Cmock config reference to provide to CMock for mock generation
    @cmock_config = {} # Default empty hash, replaced by reference below

    # Runner config reference to provide to runner generation
    @runner_config = {} # Default empty hash, replaced by reference below

    # Unity config reference -- kept alongside the above two since project_config_hash
    # is flattened (nested sections become individual top-level keys like
    # :unity_use_param_tests) and no longer holds a :unity section of its own to read back.
    @unity_config = {} # Default empty hash, replaced by reference below

    # Partials config reference -- same reason as the Unity config above, and needed
    # as a single value dependency-tracker meta can hash wholesale for Partials targets.
    @partials_config = {} # Default empty hash, replaced by reference below

    # Accessors built from configuration read this
    @project_config_hash = {}

    @programmatic_plugins = []
    @rake_plugins   = []

    @project_logging = false
    @sanity_checks   = TestResultsSanityChecks::NORMAL
  end

  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    return self.class.name
  end

  def replace_flattened_config(config)
    @project_config_hash.merge!(config)
    @configurator_setup.build_constants_and_accessors(@project_config_hash, self)
  end


  # Set up essential flattened config related to verbosity.
  # We do this because early config validation failures may need access to verbosity,
  # but the accessors won't be available until after configuration is validated.
  # PROJECT_VERBOSITY and PROJECT_DEBUG are set by command line processing.
  def set_verbosity()
    debug = !!defined?(PROJECT_DEBUG) && PROJECT_DEBUG
    define_singleton_method( :project_debug ) { debug }

    return if !defined?(PROJECT_VERBOSITY)

    verbosity = PROJECT_VERBOSITY
    define_singleton_method( :project_verbosity ) { verbosity }
  end


  def set_partials_derived_config(config)
    return if !config[:project][:use_partials]

    # If partials enabled, enable mocking
    config[:project][:use_mocks] = true
    @loginator.log( " > Enabled mocking." )

    # If partials enabled, enable full test preprocessing
    config[:project][:use_test_preprocessor] = :all
    @loginator.log( " > Enabled preprocessing." )
  end


  # Directives-only preprocessing is available only when preprocessing is on, fallback
  # is not forced, and the configured C preprocessor supports -fdirectives-only
  def resolve_directives_only_preprocessing(config, tool_executor)
    config[:test_build][:preprocess_directives_only_available] = false

    return if config[:project][:use_test_preprocessor] == :none

    if config[:test_build][:preprocess_force_fallback]
      return log_notice( "Forcing fallback text-based preprocessing in place of directives-only (:test_build ↳ :preprocess_force_fallback is enabled)." )
    end

    if !directives_only_supported?( config, tool_executor )
      return log_notice( "Preprocessor lacks -fdirectives-only support ➡️ Ceedling will use text-based fallback for preprocessing." )
    end

    config[:test_build][:preprocess_directives_only_available] = true
  end


  # The default tools a build needs are merged into the default config hash
  def merge_tools_defaults(config, default_config)
    progress( 'Collecting default tool configurations' )

    needed_tools_defaults( config ).each { |defaults| default_config.deep_merge( defaults.deep_clone() ) }
  end


  def populate_cmock_defaults(config, default_config)
    # Cmock has its own internal defaults handling, but we need to set these specific values
    # so they're guaranteed values and present for the Ceedling environment to access

    progress( 'Collecting CMock defaults' )

    # Begin populating defaults with CMock defaults as set by Ceedling
    default_cmock = default_config[:cmock]

    # Fill in default settings programmatically
    default_cmock[:mock_path] = File.join(config[:project][:build_root], TESTS_BASE_PATH, 'mocks')
    default_cmock[:verbosity] = project_verbosity()
  end


  def prepare_plugins_load_paths(plugins_load_path, config)
    # Plugins must be loaded before generic path evaluation & magic that happen later.
    # So, perform path magic here as discrete step.
    # (String replacement and standardization require DI objects not available in bin/ scope.)
    config[:plugins][:load_paths].each do |path|
      path.replace( @ruby_expandinator.expand( path, source: ":plugins ↳ :load_paths" ) )
      FilePathUtils::standardize_in_place( path )
    end

    # Delegate list construction to the shared helper (user paths first, built-in last).
    # This mirrors what RakefileComponentResolver.resolve() does in the bin/ CLI scope,
    # ensuring both scopes search plugins in the same priority order.
    config[:plugins][:load_paths] = RakefileComponentResolver.prepare_plugin_load_paths( config, plugins_load_path )

    return @configurator_plugins.process_aux_load_paths( config )
  end


  # Plugin YAML defaults merge before plugin Ruby defaults. Neither replaces a value already present.
  def merge_plugins_defaults(paths_hash, config, default_config)
    yaml_defaults = @configurator_plugins.find_plugin_yml_defaults( config, paths_hash ).to_h do |plugin, path|
      [plugin, load_plugin_yaml( path, "Could not load default configuration for plugin '#{plugin}'" )]
    end

    merge_plugin_defaults( 'YAML', yaml_defaults, default_config )
    merge_plugin_defaults( 'Ruby hash', @configurator_plugins.find_plugin_hash_defaults( config, paths_hash ), default_config )
  end


  def merge_ceedling_runtime_config(config, runtime_config)
    # Merge Ceedling's internal runtime configuration settings
    config.deep_merge( runtime_config )
  end


  def populate_with_defaults( config_hash, defaults_hash )
    progress( 'Populating project configuration with collected default values' )

    @configurator_builder.populate_with_defaults( config_hash, defaults_hash )

    # Every :extension value is settled the moment defaults are merged in, well before
    # validation or flattening ever look at it, so nothing downstream ever has to wonder
    # whether a given :extension entry is a bare String or already a FilenameExtension.
    @configurator_builder.normalize_filename_extensions( config_hash )
  end


  # Parameterized tests need Unity's test case and variadic macro support
  def populate_unity_config(config)
    progress( 'Processing Unity configuration' )

    # Save Unity config reference
    @unity_config = config[:unity]

    config[:unity][:defines].concat( ['UNITY_SUPPORT_TEST_CASES', 'UNITY_SUPPORT_VARIADIC_MACROS'] ) if config[:unity][:use_param_tests]

    debug { "Unity configuration >> #{config[:unity]}" }
  end


  def populate_partials_config(config)
    # Save Partials config reference -- no transformation needed, unlike Unity/CMock/the
    # test runner above, since nothing else derives values from or into this section.
    @partials_config = config[:partials]

    debug { "Partials configuration >> #{config[:partials]}" }
  end


  # CMock needs no preparation when mocks are off
  def populate_cmock_config(config)
    # Save CMock config reference
    @cmock_config = config[:cmock]

    if config[:project][:use_mocks]
      progress( 'Processing CMock configuration' )
      prepare_cmock_config( config[:cmock] )
    end

    debug { "CMock configuration >> #{config[:cmock]}" }
  end


  def populate_test_runner_generation_config(config)
    progress( 'Populating test runner generation settings' )

    runner = config[:test_runner]

    # Backtraces rerun test cases by name, which takes runner command line arguments
    force_cmdline_args( runner ) if config[:project][:use_backtrace] != :none

    copy_runner_options( config, runner )

    @runner_config = runner

    debug { "Test Runner configuration >> #{runner}" }
  end


  def populate_exceptions_config(config)
    # Automagically set exception handling if CMock is configured for it
    if config[:cmock][:plugins] && config[:cmock][:plugins].include?(:cexception)
      progress( 'Enabling CException use based on CMock plugins settings' )

      config[:project][:use_exceptions] = true
    end

    debug { "CException configuration >> #{config[:cexception]}" }
  end


  def get_runner_config
    # Clone because test runner generation is not thread-safe;
    # The runner generator is manufactured for each use with configuration changes for each use.
    return @runner_config.clone
  end


  def get_cmock_config
    # Clone because test mock generation is not thread-safe;
    # The mock generator is manufactured for each use with configuration changes for each use.
    return @cmock_config.clone
  end


  def get_unity_config
    # Clone for the same reason as get_runner_config/get_cmock_config above.
    return @unity_config.clone
  end


  def get_partials_config
    # Clone for the same reason as get_runner_config/get_cmock_config above.
    return @partials_config.clone
  end


  # Fills in each tool's missing name, $stderr redirect, and optional flag
  def populate_tools_config(config)
    progress( 'Populating tool definition settings and expanding any string replacements' )

    config[:tools].each { |name, tool| populate_tool( name, tool ) }
  end


  # A tool definition shortcut, :tools_<name>, may redefine the tool's executable and add
  # arguments to it
  #
  # :tools_<name>
  #   :arguments: [...]
  #   :executable: '...'
  def populate_tools_shortcuts(config)
    progress( 'Processing tool definition shortcuts' )

    config[:tools].each do |name, tool|
      executable, arguments = tool_shortcut( config, name )
      next if executable.nil? and arguments.empty?

      tool[:executable] = executable unless executable.nil?
      tool[:arguments].concat( arguments )

      debug { shortcut_message( name, executable, arguments ) }
    end
  end


  def discover_plugins(paths_hash, config)
    progress( 'Discovering all plugins' )

    @rake_plugins         = @configurator_plugins.find_rake_plugins( config, paths_hash )
    @programmatic_plugins = @configurator_plugins.find_programmatic_plugins( config, paths_hash )
    config_plugins        = @configurator_plugins.find_config_plugins( config, paths_hash )

    { 'Rake' => @rake_plugins, 'Programmatic' => @programmatic_plugins, 'Config' => config_plugins }.each do |kind, plugins|
      debug { " > #{kind} plugins: " + plugins.map { |plugin| plugin[:plugin] }.join( ', ' ) } unless plugins.empty?
    end
  end


  def populate_plugins_config(paths_hash, config)
    # Set special plugin setting for results printing if unset
    config[:plugins][:display_raw_test_results] = true if (config[:plugins][:display_raw_test_results].nil?)

    # Add corresponding path to each plugin's configuration
    paths_hash.each_pair { |name, path| config[:plugins][name] = path }
  end


  # A plugin's configuration merges into the project's like a project file
  def merge_config_plugins(config)
    @configurator_plugins.config_plugins.each do |plugin|
      plugin_config = load_plugin_yaml( plugin[:path], "Could not load configuration from plugin '#{plugin[:plugin]}'" )

      progress( "Merging configuration from plugin #{plugin[:plugin]}" )
      debug { plugin_config.to_s }

      resolve_plugin_paths( plugin_config, plugin[:path] )
      config.deep_merge( plugin_config )
    end
  end


  # Each :environment entry is a single-pair hash: a variable name and its value
  def eval_environment_variables(config)
    return if config[:environment].nil?

    progress( 'Processing environment variables' )

    config[:environment].each { |entry| eval_environment_variable( entry ) }
  end


  # Eval config path lists (convert any strings to array of size 1) and handle any Ruby string replacement
  def eval_paths(config)
    # :plugins ↳ :load_paths already handled

    progress( 'Processing path entries and expanding any string replacements' )

    eval_path_entries( config[:project][:build_root], source: ":project ↳ :build_root" )
    eval_path_entries( config[:release_build][:artifacts], source: ":release_build ↳ :artifacts" )

    [:paths, :files].each { |section| eval_path_section( config, section ) }

    # All other paths at secondary hash key level processed by convention (`_path`):
    # ex. :toplevel ↳ :foo_path & :toplevel ↳ :bar_paths are evaluated
    config.each_pair { |key, child| eval_path_entries( collect_path_list( child ), source: ":#{key} ↳ a *_path/*_paths entry" ) }
  end


  # Handle any Ruby string replacement for :flags string arrays
  def eval_flags(config)
    progress( 'Expanding any string replacements in :flags entries' )

    # Descend down to array of command line flags strings regardless of depth in config block
    traverse_hash_eval_string_arrays( config[:flags], source: ":flags" )
  end


  # Handle any Ruby string replacement for :defines string arrays
  def eval_defines(config)
    progress( 'Expanding any string replacements in :defines entries' )

    # Descend down to array of #define strings regardless of depth in config block
    traverse_hash_eval_string_arrays( config[:defines], source: ":defines" )
  end


  def standardize_paths(config)
    progress( 'Standardizing all paths' )

    standalone_paths( config ).flatten.each { |path| FilePathUtils::standardize_in_place( path ) }

    [:paths, :files].each { |section| standardize_path_section( config[section] ) }

    config[:tools].each_value { |tool| FilePathUtils::standardize_in_place( tool[:executable] ) if tool.include?( :executable ) }

    standardize_convention_paths( config )
  end


  # Every validation runs, so every problem is reported, before configuration fails
  def validate_essential(config)
    valid = ESSENTIAL_VALIDATIONS.map { |validation| @configurator_setup.public_send( validation, config ) }

    raise CeedlingException.new( "Ceedling configuration failed validation" ) unless valid.all?
  end


  # Every validation runs, so every problem is reported, before configuration fails.
  # Runner generation also checks the command line's test case filters.
  def validate_final(config, app_cfg)
    filters = [ app_cfg[:include_test_case], app_cfg[:exclude_test_case] ]

    valid = FINAL_VALIDATIONS.map do |validation|
      arguments = (validation == :validate_test_runner_generation) ? [config, *filters] : [config]
      @configurator_setup.public_send( validation, *arguments )
    end

    raise CeedlingException.new( "Ceedling configuration failed validation" ) unless valid.all?
  end


  # Create constants and accessors (attached to this object) from given hash
  def build(ceedling_lib_path, logging_path, config, *keys)
    flattened_config = @configurator_builder.flattenify( config )

    @configurator_setup.build_project_config( ceedling_lib_path, logging_path, flattened_config )
    @configurator_setup.build_directory_structure( flattened_config )

    # Copy Unity, CMock, CException into vendor directory within build directory
    @configurator_setup.vendor_frameworks_and_support_files( ceedling_lib_path, flattened_config )
    @configurator_setup.build_project_collections( flattened_config )

    @project_config_hash = flattened_config.clone
    @configurator_setup.build_constants_and_accessors( flattened_config, self )

    # Top-level keys disappear when we flatten, so create global constants & accessors to any specified keys
    build_section_constants( config, keys )
  end


  def redefine_element(elem, value)
    # Ensure elem is a symbol
    elem = elem.to_sym if elem.class != Symbol

    # Ensure element already exists
    if not @project_config_hash.include?(elem)
      error = "Could not redefine #{elem} in configurator ⏩️ Element does not exist"
      raise CeedlingException.new(error)
    end

    # Update internal hash
    @project_config_hash[elem] = value

    # Update global constant
    @configurator_builder.build_global_constant(elem, value)
  end


  # Add to constants and accessors as post build step
  def build_supplement(config_base, config_more)
    # merge in our post-build additions to base configuration hash
    config_base.deep_merge!( config_more )

    # flatten our addition hash
    config_more_flattened = @configurator_builder.flattenify( config_more )

    # merge our flattened hash with built hash from previous build
    @project_config_hash.deep_merge!( config_more_flattened )

    # create more constants and accessors
    @configurator_setup.build_constants_and_accessors(config_more_flattened, self)

    # recreate constants & update accessors with new merged, base values
    build_section_constants( config_base, config_more.keys )
  end


  def insert_rake_plugins(plugins)
    plugins.each do |hash|
      progress( "Adding plugin #{hash[:plugin]} to Rake load list" )

      @project_config_hash[:project_rakefile_component_files] << hash[:path]
    end
  end

  ### Private ###

  private

  def progress(message)
    @loginator.lazy( Verbosity::OBNOXIOUS ) { @reportinator.generate_progress( message ) }
  end

  def debug(&message)
    @loginator.lazy( Verbosity::DEBUG, &message )
  end

  def log_notice(message)
    @loginator.log( message, Verbosity::COMPLAIN, LogLabels::NOTICE )
  end

  # Probes the configured C preprocessor with the Unity header, which is always available,
  # self-contained, and needs no include paths
  def directives_only_supported?(config, tool_executor)
    probe_tool = {
      executable: config[:tools][:test_file_directives_only_preprocessor][:executable],
      name:       'directives_only_probe',
      arguments:  DIRECTIVES_ONLY_PROBE_ARGUMENTS
    }
    command = tool_executor.build_command_line( probe_tool, [], File.join( CEEDLING_VENDOR, UNITY_LIB_PATH, UNITY_H_FILE ) )

    # A failed probe means no support, so it must not raise
    command[:options][:boom] = false
    results = tool_executor.exec( command )

    # Clang and some older GCC emit a warning (not an error) when -fdirectives-only is unsupported
    return !(results[:output].match?( /warning[^\n]+-fdirectives-only/ ) || tool_executor.failed?( results ))
  end

  # config[:project] is guaranteed to exist / validated to exist but may not include the
  # settings read here. config[:test_build] and config[:release_build] are optional.
  def needed_tools_defaults(config)
    release = setting( config, :project, :release_build )

    return [
      [DEFAULT_TOOLS_TEST,               true],
      [DEFAULT_TOOLS_TEST_PREPROCESSORS, setting( config, :project, :use_test_preprocessor ) != :none],
      [DEFAULT_TOOLS_TEST_ASSEMBLER,     setting( config, :test_build, :use_assembly )],
      [DEFAULT_TOOLS_TEST_GDB_BACKTRACE, setting( config, :project, :use_backtrace ) == :gdb],
      [DEFAULT_TOOLS_RELEASE,            release],
      [DEFAULT_TOOLS_RELEASE_ASSEMBLER,  release && setting( config, :release_build, :use_assembly )]
    ].select { |_, needed| needed }.map( &:first )
  end

  # A setting from the configuration, or Ceedling's default when the configuration lacks it
  def setting(config, *keys)
    value, _ = @config_walkinator.fetch_value( *keys, hash:config, default: DEFAULT_CEEDLING_PROJECT_CONFIG.dig( *keys ) )
    return value
  end

  # Loads a plugin's YAML, naming the plugin in any failure
  def load_plugin_yaml(path, failure)
    return @yaml_wrapper.load( path )
  rescue YamlLoadException => e
    raise YamlLoadException.new(
      reason: e.reason, source: e.source, original_error: e.original_error,
      message: "#{failure} ⏩️ #{e.message}"
    )
  end

  def merge_plugin_defaults(kind, defaults_by_plugin, default_config)
    return if defaults_by_plugin.empty?

    progress( "Collecting Plugin #{kind} defaults" )

    defaults_by_plugin.each do |plugin, defaults|
      debug { " - #{plugin} >> #{defaults}" }
      default_config.deep_merge( defaults )
    end
  end

  def prepare_cmock_config(cmock)
    # Plugins housekeeping
    cmock[:plugins].map! { |plugin| plugin.to_sym() }.uniq!

    include_unity_helpers( cmock )

    # Add mocking prefix symbol for all test compilation
    cmock[:defines] << "CMOCK_MOCK_PREFIX=#{cmock[:mock_prefix]}"
  end

  # A Unity helper path may be a single string. Each helper's header is included in every mock.
  def include_unity_helpers(cmock)
    cmock[:unity_helper_path] = [cmock[:unity_helper_path]] if cmock[:unity_helper_path].is_a?( String )
    cmock[:includes].concat( cmock[:unity_helper_path].map { |path| File.basename( path ) } ).uniq!
  end

  def copy_runner_options(config, runner)
    RUNNER_CMOCK_OPTIONS.each { |option| runner[option] = config[:cmock][option] }
    RUNNER_UNITY_OPTIONS.each { |option| runner[option] = config[:unity][option] }
    runner[:defines] += config[:unity][:defines]
  end

  def force_cmdline_args(runner)
    return unless runner[:cmdline_args] == false

    runner[:cmdline_args] = true
    log_notice( "Enabled :test_runner ↳ :cmdline_args because :project ↳ :use_backtrace is enabled." )
  end

  def populate_tool(name, tool)
    raise CeedlingException.new( "Expected configuration for tool :#{name} is a Hash but found #{tool.class}" ) unless tool.is_a?( Hash )

    # Populate name if not given
    ToolExecutor.default_name!( tool, name.to_s )

    # Populate $stderr redirect option
    tool[:stderr_redirect] = StdErrRedirect::NONE if (tool[:stderr_redirect].nil?)

    # Populate optional option to control verification of executable in search paths
    tool[:optional] = false if (tool[:optional].nil?)
  end

  # The executable and arguments a tool's :tools_<name> shortcut gives, if any
  def tool_shortcut(config, name)
    shortcut = :"tools_#{name}"

    executable, _ = @config_walkinator.fetch_value( shortcut, :executable, hash:config )
    arguments, _  = @config_walkinator.fetch_value( shortcut, :arguments, hash:config, default: [] )

    return executable, arguments
  end

  def shortcut_message(name, executable, arguments)
    message  = " > #{name}\n"
    message += "   executable: \"#{executable}\"\n" unless executable.nil?
    message += "   arguments: " + arguments.map { |arg| "\"#{arg}\"" }.join( ', ' ) + "\n" unless arguments.empty?
    return message
  end

  # A plugin's :paths entries are expanded. $PLUGIN_PATH in one names the plugin's own directory.
  def resolve_plugin_paths(plugin_config, plugin_config_path)
    return unless plugin_config.include?( :paths )

    plugin_path = plugin_config_path.match( /(.*)[\/]config[\/]\w+\.yml/ )[1]
    plugin_config[:paths].transform_values! do |paths|
      paths.map { |path| File.expand_path( path.gsub( /\$PLUGIN_PATH/, plugin_path ) ) }
    end
  end

  # The value, a string or list of strings, is expanded and joined into one string. A
  # :path list joins with the platform path separator, ':' or ';', and any other list with
  # spaces. The variable is set in the environment by its name upcased.
  def eval_environment_variable(entry)
    name, value = entry.first
    items = expand_environment_items( name, value.is_a?( Array ) ? value : [value] )
    entry[name] = items.join( (name == :path) ? File::PATH_SEPARATOR : ' ' )

    @system_wrapper.env_set( name.to_s.upcase, entry[name] )
    debug { " - #{name.to_s.upcase}: \"#{entry[name]}\"" }
  end

  def expand_environment_items(name, items)
    items.each { |item| item.replace( @ruby_expandinator.expand( item, source: ":environment ↳ #{name}" ) ) if item.is_a?( String ) }
  end

  def eval_path_section(config, section)
    config[section].each_pair do |entry, paths|
      # Sub-entries (e.g. :test) could be a single string -> make array
      reform_path_entries_as_lists( config[section], entry, paths )
      eval_path_entries( paths, source: ":#{section} ↳ #{entry}" )
    end
  end

  # :project ↳ :build_root and :release_build ↳ :artifacts are individual paths that don't
  # follow the _path/_paths key convention. :release_build may be absent in minimal configs.
  def standalone_paths(config)
    return [ config[:project][:build_root], config[:release_build][:artifacts] ] if config[:release_build]

    log_notice( ":release_build section absent from config ➡️ skipping :artifacts path standardization." )
    return [ config[:project][:build_root] ]
  end

  # Each entry becomes a list, without the nil or empty entries standardizing leaves of a
  # non-String or whitespace-only value
  def standardize_path_section(section)
    section.transform_values! do |paths|
      [paths].flatten
        .map    { |path| FilePathUtils::standardize_in_place( path ) }
        .reject { |path| path.nil? || (path.is_a?( String ) && path.empty?) }
    end
  end

  # All other paths at secondary hash key level processed by convention (`_path`):
  # ex. :toplevel ↳ :foo_path & :toplevel ↳ :bar_paths are standardized
  def standardize_convention_paths(config)
    config.each_value { |child| collect_path_list( child ).each { |path| FilePathUtils::standardize_in_place( path ) } }
  end

  def build_section_constants(config, keys)
    keys.each { |key| @configurator_setup.build_constants_and_accessors( { key => config[key] }, self ) }
  end

  def reform_path_entries_as_lists( container, entry, value )
    container[entry] = [value]  if value.kind_of?( String )
  end


  def collect_path_list( container )
    return [] unless container.is_a?( Hash )

    return container.select { |key, _| key.to_s =~ /_path(s)?$/ }.values.flatten
  end


  def eval_path_entries( container, source: )
    paths = case container
            when Array  then container.flatten
            when String then [container]
            else             []
            end

    # An unset path setting has nothing to expand
    paths.each do |path|
      path.replace( @ruby_expandinator.expand( path, source: source ) ) if path.is_a?( String )
    end
  end


  # Traverse configuration tree recursively to find terminal leaf nodes that are a list of strings;
  # expand in place any string with the Ruby string replacement pattern.
  def traverse_hash_eval_string_arrays(config, source:)
    case config

    when Array
      # If it's an array of strings, process it
      if config.all? { |item| item.is_a?( String ) }
        # Expand in place each string item in the array
        config.each do |item|
          item.replace( @ruby_expandinator.expand( item, source: source ) )
        end
      end

    when Hash
      # Recurse
      config.each_value { |value| traverse_hash_eval_string_arrays( value, source: source ) }
    end
  end

end
