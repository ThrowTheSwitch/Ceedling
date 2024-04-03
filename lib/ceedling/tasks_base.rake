require 'ceedling/constants'
require 'ceedling/file_path_utils'

# Set Rake verbosity using global constant verbosity set before Rake is loaded
if !!defined?(PROJECT_VERBOSITY)
  verbose(PROJECT_VERBOSITY >= Verbosity::OBNOXIOUS)
  if PROJECT_VERBOSITY >= Verbosity::OBNOXIOUS
    Rake.application.options.silent = false
    Rake.application.options.suppress_backtrace_pattern = nil
  end
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

# Do not present task if there's no plugins
if (not PLUGINS_ENABLED.empty?)
desc "Execute plugin result summaries (no build triggering)."
task :summary do
	@ceedling[:plugin_manager].summary
  puts "\nNOTE: Summaries may be out of date with project sources.\n\n"
end
end

