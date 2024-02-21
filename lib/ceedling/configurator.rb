require 'ceedling/defaults'
require 'ceedling/constants'
require 'ceedling/file_path_utils'
require 'ceedling/exceptions'
require 'deep_merge'



class Configurator

  attr_reader :project_config_hash, :programmatic_plugins, :rake_plugins
  attr_accessor :project_logging, :project_debug, :project_verbosity, :sanity_checks

  constructor(:configurator_setup, :configurator_builder, :configurator_plugins, :yaml_wrapper, :system_wrapper) do
    @project_logging   = false
    @project_debug     = false
    @project_verbosity = Verbosity::NORMAL
    @sanity_checks     = TestResultsSanityChecks::NORMAL
  end

  def setup
    # Cmock config reference to provide to CMock for mock generation
    @cmock_config = {} # Default empty hash, replaced by reference below

    # Runner config reference to provide to runner generation
    @runner_config = {} # Default empty hash, replaced by reference below

    # note: project_config_hash is an instance variable so constants and accessors created
    # in eval() statements in build() have something of proper scope and persistence to reference
    @project_config_hash = {}
    @project_config_hash_backup = {}

    @programmatic_plugins = []
    @rake_plugins   = []
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


  def store_config
    @project_config_hash_backup = @project_config_hash.clone
  end


  def restore_config
    @project_config_hash = @project_config_hash_backup
    @configurator_setup.build_constants_and_accessors(@project_config_hash, binding())
  end


  def reset_defaults(config)
    [:test_compiler,
     :test_linker,
     :test_fixture,
     :test_includes_preprocessor,
     :test_file_preprocessor,
     :test_file_preprocessor_directives,
     :test_dependencies_generator,
     :release_compiler,
     :release_assembler,
     :release_linker,
     :release_dependencies_generator].each do |tool|
      config[:tools].delete(tool) if (not (config[:tools][tool].nil?))
    end
  end


  # Set up essential flattened config related to verbosity.
  # We do this because early config validation failures may need access to verbosity,
  # but the accessors won't be available until after configuration is validated.
  def set_verbosity(config)
    # PROJECT_VERBOSITY and PROJECT_DEBUG were set at command line processing 
    # before Ceedling is even loaded.

    if (!!defined?(PROJECT_DEBUG) and PROJECT_DEBUG) or (config[:project][:debug])
      eval("def project_debug() return true end", binding())
    else
      eval("def project_debug() return false end", binding())      
    end

    if !!defined?(PROJECT_VERBOSITY)
      eval("def project_verbosity() return #{PROJECT_VERBOSITY} end", binding())
    end

    # Configurator will try to create these accessors automatically but will silently 
    # fail if they already exist.
  end


  # The default values defined in defaults.rb (eg. DEFAULT_TOOLS_TEST) are populated
  # into @param config
  def populate_defaults(config)
    new_config = DEFAULT_CEEDLING_CONFIG.deep_clone
    new_config.deep_merge!(config)
    config.replace(new_config)

    @configurator_builder.populate_defaults( config, DEFAULT_TOOLS_TEST )
    @configurator_builder.populate_defaults( config, DEFAULT_TOOLS_TEST_PREPROCESSORS ) if (config[:project][:use_test_preprocessor])
    @configurator_builder.populate_defaults( config, DEFAULT_TOOLS_TEST_ASSEMBLER )     if (config[:test_build][:use_assembly])

    @configurator_builder.populate_defaults( config, DEFAULT_TOOLS_RELEASE )              if (config[:project][:release_build])
    @configurator_builder.populate_defaults( config, DEFAULT_TOOLS_RELEASE_ASSEMBLER )    if (config[:project][:release_build] and config[:release_build][:use_assembly])
  end


  def populate_unity_defaults(config)
      unity = config[:unity] || {}
      @runner_config = unity.merge(config[:test_runner] || {})
  end

  def populate_cmock_defaults(config)
    # cmock has its own internal defaults handling, but we need to set these specific values
    # so they're present for the build environment to access;
    # note: these need to end up in the hash given to initialize cmock for this to be successful
    cmock = config[:cmock] || {}

    # yes, we're duplicating the default mock_prefix in cmock, but it's because we need CMOCK_MOCK_PREFIX always available in Ceedling's environment
    cmock[:mock_prefix] = 'Mock' if (cmock[:mock_prefix].nil?)

    # just because strict ordering is the way to go
    cmock[:enforce_strict_ordering] = true                                                  if (cmock[:enforce_strict_ordering].nil?)

    cmock[:mock_path] = File.join(config[:project][:build_root], TESTS_BASE_PATH, 'mocks')  if (cmock[:mock_path].nil?)

    cmock[:verbosity] = @project_verbosity                                                  if (cmock[:verbosity].nil?)

    cmock[:plugins] = []                             if (cmock[:plugins].nil?)
    cmock[:plugins].map! { |plugin| plugin.to_sym }
    cmock[:plugins].uniq!

    cmock[:unity_helper] = false                     if (cmock[:unity_helper].nil?)

    if (cmock[:unity_helper])
      cmock[:unity_helper] = [cmock[:unity_helper]] if cmock[:unity_helper].is_a? String
      cmock[:includes] += cmock[:unity_helper].map{|helper| File.basename(helper) }
      cmock[:includes].uniq!
    end

    @runner_config = cmock.merge(@runner_config || config[:test_runner] || {})

    @cmock_config = cmock
  end


  def get_runner_config
    return @runner_config.clone
  end


  def get_cmock_config
    return @cmock_config.clone
  end


  # Grab tool names from yaml and insert into tool structures so available for error messages.
  # Set up default values.
  def tools_setup(config)
    config[:tools].each_key do |name|
      tool = config[:tools][name]

      if not tool.is_a?(Hash)
        raise CeedlingException.new("ERROR: Expected configuration for tool :#{name} is a Hash but found #{tool.class}")
      end

      # Populate name if not given
      tool[:name] = name.to_s if (tool[:name].nil?)

      # handle inline ruby string substitution in executable
      if (tool[:executable] =~ RUBY_STRING_REPLACEMENT_PATTERN)
        tool[:executable].replace(@system_wrapper.module_eval(tool[:executable]))
      end

      # populate stderr redirect option
      tool[:stderr_redirect] = StdErrRedirect::NONE if (tool[:stderr_redirect].nil?)

      # populate optional option to control verification of executable in search paths
      tool[:optional] = false if (tool[:optional].nil?)
    end
  end


  def tools_supplement_arguments(config)
    tools_name_prefix = 'tools_'
    config[:tools].each_key do |name|
      tool = @project_config_hash[(tools_name_prefix + name.to_s).to_sym]

      # Smoosh in extra arguments specified at top-level of config
      # (useful for plugins & default gcc tools if argument order does not matter).
      # Arguments are squirted in at *end* of list.
      top_level_tool = (tools_name_prefix + name.to_s).to_sym
      if (not config[top_level_tool].nil?)
         # Adding and flattening is not a good idea -- might over-flatten if 
         # there's array nesting in tool args.
         tool[:arguments].concat config[top_level_tool][:arguments]
      end
    end
  end


  def find_and_merge_plugins(config)
    # Plugins must be loaded before generic path evaluation & magic that happen later.
    # So, perform path magic here as discrete step.
    config[:plugins][:load_paths].each do |path|
      path.replace( @system_wrapper.module_eval(path) ) if (path =~ RUBY_STRING_REPLACEMENT_PATTERN)
      FilePathUtils::standardize(path)
    end

    # Add Ceedling's plugins path as load path so built-in plugins can be found
    config[:plugins][:load_paths] << FilePathUtils::standardize( Ceedling.plugins_load_path )
    config[:plugins][:load_paths].uniq!

    paths_hash = @configurator_plugins.process_aux_load_paths(config)

    # Rake-based plugins
    @rake_plugins = @configurator_plugins.find_rake_plugins( config, paths_hash )

    # Ruby `PLugin` subclass programmatic plugins
    @programmatic_plugins = @configurator_plugins.find_programmatic_plugins( config, paths_hash )
    
    # Config YAML defaults plugins
    plugin_yml_defaults = @configurator_plugins.find_plugin_yml_defaults( config, paths_hash )
    
    # Config Ruby-based hash defaults plugins
    plugin_hash_defaults = @configurator_plugins.find_plugin_hash_defaults( config, paths_hash )

    # Config plugins
    config_plugins  = @configurator_plugins.find_config_plugins( config, paths_hash )

    # Load base configuration values (defaults) from YAML
    plugin_yml_defaults.each do |defaults|
      @configurator_builder.populate_defaults( config, @yaml_wrapper.load(defaults) )
    end

    # Load base configuration values (defaults) as hash from Ruby
    plugin_hash_defaults.each do |defaults|
      @configurator_builder.populate_defaults( config, defaults )
    end

    # Merge plugin configuration values (like Ceedling project file)
    config_plugins.each do |plugin|
      plugin_config = @yaml_wrapper.load( plugin )

      # Special handling for plugin paths
      if (plugin_config.include?( :paths ))
        plugin_config[:paths].update(plugin_config[:paths]) do |k,v| 
          plugin_path = plugin.match(/(.*)[\/]config[\/]\w+\.yml/)[1]
          v.map {|vv| File.expand_path(vv.gsub!(/\$PLUGIN_PATH/,plugin_path)) }
        end
      end

      config.deep_merge(plugin_config)
    end

    # Set special plugin setting for results printing if unset
    config[:plugins][:display_raw_test_results] = true if (config[:plugins][:display_raw_test_results].nil?)

    # Add corresponding path to each plugin's configuration
    paths_hash.each_pair { |name, path| config[:plugins][name] = path }
  end


  def merge_imports(config)
    if config[:import]
      if config[:import].is_a? Array
        until config[:import].empty?
          path = config[:import].shift
          path = @system_wrapper.module_eval(path) if (path =~ RUBY_STRING_REPLACEMENT_PATTERN)
          config.deep_merge!(@yaml_wrapper.load(path))
        end
      else
        config[:import].each_value do |path|
          if !path.nil?
            path = @system_wrapper.module_eval(path) if (path =~ RUBY_STRING_REPLACEMENT_PATTERN)
            config.deep_merge!(@yaml_wrapper.load(path))
          end
        end
      end
    end
    config.delete(:import)
  end


  def eval_environment_variables(config)
    config[:environment].each do |hash|
      key   = hash.keys[0]
      value = hash[key]
      items = []

      interstitial = ((key == :path) ? File::PATH_SEPARATOR : '')
      items = ((value.class == Array) ? hash[key] : [value])

      items.each do |item|
        if item.is_a? String and item =~ RUBY_STRING_REPLACEMENT_PATTERN
          item.replace( @system_wrapper.module_eval( item ) )
        end
      end

      hash[key] = items.join( interstitial )

      @system_wrapper.env_set( key.to_s.upcase, hash[key] )
    end
  end


  # Eval config path lists (convert strings to array of size 1) and handle any Ruby string replacement
  def eval_paths(config)
    # :plugins ↳ :load_paths already handled

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


  def standardize_paths(config)
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


  def validate(config)
    # Collect felonies and go straight to jail
    if (not @configurator_setup.validate_required_sections( config ))
      raise CeedlingException.new("ERROR: Ceedling configuration failed validation")
    end

    # Collect all misdemeanors, everybody on probation
    blotter = true
    blotter &= @configurator_setup.validate_required_section_values( config )
    blotter &= @configurator_setup.validate_paths( config )
    blotter &= @configurator_setup.validate_tools( config )
    blotter &= @configurator_setup.validate_threads( config )
    blotter &= @configurator_setup.validate_plugins( config )

    if !blotter
      raise CeedlingException.new("ERROR: Ceedling configuration failed validation")
    end
  end


  # Create constants and accessors (attached to this object) from given hash
  def build(config, *keys)
    flattened_config = @configurator_builder.flattenify( config )

    @configurator_setup.build_project_config( flattened_config )

    @configurator_setup.build_directory_structure( flattened_config )

    # Copy Unity, CMock, CException into vendor directory within build directory
    @configurator_setup.vendor_frameworks( flattened_config )

    @configurator_setup.build_project_collections( flattened_config )

    @project_config_hash = flattened_config.clone
    store_config()

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

    # Update backup config
    store_config
  end


  # Add to constants and accessors as post build step
  def build_supplement(config_base, config_more)
    # merge in our post-build additions to base configuration hash
    config_base.deep_merge!( config_more )

    # flatten our addition hash
    config_more_flattened = @configurator_builder.flattenify( config_more )

    # merge our flattened hash with built hash from previous build
    @project_config_hash.deep_merge!( config_more_flattened )
    store_config()

    # create more constants and accessors
    @configurator_setup.build_constants_and_accessors(config_more_flattened, binding())

    # recreate constants & update accessors with new merged, base values
    config_more.keys.each do |key|
      hash = { key => config_base[key] }
      @configurator_setup.build_constants_and_accessors(hash, binding())
    end
  end


  def insert_rake_plugins(plugins)
    plugins.each do |plugin|
      @project_config_hash[:project_rakefile_component_files] << plugin
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

end

