require 'fileutils'

$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'unity/auto') )
$LOAD_PATH.unshift( File.join(CEEDLING_VENDOR, 'cmock/lib') )

require 'rake'

# Let's make sure we remember the task descriptions in case we need them
Rake::TaskManager.record_task_metadata = true

require 'ceedling/system_wrapper'
require 'ceedling/reportinator'

# Operation duration logging
def log_runtime(run, start_time_s, end_time_s, enabled)
  return if !enabled
  return if !defined?(PROJECT_VERBOSITY)
  return if (PROJECT_VERBOSITY < Verbosity::NORMAL)

  duration = Reportinator.generate_duration( start_time_s: start_time_s, end_time_s: end_time_s )

  return if duration.empty?

  @ceedling[:streaminator].stream_puts( "\nCeedling #{run} completed in #{duration}" )
end

# Centralized last resort, outer exception handling
def boom_handler(exception:, debug:)
  if !@ceedling.nil? && !@ceedling[:streaminator].nil?
    @ceedling[:streaminator].stream_puts("#{exception.class} ==> #{exception.message}", Verbosity::ERRORS)
    if debug
      @ceedling[:streaminator].stream_puts("Backtrace ==>", Verbosity::ERRORS)
      @ceedling[:streaminator].stream_puts(exception.backtrace, Verbosity::ERRORS)
    end
  else
    # something went really wrong... streaming isn't even up and running yet
    $stderr.puts("#{exception.class} ==> #{exception.message}")
    $stderr.puts("Backtrace ==>")
    $stderr.puts(exception.backtrace)
  end
  exit(1)
end

start_time = nil # Outside scope of exception handling

# Top-level exception handling for any otherwise un-handled exceptions, particularly around startup
begin
  # Redefine start_time with actual timestamp before set up begins
  start_time = SystemWrapper.time_stopwatch_s()

  # Construct all objects
  #  1. Add full path to $LOAD_PATH to simplify objects.yml
  #  2. Perform object construction + dependency injection
  #  3. Remove full path from $LOAD_PATH
  $LOAD_PATH.unshift( CEEDLING_LIB )
  @ceedling = DIY::Context.from_yaml( File.read( File.join( CEEDLING_LIB, 'objects.yml' ) ) )
  @ceedling.build_everything()
  $LOAD_PATH.delete( CEEDLING_LIB )

  # One-stop shopping for all our setup and such after construction
  @ceedling[:setupinator].ceedling = @ceedling
  @ceedling[:setupinator].do_setup( CEEDLING_APPCFG )

  setup_done = SystemWrapper.time_stopwatch_s()
  log_runtime( 'set up', start_time, setup_done, CEEDLING_APPCFG[:stopwatch] )

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

  # Tell all our plugins we're about to do something
  @ceedling[:plugin_manager].pre_build

  # load rakefile component files (*.rake)
  PROJECT_RAKEFILE_COMPONENT_FILES.each { |component| load(component) }
rescue StandardError => e
  boom_handler( exception:e, debug:(defined?(PROJECT_DEBUG) && PROJECT_DEBUG) )
end

def test_failures_handler()
  graceful_fail = CEEDLING_APPCFG[:tests_graceful_fail]

  # $stdout test reporting plugins store test failures
  exit(1) if @ceedling[:plugin_manager].plugins_failed? && !graceful_fail
end

# End block always executed following rake run
END {
  $stdout.flush unless $stdout.nil?
  $stderr.flush unless $stderr.nil?

  # Cache our input configurations to use in comparison upon next execution
  @ceedling[:cacheinator].cache_test_config( @ceedling[:setupinator].config_hash )    if (@ceedling[:task_invoker].test_invoked?)
  @ceedling[:cacheinator].cache_release_config( @ceedling[:setupinator].config_hash ) if (@ceedling[:task_invoker].release_invoked?)

  # Only perform these final steps if we got here without runtime exceptions or errors
  if (@ceedling[:application].build_succeeded?)
    # Tell all our plugins the build is done and process results
    begin
      @ceedling[:plugin_manager].post_build
      @ceedling[:plugin_manager].print_plugin_failures
      ops_done = SystemWrapper.time_stopwatch_s()
      log_runtime( 'operations', start_time, ops_done, CEEDLING_APPCFG[:stopwatch] )
      test_failures_handler() if (@ceedling[:task_invoker].test_invoked? || @ceedling[:task_invoker].invoked?(/^gcov:/))
    rescue => ex
      ops_done = SystemWrapper.time_stopwatch_s()
      log_runtime( 'operations', start_time, ops_done, CEEDLING_APPCFG[:stopwatch] )
      boom_handler( exception:ex, debug:(defined?(PROJECT_DEBUG) && PROJECT_DEBUG) )
      exit(1)
    end

    exit(0)
  else
    @ceedling[:streaminator].stream_puts("\nERROR: Ceedling could not complete operations because of errors.", Verbosity::ERRORS)
    begin
      @ceedling[:plugin_manager].post_error
    rescue => ex
      boom_handler( exception:ex, debug:(defined?(PROJECT_DEBUG) && PROJECT_DEBUG) )
    ensure
      exit(1)
    end
  end
}
