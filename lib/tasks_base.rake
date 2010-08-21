require 'constants'
require 'file_path_utils'


desc "Display build environment version info."
task :version do
  tools = [
      ['  Ceedling', CEEDLING_ROOT],
      ['CException', File.join( CEEDLING_VENDOR, 'c_exception')],
      ['     CMock', File.join( CEEDLING_VENDOR, 'cmock')],
      ['     Unity', File.join( CEEDLING_VENDOR, 'unity')],
    ]
  
  tools.each do |tool|
    version_string = @ceedling[:file_wrapper].read( File.join(tool[1], 'release', 'version.info') ).strip
    build_string   = @ceedling[:file_wrapper].read( File.join(tool[1], 'release', 'build.info') ).strip
    puts "#{tool[0]}:: #{version_string} (#{build_string})"
  end
end


desc "Set verbose output (silent:[#{Verbosity::SILENT}] - obnoxious:[#{Verbosity::OBNOXIOUS}])."
task :verbosity, :level do |t, args|
  verbosity_level = args.level.to_i

  hash = @ceedling[:setupinator].config_hash
  hash[:project][:verbosity] = verbosity_level
  hash[:cmock][:verbosity]   = verbosity_level if (PROJECT_USE_MOCKS)
  
  @ceedling[:configurator].build( hash )

  # control rake's verbosity with new setting
  verbose( ((verbosity_level == Verbosity::OBNOXIOUS) ? true : false) )
end


desc "Enable logging"
task :logging do
  @ceedling[:configurator].project_logging = true
end


namespace :options do

  @ceedling[:configurator].collection_project_options.each do |option_path|
    option = File.basename(option_path, '.yml')

    desc "Merge #{option} project options."
    task option.downcase.to_sym do
      @ceedling[:project_config_manager].project_options_filepath = option_path

      hash = @ceedling[:setupinator].config_hash
      hash.deep_merge( @ceedling[:yaml_wrapper].load(option_path) )
      
      @ceedling[:setupinator].do_setup( @ceedling, hash )
    end
  end

end



