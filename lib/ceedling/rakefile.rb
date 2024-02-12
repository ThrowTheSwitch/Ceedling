require 'fileutils'

# get directory containing this here file, back up one directory, and expand to full path
CEEDLING_ROOT    = File.expand_path(File.dirname(__FILE__) + '/../..')
CEEDLING_LIB     = File.join(CEEDLING_ROOT, 'lib')
CEEDLING_VENDOR  = File.join(CEEDLING_ROOT, 'vendor')
CEEDLING_RELEASE = File.join(CEEDLING_ROOT, 'release')

$LOAD_PATH.unshift( CEEDLING_LIB )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'unity/auto') )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'diy/lib') )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'cmock/lib') )

require 'rake'

# Let's make sure we remember the task descriptions in case we need them
Rake::TaskManager.record_task_metadata = true

require 'diy'
require 'constructor'
require 'ceedling/constants'
require 'ceedling/target_loader'
require 'ceedling/system_wrapper'
require 'ceedling/reportinator'
require 'deep_merge'

def log_runtime(run, start_time_s, end_time_s)
  return if !defined?(PROJECT_VERBOSITY)
  return if (PROJECT_VERBOSITY < Verbosity::ERRORS)

  duration = Reportinator.generate_duration( start_time_s: start_time_s, end_time_s: end_time_s )

  return if duration.empty?

  puts( "\nCeedling #{run} completed in #{duration}" )
end

def boom_handler(exception:, debug:)
  $stderr.puts("#{exception.class} ==> #{exception.message}")
  if debug
    $stderr.puts("Backtrace ==>")
    $stderr.puts(exception.backtrace)
  end
  abort # Rake's abort
end

# Exists in external scope
start_time = nil

# Top-level exception handling for any otherwise un-handled exceptions, particularly around startup
begin
  # Redefine start_time with actual timestamp before set up begins
  start_time = SystemWrapper.time_stopwatch_s()

  # construct all our objects
  # ensure load path contains all libraries needed first
  lib_ceedling_load_path_temp = File.join(CEEDLING_LIB, 'ceedling')
  $LOAD_PATH.unshift( lib_ceedling_load_path_temp )
  @ceedling = DIY::Context.from_yaml( File.read( File.join(lib_ceedling_load_path_temp, 'objects.yml') ) )
  @ceedling.build_everything
  # now that all objects are built, delete 'lib/ceedling' from load path
  $LOAD_PATH.delete(lib_ceedling_load_path_temp)
  # one-stop shopping for all our setup and such after construction
  @ceedling[:setupinator].ceedling = @ceedling

  project_config =
    begin
      cfg = @ceedling[:setupinator].load_project_files
      TargetLoader.inspect(cfg, ENV['TARGET'])
    rescue TargetLoader::NoTargets
      cfg
    rescue TargetLoader::RequestReload
      @ceedling[:setupinator].load_project_files
    end

  @ceedling[:setupinator].do_setup( project_config )

  log_runtime( 'set up', start_time, SystemWrapper.time_stopwatch_s() )

  # Configure high-level verbosity
  unless defined?(PROJECT_DEBUG) and PROJECT_DEBUG
    # Configure Ruby's default reporting for Thread exceptions.
    # In Ceedling's case thread scenarios will fall into these buckets:
    #  1. Jobs shut down cleanly
    #  2. Jobs shut down at garbage collected after a build step terminates with an error
    #
    # Since Ceedling is not a daemon, server app, or something to run continuously,
    # we can safely disable forced exception reporting.
    Thread.report_on_exception = false

    # Tell Rake to shut up by default unless we're in DEBUG
    verbose(false)
    Rake.application.options.silent = true

    # Remove all Rake backtrace
    Rake.application.options.suppress_backtrace_pattern = /.*/
  end

  # Reset start_time before operations begins
  start_time = SystemWrapper.time_stopwatch_s()

  # tell all our plugins we're about to do something
  @ceedling[:plugin_manager].pre_build

  # load rakefile component files (*.rake)
  PROJECT_RAKEFILE_COMPONENT_FILES.each { |component| load(component) }
rescue StandardError => e
  boom_handler( exception:e, debug:PROJECT_DEBUG )
end

# End block always executed following rake run
END {
  $stdout.flush unless $stdout.nil?
  $stderr.flush unless $stderr.nil?

  # Cache our input configurations to use in comparison upon next execution
  @ceedling[:cacheinator].cache_test_config( @ceedling[:setupinator].config_hash )    if (@ceedling[:task_invoker].test_invoked?)
  @ceedling[:cacheinator].cache_release_config( @ceedling[:setupinator].config_hash ) if (@ceedling[:task_invoker].release_invoked?)

  graceful_fail = @ceedling[:setupinator].config_hash[:graceful_fail]

  # Only perform these final steps if we got here without runtime exceptions or errors
  if (@ceedling[:application].build_succeeded?)
    # Tell all our plugins the build is done and process results
    begin
      @ceedling[:plugin_manager].post_build
      @ceedling[:plugin_manager].print_plugin_failures
      log_runtime( 'operations', start_time, SystemWrapper.time_stopwatch_s() )
      exit(1) if @ceedling[:plugin_manager].plugins_failed? && !graceful_fail
    rescue => ex
      log_runtime( 'operations', start_time, SystemWrapper.time_stopwatch_s() )
      boom_handler( exception:ex, debug:PROJECT_DEBUG )
      exit(1)
    end

    exit(0)
  else
    puts("\nCeedling could not complete operations because of errors.")
    begin
      @ceedling[:plugin_manager].post_error
    rescue => ex
      boom_handler( exception:ex, debug:PROJECT_DEBUG )
    ensure
      exit(1)
    end
  end
}
