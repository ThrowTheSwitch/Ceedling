
# add sort-ability to symbol so we can order keys array in hash for test-ability 
class Symbol
  include Comparable

  def <=>(other)
    self.to_s <=> other.to_s
  end
end


class ConfiguratorHelper
  
  constructor :configurator_validator, :system_wrapper
  
  def set_environment_variables(config)
    environment_hash = config[:environment]
    
    return if (environment_hash.nil?)
    
    environment_hash.keys.sort.each do |key|
      @system_wrapper.env_set(key.to_s.upcase, (environment_hash[key]).to_s)
    end
  end
  
  def validate_required_sections(config)
    validation = []
    validation << @configurator_validator.exists?(config, :project)
    validation << @configurator_validator.exists?(config, :paths)
    validation << @configurator_validator.exists?(config, :tools)

    return false if (validation.include?(false))
    return true
  end

  def validate_required_section_values(config)
    validation = []
    validation << @configurator_validator.exists?(config, :project, :build_root)
    validation << @configurator_validator.exists?(config, :paths, :test)
    validation << @configurator_validator.exists?(config, :paths, :source)
    validation << @configurator_validator.exists?(config, :tools, :test_compiler)
    validation << @configurator_validator.exists?(config, :tools, :test_linker)
    validation << @configurator_validator.exists?(config, :tools, :test_fixture)

    return false if (validation.include?(false))
    return true
  end

  def validate_paths(config)
    validation = []

    validation << @configurator_validator.validate_paths(config, :project, :build_root) 

    config[:paths].keys.sort.each do |key|
      validation << @configurator_validator.validate_paths(config, :paths, key)
    end

    plugin_base_path = config[:plugins][:base_path]
    validation << @configurator_validator.validate_path( plugin_base_path, :plugins, :base_path )
    config[:plugins][:enabled].sort.each do |plugin|
      validation << @configurator_validator.validate_path( File.join(plugin_base_path, plugin), :plugins, :enabled, plugin.to_sym )
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
  
end
