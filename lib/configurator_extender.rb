require 'verbosinator'

class ConfiguratorExtender

  constructor :stream_wrapper, :file_wrapper

  def setup
    @rake_extenders   = []
    @script_extenders = []
  end


  # gather up and return .rake filepaths that exist on-disk
  def find_rake_extenders(config)
    base_path = config[:extenders][:base_path]
    
    return if base_path.empty?
    
    extenders_with_path = []
    
    config[:extenders][:enabled].each do |extender|
      rake_extender_path = File.join(CEEDLING_ROOT, base_path, extender, "#{extender}.rake")
      if (@file_wrapper.exists?(rake_extender_path))
        extenders_with_path << rake_extender_path
        @rake_extenders << extender
      end
    end
    
    return extenders_with_path
  end


  # gather up and return just names of .rb classes that exist on-disk
  def find_script_extenders(config)
    base_path = config[:extenders][:base_path]
    
    return if base_path.empty?
    
    config[:extenders][:enabled].each do |extender|
      script_extender_path = File.join(base_path, extender, "#{extender}.rb")
      @script_extenders << extender if @file_wrapper.exists?(script_extender_path)
    end
    
    return @script_extenders 
  end
  
  
  # gather up and return .yml filepaths that exist on-disk
  def find_config_extenders(config)
    base_path = config[:extenders][:base_path]
    
    return if base_path.empty?

    extenders_with_path = []
    
    config[:extenders][:enabled].each do |extender|
      config_extender_path = File.join(base_path, extender, "#{extender}.yml")
      extenders_with_path << config_extender_path if @file_wrapper.exists?(config_extender_path)
    end
    
    return extenders_with_path    
  end
  
  
  def validate_extenders(enabled_extenders)
    missing_extenders = Set.new(enabled_extenders) - Set.new(@rake_extenders) - Set.new(@script_extenders)
    
    missing_extenders.each do |extender|
      @stream_wrapper.stdout_puts.stderr_puts("ERROR: Extender '#{extender}' contains no rake or script entry point. (Misspelled or missing files?)")
    end
    
    raise if (missing_extenders.size > 0)
  end

end
