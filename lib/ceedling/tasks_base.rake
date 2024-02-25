require 'ceedling/constants'
require 'ceedling/file_path_utils'
require 'ceedling/version'

# Set Rake verbosity using global constant verbosity set before Rake is loaded
if !!defined?(PROJECT_VERBOSITY)
  verbose(PROJECT_VERBOSITY >= Verbosity::OBNOXIOUS)
  if PROJECT_VERBOSITY >= Verbosity::OBNOXIOUS
    Rake.application.options.silent = false
    Rake.application.options.suppress_backtrace_pattern = nil
  end
end

desc "Display build environment version info."
task :version do
  puts "   Ceedling:: #{Ceedling::Version::CEEDLING}"
  puts "      Unity:: #{Ceedling::Version::UNITY}"
  puts "      CMock:: #{Ceedling::Version::CMOCK}"
  puts " CException:: #{Ceedling::Version::CEXCEPTION}"
end

desc "Set verbose output numerically (silent:[#{Verbosity::SILENT}] - debug:[#{Verbosity::DEBUG}])."
task :verbosity, :level do |t, args|
  # Most of setting verbosity has been moved to command line processing before Rake.
  level = args.level.to_i

  if level >= Verbosity::OBNOXIOUS
    Rake.application.options.silent = false
    Rake.application.options.suppress_backtrace_pattern = nil
  end

  if level < Verbosity::SILENT or level > Verbosity::DEBUG
    puts("WARNING: Verbosity level #{level} is outside of the recognized range [#{Verbosity::SILENT}-#{Verbosity::DEBUG}]")
  end
end

namespace :verbosity do 
  desc "Set verbose output by named level."
  task :* do
    message = "\nOops! 'verbosity:*' isn't a real task. " +
              "Replace '*' with a named level (see verbosity:list).\n\n"

    @ceedling[:streaminator].stdout_puts( message, Verbosity::ERRORS )
  end

  # Most of setting verbosity has been moved to command line processing before Rake.
  VERBOSITY_OPTIONS.each_pair do |key, val| 
    task key do
      if val >= Verbosity::OBNOXIOUS
        Rake.application.options.silent = false
        Rake.application.options.suppress_backtrace_pattern = nil
      end
    end
  end

  # Offer a handy list of verbosity levels
  desc "Available verbosity levels by name"
  task :list do 
    VERBOSITY_OPTIONS.keys.each do |key|
      puts " - verbosity:#{key}"
    end
  end
end

desc "Enable logging"
task :logging do
  @ceedling[:configurator].project_logging = true
  @ceedling[:loginator].project_logging = true
end

# Non-advertised debug task
task :debug do
  Rake.application.options.trace = true
end

# non advertised sanity checking task
task :sanity_checks, :level do |t, args|
  check_level = args.level.to_i
  @ceedling[:configurator].sanity_checks = check_level
end

# non advertised catch for calling upgrade in the wrong place
task :upgrade do
  puts "WARNING: You're currently IN your project directory. Take a step out and try"
  puts "again if you'd like to perform an upgrade."
end

# list expanded environment variables
if (not ENVIRONMENT.empty?)
desc "List all configured environment variables."
task :environment do
  env_list = []
  ENVIRONMENT.each do |env|
    env.each_key do |key|
      name = key.to_s.upcase
	  env_list.push(" - #{name}: \"#{env[key]}\"")
    end
  end
  env_list.sort.each do |env_line|
	puts env_line
  end
end
end

namespace :options do

  COLLECTION_PROJECT_OPTIONS.each do |option_path|
    option = File.basename(option_path, '.yml')

    desc "Merge #{option} project options."
    task option.to_sym do
      hash = @ceedling[:project_config_manager].merge_options( @ceedling[:setupinator].config_hash, option_path )
      @ceedling[:setupinator].do_setup( hash )
      if @ceedling[:configurator].project_release_build
        load(File.join(CEEDLING_LIB, 'ceedling', 'rules_release.rake'))
      end
    end
  end

  # This is to give nice errors when typing options
  rule /^options:.*/ do |t, args|
    filename = t.to_s.split(':')[-1] + '.yml'
    filelist = COLLECTION_PROJECT_OPTIONS.map{|s| File.basename(s) }
    @ceedling[:file_finder].find_file_from_list(filename, filelist, :error)
  end

  # This will output the fully-merged tools options to their own project.yml file
  desc "Export tools options to a new project file"
  task :export, :filename do |t, args|
    outfile = args.filename || 'tools.yml'
    toolcfg = {}
    @ceedling[:configurator].project_config_hash.each_pair do |k,v|
      toolcfg[k] = v if (k.to_s[0..5] == 'tools_')
    end
    File.open(outfile,'w') {|f| f << toolcfg.to_yaml({:indentation => 2})}
  end
end


# do not present task if there's no plugins
if (not PLUGINS_ENABLED.empty?)
desc "Execute plugin result summaries (no build triggering)."
task :summary do
	@ceedling[:plugin_manager].summary
  puts "\nNOTE: Summaries may be out of date with project sources.\n\n"
end
end

