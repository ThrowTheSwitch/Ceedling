# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/defaults'
require 'ceedling/constants'
require 'ceedling/file_path_utils'
require 'ceedling/exceptions'
require 'deep_merge'

class Configurator

  attr_reader :project_config_hash, :programmatic_plugins, :rake_plugins
  attr_accessor :project_logging, :sanity_checks, :include_test_case, :exclude_test_case

  constructor :configurator_setup, :configurator_builder, :configurator_plugins, :config_walkinator, :yaml_wrapper, :system_wrapper, :loginator, :reportinator

  def setup()
    # Cmock config reference to provide to CMock for mock generation
    @cmock_config = {} # Default empty hash, replaced by reference below

    # Runner config reference to provide to runner generation
    @runner_config = {} # Default empty hash, replaced by reference below

    # Note: project_config_hash is an instance variable so constants and accessors created
    # in eval() statements in build() have something of proper scope and persistence to reference
    @project_config_hash = {}

    @programmatic_plugins = []
    @rake_plugins   = []

    @project_logging = false
    @sanity_checks   = TestResultsSanityChecks::NORMAL
  end

  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    # TODO: When identifying information is added to constructor, insert it into `inspect()` string
    return this.class.name
  end

  def replace_flattened_config(config)
    @project_config_hash.merge!(config)
    @configurator_setup.build_constants_and_accessors(@project_config_hash, binding())
  end


  def reset_defaults(config)
    [:test_compiler,
     :test_linker,
     :test_fixture,
     :test_includes_preprocessor,
     :test_file_preprocessor,
     :test_dependencies_generator,
     :release_compiler,
     :release_assembler,
     :release_linker,
     :release_dependencies_generator
    ].each do |tool|
      config[:tools].delete(tool) if (not (config[:tools][tool].nil?))
    end
  end


  # Set up essential flattened config related to verbosity.
  # We do this because early config validation failures may need access to verbosity,
  # but the accessors won't be available until after configuration is validated.
  def set_verbosity(config)
    # PROJECT_VERBOSITY and PROJECT_DEBUG set at command line processing before Ceedling is loaded

    # Configurator will later try to create these accessors automatically but will silently 
    # fail if they already exist.

    if (!!defined?(PROJECT_DEBUG) and PROJECT_DEBUG) or (config[:project][:debug])
      eval("def project_debug() return true end", binding())
    else
      eval("def project_debug() return false end", binding())      
    end

    if !!defined?(PROJECT_VERBOSITY)
      eval("def project_verbosity() return #{PROJECT_VERBOSITY} end", binding())
    end
  end


  # The default tools (eg. DEFAULT_TOOLS_TEST) are merged into default config hash
  def merge_tools_defaults(config, default_config)
    msg = @reportinator.generate_progress( 'Collecting default tool configurations' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # config[:project] is guaranteed to exist / validated to exist but may not include elements referenced below
    # config[:test_build] and config[:release_build] are optional in a user project configuration


    release_build, _      = @config_walkinator.fetch_value( :project, :release_build, 
                              hash:config,
                              default: DEFAULT_CEEDLING_PROJECT_CONFIG[:project][:release_build]
                            )

    test_preprocessing, _ = @config_walkinator.fetch_value( :project, :use_test_preprocessor,
                              hash:config,
                              default: DEFAULT_CEEDLING_PROJECT_CONFIG[:project][:use_test_preprocessor]
                            )

    backtrace, _          = @config_walkinator.fetch_value( :project, :use_backtrace,
                              hash:config,
                              default: DEFAULT_CEEDLING_PROJECT_CONFIG[:project][:use_backtrace]
                            )

    release_assembly, _   = @config_walkinator.fetch_value( :release_build, :use_assembly,
                              hash:config,
                              default: DEFAULT_CEEDLING_PROJECT_CONFIG[:release_build][:use_assembly]
                            )

    test_assembly, _      = @config_walkinator.fetch_value( :test_build, :use_assembly,
                              hash:config,
                              default: DEFAULT_CEEDLING_PROJECT_CONFIG[:test_build][:use_assembly]
                            )

    default_config.deep_merge( DEFAULT_TOOLS_TEST.deep_clone() )

    default_config.deep_merge( DEFAULT_TOOLS_TEST_PREPROCESSORS.deep_clone() ) if (test_preprocessing != :none)
    default_config.deep_merge( DEFAULT_TOOLS_TEST_ASSEMBLER.deep_clone() )     if test_assembly
    default_config.deep_merge( DEFAULT_TOOLS_TEST_GDB_BACKTRACE.deep_clone() ) if (backtrace == :gdb)

    default_config.deep_merge( DEFAULT_TOOLS_RELEASE.deep_clone() )            if release_build
    default_config.deep_merge( DEFAULT_TOOLS_RELEASE_ASSEMBLER.deep_clone() )  if (release_build and release_assembly)
  end


  def populate_cmock_defaults(config, default_config)
    # Cmock has its own internal defaults handling, but we need to set these specific values
    # so they're guaranteed values and present for the Ceedling environment to access

    msg = @reportinator.generate_progress( 'Collecting CMock defaults' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Begin populating defaults with CMock defaults as set by Ceedling
    default_cmock = default_config[:cmock]

    # Fill in default settings programmatically
    default_cmock[:mock_path] = File.join(config[:project][:build_root], TESTS_BASE_PATH, 'mocks')
    default_cmock[:verbosity] = project_verbosity()
  end


  def prepare_plugins_load_paths(plugins_load_path, config)
    # Plugins must be loaded before generic path evaluation & magic that happen later.
    # So, perform path magic here as discrete step.
    config[:plugins][:load_paths].each do |path|
      path.replace( @system_wrapper.module_eval( path ) ) if (path =~ RUBY_STRING_REPLACEMENT_PATTERN)
      FilePathUtils::standardize( path )
    end

    # Add Ceedling's plugins path as load path so built-in plugins can be found
    config[:plugins][:load_paths] << plugins_load_path
    config[:plugins][:load_paths].uniq!

    return @configurator_plugins.process_aux_load_paths( config )
  end


  def merge_plugins_defaults(paths_hash, config, default_config)
    # Config YAML defaults plugins
    plugin_yml_defaults = @configurator_plugins.find_plugin_yml_defaults( config, paths_hash )
    
    # Config Ruby-based hash defaults plugins
    plugin_hash_defaults = @configurator_plugins.find_plugin_hash_defaults( config, paths_hash )


    if !plugin_hash_defaults.empty?
      msg = @reportinator.generate_progress( 'Collecting Plugin YAML defaults' )
      @loginator.log( msg, Verbosity::OBNOXIOUS )
    end

    # Load base configuration values (defaults) from YAML
    plugin_yml_defaults.each do |plugin, defaults|
      _defaults = @yaml_wrapper.load( defaults )

      msg = " - #{plugin} >> " + _defaults.to_s()
      @loginator.log( msg, Verbosity::DEBUG )

      default_config.deep_merge( _defaults )
    end

    if !plugin_hash_defaults.empty?
      msg = @reportinator.generate_progress( 'Collecting Plugin Ruby hash defaults' )
      @loginator.log( msg, Verbosity::OBNOXIOUS )
    end

    # Load base configuration values (defaults) as hash from Ruby
    plugin_hash_defaults.each do |plugin, defaults|
      msg = " - #{plugin} >> " + defaults.to_s()
      @loginator.log( msg, Verbosity::DEBUG )

      default_config.deep_merge( defaults )
    end
  end


  def merge_ceedling_runtime_config(config, runtime_config)
    # Merge Ceedling's internal runtime configuration settings
    config.deep_merge( runtime_config )
  end


  def populate_unity_config(config)
    msg = @reportinator.generate_progress( 'Processing Unity configuration' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    if config[:unity][:use_param_tests]
      config[:unity][:defines] << 'UNITY_SUPPORT_TEST_CASES'
      config[:unity][:defines] << 'UNITY_SUPPORT_VARIADIC_MACROS'
    end
  end


  def populate_cmock_config(config)
    # Populate config with CMock config
    cmock = config[:cmock] || {}
    @cmock_config = cmock

    return if !config[:project][:use_mocks]

    msg = @reportinator.generate_progress( 'Processing CMock configuration' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Plugins housekeeping
    cmock[:plugins].map! { |plugin| plugin.to_sym() }
    cmock[:plugins].uniq!

    # CMock includes safe defaults
    cmock[:includes] = [] if (cmock[:includes].nil?)

    # Default to empty array if cmock[:unity_helper_path] not provided
    cmock[:unity_helper_path] = [] if cmock[:unity_helper_path].nil?
    # Reformulate CMock helper path value as array of one element if it's a string in config
    cmock[:unity_helper_path] = [cmock[:unity_helper_path]] if cmock[:unity_helper_path].is_a?( String )

    # CMock Unity helper handling
    cmock[:unity_helper_path].each do |path|
      cmock[:includes] << File.basename( path )
    end

    cmock[:includes].uniq!
  end


  def populate_with_defaults( config_hash, defaults_hash )
    msg = @reportinator.generate_progress( 'Populating project configuration with collected default values' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )    

    @configurator_builder.populate_with_defaults( config_hash, defaults_hash )
  end


  def populate_test_runner_generation_config(config)
    msg = @reportinator.generate_progress( 'Populating test runner generation settings' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )    

    use_backtrace = config[:project][:use_backtrace]

    # Force command line argument option for any backtrace option
    if use_backtrace != :none
      config[:test_runner][:cmdline_args] = true
    end

    # Copy CMock options used by test runner generation
    config[:test_runner][:mock_prefix] = config[:cmock][:mock_prefix]
    config[:test_runner][:mock_suffix] = config[:cmock][:mock_suffix]
    config[:test_runner][:enforce_strict_ordering] = config[:cmock][:enforce_strict_ordering]

    # Merge Unity options used by test runner generation
    config[:test_runner][:defines] += config[:unity][:defines]
    config[:test_runner][:use_param_tests] = config[:unity][:use_param_tests]

    @runner_config = config[:test_runner]
  end


  def populate_exceptions_config(config)
    # Automagically set exception handling if CMock is configured for it
    if config[:cmock][:plugins] && config[:cmock][:plugins].include?(:cexception)
      msg = @reportinator.generate_progress( 'Enabling CException use based on CMock plugins settings' )
      @loginator.log( msg, Verbosity::OBNOXIOUS )    

      config[:project][:use_exceptions] = true
    end
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


  # Process our tools
  #  - :tools entries
  #    - Insert missing names for
  #    - Handle needed defaults
  #  - Configure test runner from backtrace configuration
  def populate_tools_config(config)
    msg = @reportinator.generate_progress( 'Populating tool definition settings and expanding any string replacements' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    config[:tools].each_key do |name|
      tool = config[:tools][name]

      if not tool.is_a?(Hash)
        raise CeedlingException.new( "Expected configuration for tool :#{name} is a Hash but found #{tool.class}" )
      end

      # Populate name if not given
      tool[:name] = name.to_s if (tool[:name].nil?)

      # Populate $stderr redirect option
      tool[:stderr_redirect] = StdErrRedirect::NONE if (tool[:stderr_redirect].nil?)

      # Populate optional option to control verification of executable in search paths
      tool[:optional] = false if (tool[:optional].nil?)
    end
  end


  # Process any tool definition shortcuts
  #  - Append extra arguments
  #  - Redefine executable  
  #
  # :tools_<name>
  #   :arguments: [...]
  #   :executable: '...'
  def populate_tools_shortcuts(config)
    msg = @reportinator.generate_progress( 'Processing tool definition shortcuts' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    prefix = 'tools_'
    config[:tools].each do |name, tool|
      # Lookup shortcut tool definition (:tools_<name>)
      shortcut = (prefix + name.to_s).to_sym

      # Logging message to be built up
      msg = ''

      # Try to lookup the executable from user config
      executable, _  = @config_walkinator.fetch_value(shortcut, :executable, 
                         hash:config
                       )

      # Try to lookup arguments from user config
      args_to_add, _ = @config_walkinator.fetch_value(shortcut, :arguments, 
                         hash:config,
                         default: []
                       )

      # If either tool definition modification is happening, start building the logging message
      if !args_to_add.empty? or !executable.nil?
        msg += " > #{name}\n" 
      end

      # Log the executable and redefine the tool config
      if !executable.nil?
        msg += "   executable: \"#{executable}\"\n"
        tool[:executable] = executable
      end

      # Log the arguments and add to the tool config
      if !args_to_add.empty?
        msg += "   arguments: " + args_to_add.map{|arg| "\"#{arg}\""}.join( ', ' ) + "\n"
        tool[:arguments].concat( args_to_add )
      end

      # Log
      @loginator.log( msg, Verbosity::DEBUG ) if !msg.empty?
    end
  end


  def discover_plugins(paths_hash, config)
    msg = @reportinator.generate_progress( 'Discovering all plugins' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Rake-based plugins
    @rake_plugins = @configurator_plugins.find_rake_plugins( config, paths_hash )
    if !@configurator_plugins.rake_plugins.empty?
      msg = " > Rake plugins: " + @configurator_plugins.rake_plugins.map{|p| p[:plugin]}.join( ', ' )
      @loginator.log( msg, Verbosity::DEBUG )
    end

    # Ruby `Plugin` subclass programmatic plugins
    @programmatic_plugins = @configurator_plugins.find_programmatic_plugins( config, paths_hash )
    if !@configurator_plugins.programmatic_plugins.empty?
      msg = " > Programmatic plugins: " + @configurator_plugins.programmatic_plugins.map{|p| p[:plugin]}.join( ', ' )
      @loginator.log( msg, Verbosity::DEBUG )
    end
    
    # Config plugins
    config_plugins = @configurator_plugins.find_config_plugins( config, paths_hash )
    if !@configurator_plugins.config_plugins.empty?
      msg = " > Config plugins: " + @configurator_plugins.config_plugins.map{|p| p[:plugin]}.join( ', ' )
      @loginator.log( msg, Verbosity::DEBUG )
    end
  end


  def populate_plugins_config(paths_hash, config)
    # Set special plugin setting for results printing if unset
    config[:plugins][:display_raw_test_results] = true if (config[:plugins][:display_raw_test_results].nil?)

    # Add corresponding path to each plugin's configuration
    paths_hash.each_pair { |name, path| config[:plugins][name] = path }
  end


  def merge_config_plugins(config)
    return if @configurator_plugins.config_plugins.empty?

    # Merge plugin configuration values (like Ceedling project file)
    @configurator_plugins.config_plugins.each do |hash|
      _config = @yaml_wrapper.load( hash[:path] )

      msg = @reportinator.generate_progress( "Merging configuration from plugin #{hash[:plugin]}" )
      @loginator.log( msg, Verbosity::OBNOXIOUS )
      @loginator.log( _config.to_s, Verbosity::DEBUG )

      # Special handling for plugin paths
      if (_config.include?( :paths ))
        _config[:paths].update( _config[:paths] ) do |k,v| 
          plugin_path = hash[:path].match( /(.*)[\/]config[\/]\w+\.yml/ )[1]
          v.map {|vv| File.expand_path( vv.gsub!( /\$PLUGIN_PATH/, plugin_path) ) }
        end
      end

      config.deep_merge( _config )
    end
  end


  # Process environment variables set in configuration file
  # (Each entry within the :environment array is a hash)
  def eval_environment_variables(config)
    return if config[:environment].nil?

    msg = @reportinator.generate_progress( 'Processing environment variables' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    config[:environment].each do |hash|
      key   = hash.keys[0] # Get first (should be only) environment variable entry
      value = hash[key]    # Get associated value
      items = []

      # Special case handling for :path environment variable entry
      # File::PATH_SEPARATOR => ':' (Unix-ish) or ';' (Windows)
      interstitial = ((key == :path) ? File::PATH_SEPARATOR : ' ')

      # Create an array container for the value of this entry
      #  - If the value is an array, get it
      #  - Otherwise, place value in a single item array
      items = ((value.class == Array) ? hash[key] : [value])

      # Process value array
      items.each do |item|
        # Process each item for Ruby string replacement
        if item.is_a? String and item =~ RUBY_STRING_REPLACEMENT_PATTERN
          item.replace( @system_wrapper.module_eval( item ) )
        end
      end

      # Join any value items (become a flattened string)
      #  - With path separator if the key was :path
      #  - With space otherwise
      hash[key] = items.join( interstitial )

      # Set the environment variable for our session
      @system_wrapper.env_set( key.to_s.upcase, hash[key] )
      @loginator.log( " - #{key.to_s.upcase}: \"#{hash[key]}\"", Verbosity::DEBUG )
    end
  end


  # Eval config path lists (convert any strings to array of size 1) and handle any Ruby string replacement
  def eval_paths(config)
    # :plugins ↳ :load_paths already handled

    msg = @reportinator.generate_progress( 'Processing path entries and expanding any string replacements' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    eval_path_entries( config[:project][:build_root] )
    eval_path_entries( config[:release_build][:artifacts] )

    config[:paths].each_pair do |entry, paths|
      # :paths sub-entries (e.g. :test) could be a single string -> make array
      reform_path_entries_as_lists( config[:paths], entry, paths )
      eval_path_entries( paths )
    end

    config[:files].each_pair do |entry, files|
      # :files sub-entries (e.g. :test) could be a single string -> make array
      reform_path_entries_as_lists( config[:files], entry, files )
      eval_path_entries( files )
    end

    # All other paths at secondary hash key level processed by convention (`_path`):
    # ex. :toplevel ↳ :foo_path & :toplevel ↳ :bar_paths are evaluated
    config.each_pair { |_, child| eval_path_entries( collect_path_list( child ) ) }
  end


  # Handle any Ruby string replacement for :flags string arrays
  def eval_flags(config)
    msg = @reportinator.generate_progress( 'Expanding any string replacements in :flags entries' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Descend down to array of command line flags strings regardless of depth in config block
    traverse_hash_eval_string_arrays( config[:flags] )
  end


  # Handle any Ruby string replacement for :defines string arrays
  def eval_defines(config)
    msg = @reportinator.generate_progress( 'Expanding any string replacements in :defines entries' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Descend down to array of #define strings regardless of depth in config block
    traverse_hash_eval_string_arrays( config[:defines] )
  end


  def standardize_paths(config)
    msg = @reportinator.generate_progress( 'Standardizing all paths' )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Individual paths that don't follow `_path` convention processed here
    paths = [
      config[:project][:build_root],
      config[:release_build][:artifacts]
    ]

    paths.flatten.each { |path| FilePathUtils::standardize( path ) }

    config[:paths].each_pair do |collection, paths|
      # Ensure that list is an array (i.e. handle case of list being a single string,
      # or a multidimensional array)
      config[:paths][collection] = [paths].flatten.map{|path| FilePathUtils::standardize( path )}
    end

    config[:files].each_pair { |_, files| files.each{ |path| FilePathUtils::standardize( path ) } }

    config[:tools].each_pair { |_, config| FilePathUtils::standardize( config[:executable] ) if (config.include? :executable) }

    # All other paths at secondary hash key level processed by convention (`_path`):
    # ex. :toplevel ↳ :foo_path & :toplevel ↳ :bar_paths are standardized
    config.each_pair do |_, child|
      collect_path_list( child ).each { |path| FilePathUtils::standardize( path ) }
    end
  end


  def validate_essential(config)
    # Collect all infractions, everybody on probation until final adjudication
    blotter = true

    blotter &= @configurator_setup.validate_required_sections( config )
    blotter &= @configurator_setup.validate_required_section_values( config )

    # Configuration sections can reference environment variables that are evaluated early on.
    # So, we validate :environment early as an essential section.
    blotter &= @configurator_setup.validate_environment_vars( config )

    if !blotter
      raise CeedlingException.new("Ceedling configuration failed validation")
    end
  end


  def validate_final(config, app_cfg)
    # Collect all infractions, everybody on probation until final adjudication
    blotter = true
    blotter &= @configurator_setup.validate_paths( config )
    blotter &= @configurator_setup.validate_tools( config )
    blotter &= @configurator_setup.validate_test_runner_generation(
                 config,
                 app_cfg[:include_test_case],
                 app_cfg[:exclude_test_case]
               )
    blotter &= @configurator_setup.validate_defines( config )
    blotter &= @configurator_setup.validate_flags( config )
    blotter &= @configurator_setup.validate_test_preprocessor( config )
    blotter &= @configurator_setup.validate_backtrace( config )
    blotter &= @configurator_setup.validate_threads( config )
    blotter &= @configurator_setup.validate_plugins( config )

    if !blotter
      raise CeedlingException.new( "Ceedling configuration failed validation" )
    end
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

    @configurator_setup.build_constants_and_accessors( flattened_config, binding() )

    # Top-level keys disappear when we flatten, so create global constants & accessors to any specified keys
    keys.each do |key|
      hash = { key => config[key] }
      @configurator_setup.build_constants_and_accessors( hash, binding() )
    end
  end


  def redefine_element(elem, value)
    # Ensure elem is a symbol
    elem = elem.to_sym if elem.class != Symbol

    # Ensure element already exists
    if not @project_config_hash.include?(elem)
      error = "Could not rederine #{elem} in configurator--element does not exist"
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
    @configurator_setup.build_constants_and_accessors(config_more_flattened, binding())

    # recreate constants & update accessors with new merged, base values
    config_more.keys.each do |key|
      hash = { key => config_base[key] }
      @configurator_setup.build_constants_and_accessors(hash, binding())
    end
  end


  def insert_rake_plugins(plugins)
    plugins.each do |hash|
      msg = @reportinator.generate_progress( "Adding plugin #{hash[:plugin]} to Rake load list" )
      @loginator.log( msg, Verbosity::OBNOXIOUS )

      @project_config_hash[:project_rakefile_component_files] << hash[:path]
    end
  end

  ### Private ###

  private

  def reform_path_entries_as_lists( container, entry, value )
    container[entry] = [value]  if value.kind_of?( String )
  end


  def collect_path_list( container )
    paths = []

    if (container.class == Hash)
      container.each_key do |key|
        paths << container[key] if (key.to_s =~ /_path(s)?$/)
      end
    end
    
    return paths.flatten()
  end


  def eval_path_entries( container )
    paths = []

    case(container)
    when Array then paths = Array.new( container ).flatten()
    when String then paths << container
    else
      return
    end

    paths.each do |path|
      path.replace( @system_wrapper.module_eval( path ) ) if (path =~ RUBY_STRING_REPLACEMENT_PATTERN)
    end
  end


  # Traverse configuration tree recursively to find terminal leaf nodes that are a list of strings;
  # expand in place any string with the Ruby string replacement pattern.
  def traverse_hash_eval_string_arrays(config)
    case config

    when Array
      # If it's an array of strings, process it
      if config.all? { |item| item.is_a?( String ) }
        # Expand in place each string item in the array
        config.each do |item|
          item.replace( @system_wrapper.module_eval( item ) ) if (item =~ RUBY_STRING_REPLACEMENT_PATTERN)
        end
      end

    when Hash
      # Recurse
      config.each_value { |value| traverse_hash_eval_string_arrays( value ) }
    end
  end

end

