# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'

# Add Unity and CMock's Ruby code paths to $LOAD_PATH for runner generation and mocking
$LOAD_PATH.unshift( File.join( CEEDLING_APPCFG[:ceedling_vendor_path], 'unity/auto') )
$LOAD_PATH.unshift( File.join( CEEDLING_APPCFG[:ceedling_vendor_path], 'cmock/lib') )

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

  @ceedling[:loginator].log() # Blank line
  @ceedling[:loginator].log( "Ceedling #{run} completed in #{duration}", Verbosity::NORMAL)
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
  $LOAD_PATH.unshift( CEEDLING_APPCFG[:ceedling_lib_path] )
  objects_filepath = File.join( CEEDLING_APPCFG[:ceedling_lib_path], 'objects.yml' )
  
  # Create object hash and dependency injection context
  @ceedling = {} # Empty hash to be redefined if all goes well
  @ceedling = DIY::Context.from_yaml( File.read( objects_filepath ) )

  # Inject objects already insatantiated from bin/ bootloader before building the rest
  CEEDLING_HANDOFF_OBJECTS.each_pair {|name,obj| @ceedling.set_object( name.to_s, obj )}

  # Build Ceedling application's objects
  @ceedling.build_everything()

  # Simplify load path after construction
  $LOAD_PATH.delete( CEEDLING_APPCFG[:ceedling_lib_path] )

  # One-stop shopping for all our setup and such after construction
  @ceedling[:setupinator].ceedling = @ceedling
  @ceedling[:setupinator].do_setup( CEEDLING_APPCFG )

  setup_done = SystemWrapper.time_stopwatch_s()
  log_runtime( 'set up', start_time, setup_done, CEEDLING_APPCFG.build_tasks? )

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
  @ceedling[:plugin_manager].pre_build if CEEDLING_APPCFG.build_tasks?

  # load rakefile component files (*.rake)
  PROJECT_RAKEFILE_COMPONENT_FILES.each { |component| load(component) }
rescue StandardError => ex
  boom_handler( @ceedling[:loginator], ex )
  exit(1)
end

def test_failures_handler()
  # $stdout test reporting plugins store test failures
  exit(1) if @ceedling[:plugin_manager].plugins_failed? && !CEEDLING_APPCFG.tests_graceful_fail?
end

# End block always executed following rake run
END {
  $stdout.flush unless $stdout.nil?
  $stderr.flush unless $stderr.nil?

  # Only perform these final steps if we got here without runtime exceptions or errors
  if @ceedling[:application].build_succeeded?
    # Tell all our plugins the build is done and process results
    begin
      if CEEDLING_APPCFG.build_tasks?
        @ceedling[:plugin_manager].post_build
        @ceedling[:plugin_manager].print_plugin_failures
      end
      ops_done = SystemWrapper.time_stopwatch_s()
      log_runtime( 'operations', start_time, ops_done, CEEDLING_APPCFG.build_tasks? )
      test_failures_handler() if (@ceedling[:task_invoker].test_invoked? || @ceedling[:task_invoker].invoked?(/^gcov:/))
    rescue => ex
      ops_done = SystemWrapper.time_stopwatch_s()
      log_runtime( 'operations', start_time, ops_done, CEEDLING_APPCFG.build_tasks? )
      boom_handler( @ceedling[:loginator], ex )
      @ceedling[:loginator].wrapup
      exit(1)
    end

    @ceedling[:loginator].wrapup
    exit(0)
  else
    msg = "Ceedling could not complete operations because of errors"
    @ceedling[:loginator].log( msg, Verbosity::ERRORS, LogLabels::TITLE )
    begin
      @ceedling[:plugin_manager].post_error if CEEDLING_APPCFG.build_tasks?
    rescue => ex
      boom_handler( @ceedling[:loginator], ex)
    ensure
      @ceedling[:loginator].wrapup
      exit(1)
    end
  end
}
