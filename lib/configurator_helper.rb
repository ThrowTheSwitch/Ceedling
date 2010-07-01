
# add sort-ability to symbol so we can order keys array in hash for test-ability 
class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end


class ConfiguratorHelper
  
  constructor :configurator_builder, :configurator_validator
  
  
  def build_project_config(config)
    # convert config object to flattened hash
    new_config = @configurator_builder.flattenify(config)

    # flesh out config
    @configurator_builder.clean(new_config)
    
    # add to hash values we build up from configuration & file system contents
    new_config.merge!(@configurator_builder.set_build_paths(new_config))
    new_config.merge!(@configurator_builder.set_log_filepath(new_config))
    new_config.merge!(@configurator_builder.set_rakefile_components(new_config))
    new_config.merge!(@configurator_builder.set_release_target(new_config))
    new_config.merge!(@configurator_builder.collect_project_options(new_config))
    
    # iterate through all entries in paths section and expand any & all globs to actual paths
    new_config.merge!(@configurator_builder.expand_all_path_globs(new_config))
    
    new_config.merge!(@configurator_builder.collect_source_and_include_paths(new_config))
    new_config.merge!(@configurator_builder.collect_test_and_source_and_include_paths(new_config))
    new_config.merge!(@configurator_builder.collect_test_and_source_paths(new_config))
    new_config.merge!(@configurator_builder.collect_tests(new_config))
    new_config.merge!(@configurator_builder.collect_assembly(new_config))
    new_config.merge!(@configurator_builder.collect_source(new_config))
    new_config.merge!(@configurator_builder.collect_headers(new_config))
    new_config.merge!(@configurator_builder.collect_all_existing_compilation_input(new_config))
    new_config.merge!(@configurator_builder.collect_test_defines(new_config))    
    new_config.merge!(@configurator_builder.collect_environment_dependencies)

    @configurator_builder.collect_test_fixture_link_objects(new_config)

    return new_config
  end

  
  def build_constants_and_accessors(config, context)
    @configurator_builder.build_global_constants(config)
    @configurator_builder.build_accessor_methods(config, context)
  end
  
  
  def validate_required_sections(config)
    validation = []
    validation << @configurator_validator.exists?(config, :project)
    validation << @configurator_validator.exists?(config, :paths)

    return false if (validation.include?(false))
    return true
  end

  def validate_required_section_values(config)
    validation = []
    validation << @configurator_validator.exists?(config, :project, :build_root)
    validation << @configurator_validator.exists?(config, :paths, :test)
    validation << @configurator_validator.exists?(config, :paths, :source)

    return false if (validation.include?(false))
    return true
  end

  def validate_paths(config)
    validation = []

    validation << @configurator_validator.validate_simple_path(config[:project][:build_root],          :project, :build_root)
    validation << @configurator_validator.validate_simple_path(config[:project][:options_path],        :project, :options_path)
    validation << @configurator_validator.validate_simple_path(config[:plugins][:base_path],           :plugins, :base_path)
    validation << @configurator_validator.validate_simple_path(config[:plugins][:auxiliary_load_path], :plugins, :auxiliary_load_path)

    config[:paths].keys.sort.each do |key|
      validation << @configurator_validator.validate_path_list(config, :paths, key)
    end

    return false if (validation.include?(false))
    return true
  end
  
  def validate_tools(config)
    validation = []

    config[:tools].keys.sort.each do |key|
      validation << @configurator_validator.exists?(config, :tools, key, :executable)
      validation << @configurator_validator.validate_filepath(config, :tools, key, :executable)    
    end

    return false if (validation.include?(false))
    return true
  end

  def validate_plugins(config)
    validation = []

    config[:plugins][:enabled].sort.each do |plugin|
      validation << @configurator_validator.validate_simple_path( File.join(config[:plugins][:base_path], plugin), :plugins, :enabled, plugin.to_sym )
    end
  
    return false if (validation.include?(false))
    return true
  end
  
end
