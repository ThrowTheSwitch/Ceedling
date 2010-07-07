require 'constants'


desc "Display build environment version info."
task :version do
# print ceedling, cmock, unity info
end


desc "Set verbose output (silent:[#{Verbosity::SILENT}] - obnoxious:[#{Verbosity::OBNOXIOUS}])."
task :verbosity, :level do |t, args|
  verbosity_level = args.level.to_i

  hash = @ceedling[:setupinator].config_hash
  hash[:project][:verbosity] = verbosity_level
  @ceedling[:configurator].cmock_config_hash[:verbosity] = verbosity_level
  
  @ceedling[:configurator].build( hash )

  # control rake's verbosity with new setting
  verbose( ((verbosity_level == Verbosity::OBNOXIOUS) ? true : false) )
end

desc "Enable logging"
task :logging do
  hash = @ceedling[:setupinator].config_hash
  hash[:project][:logging] = true

  @ceedling[:configurator].build( hash )
end

namespace :options do

  @ceedling[:configurator].collection_project_options.each do |option_path|
    option = File.basename(option_path, '.yml')

    desc "Merge #{option} project options."
    task option.downcase.to_sym do
      @ceedling[:project_file_loader].project_options_filepath = option_path

      hash = @ceedling[:setupinator].config_hash
      hash.deep_merge( @ceedling[:yaml_wrapper].load(option_path) )
      
      @ceedling[:setupinator].do_setup( @ceedling, hash )
      
      COLLECTION_ENVIRONMENT_DEPENDENCIES << option_path
    end
  end

end
