require 'file_path_utils'
require 'deep_merge'

class Configurator
  
  attr_reader :project_config_hash, :cmock_config_hash, :script_extenders, :rake_extenders
  
  constructor :configurator_helper, :configurator_builder, :configurator_extender, :yaml_wrapper
  
  def setup
    # special copy of cmock config to provide to cmock for construction
    @cmock_config_hash = {}
    
    # note: project_config_hash is an instance variable so constants and accessors created
    # in eval() statements in build() have something of proper scope and persistence to reference
    @project_config_hash = {}
    
    @script_extenders = []
  end
  
  
  def set_verbosity(level)
    @project_config_hash[:project_verbosity] = level
    @cmock_config_hash[:verbosity] = level
  end
  
  
  def standardize_paths(config)
    FilePathUtils::standardize(config[:project][:build_root])
    
    config[:paths].each_pair do |key, list|
      list.each{|path| FilePathUtils::standardize(path)}
    end

    config[:tools].each_pair do |key, tool_config|
      FilePathUtils::standardize(tool_config[:executable])
    end
  end
  
  
  def populate_extenders_defaults(config)
    if (config[:extenders].nil?)
      config[:extenders] = {
        :base_path => '.',
        :enabled => []
        }
      return
    end
    
    if (config[:extenders][:base_path].nil?)
      config[:extenders][:base_path] = '.'
    end

    if (config[:extenders][:enabled].nil?)
      config[:extenders][:enabled] = []
    end
  end


  def validate(config)
    # collect felonies and go straight to jail
    raise if (not @configurator_helper.validate_required_sections(config))
    
    # collect all misdemeanors, everybody on probation
    blotter = []
    blotter << @configurator_helper.validate_required_section_values(config)
    blotter << @configurator_helper.validate_paths(config)
    blotter << @configurator_helper.validate_tools(config)
    
    raise if (blotter.include?(false))
  end
  
  
  def build_cmock_defaults(config)
    # cmock has its own internal defaults handling, but we need to set these specific values
    # so they're present for the build environment to access;
    # note: these need to end up in the hash given to initialize cmock for this to be successful
    cmock = {}    
    cmock = config[:cmock] if not config[:cmock].nil?
    
    cmock[:mock_prefix] = 'Mock'                                                 if (cmock[:mock_prefix].nil?)
    cmock[:enforce_strict_ordering] = true                                       if (cmock[:enforce_strict_ordering].nil?)
    cmock[:mock_path] = File.join(config[:project][:build_root], 'tests/mocks')  if (cmock[:mock_path].nil?)
    cmock[:verbosity] = config[:project][:verbosity]                             if (not config[:project][:verbosity].nil? and cmock[:verbosity].nil?)
    
    config[:cmock] = cmock if config[:cmock].nil?
    
    @cmock_config_hash = config[:cmock].clone
  end
  
  
  def find_and_merge_extenders(config)    
    @rake_extenders   = @configurator_extender.find_rake_extenders(config)
    @script_extenders = @configurator_extender.find_script_extenders(config)
    config_extenders  = @configurator_extender.find_config_extenders(config)
    
    config_extenders.each do |extender|
      config.deep_merge( @yaml_wrapper.load(extender) )
    end
  end
  
  
  def build(config)
    # grab tool names from yaml and insert into tool structures so available for error messages
    @configurator_builder.insert_tool_names(config)
    
    # convert config object to flattened hash
    @project_config_hash = @configurator_builder.hashify(config)

    # flesh out config
    @project_config_hash.merge!(@configurator_builder.populate_defaults(@project_config_hash))
    @configurator_builder.clean(@project_config_hash)
    
    # add to hash values we build up from configuration & file system contents
    @project_config_hash.merge!(@configurator_builder.set_build_paths(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.set_rakefile_components(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.collect_test_and_source_include_paths(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.collect_test_and_source_paths(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.collect_tests(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.collect_source(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.collect_headers(@project_config_hash))
    @project_config_hash.merge!(@configurator_builder.collect_test_defines(@project_config_hash))    
    @project_config_hash.merge!(@configurator_builder.collect_environment_dependencies)

    # iterate through all entries in paths section and expand any & all globs to actual paths
    @project_config_hash.merge!(@configurator_builder.expand_all_path_globs(@project_config_hash))

    @project_config_hash.each_pair do |key, value|
      # create global constants
      Object.module_eval("#{key.to_s.upcase} = value")
      # fill configurator object with accessor methods
      eval("def #{key.to_s.downcase}() return @project_config_hash[:#{key.to_s}] end")
    end    
  end
  
  
  def insert_rake_extenders(extenders)
    extenders.each do |extender|
      @project_config_hash[:project_rakefile_component_files] << extender
    end
  end
  
end
