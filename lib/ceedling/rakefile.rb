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

#Let's make sure we remember the task descriptions in case we need them
Rake::TaskManager.record_task_metadata = true

require 'diy'
require 'constructor'
require 'ceedling/constants'
require 'ceedling/target_loader'
require 'deep_merge'

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

# Configure Ruby's default reporting for Thread exceptions.
unless @ceedling[:configurator].project_verbosity == Verbosity::DEBUG
  # In Ceedling's case thread scenarios will fall into these buckets:
  #  1. Jobs shut down cleanly
  #  2. Jobs shut down at garbage collected after a build step terminates with an error
  #
  # Since Ceedling is not a daemon, server app, or something to run continuously,
  # we can safely disable forced exception reporting.
  Thread.report_on_exception = false
end

# tell all our plugins we're about to do something
@ceedling[:plugin_manager].pre_build

# load rakefile component files (*.rake)
PROJECT_RAKEFILE_COMPONENT_FILES.each { |component| load(component) }

# tell rake to shut up by default (overridden in verbosity / debug tasks as appropriate)
verbose(false)


# end block always executed following rake run
END {
  $stdout.flush unless $stdout.nil?
  $stderr.flush unless $stderr.nil?

  # cache our input configurations to use in comparison upon next execution
  @ceedling[:cacheinator].cache_test_config( @ceedling[:setupinator].config_hash )    if (@ceedling[:task_invoker].test_invoked?)
  @ceedling[:cacheinator].cache_release_config( @ceedling[:setupinator].config_hash ) if (@ceedling[:task_invoker].release_invoked?)

  # only perform these final steps if we got here without runtime exceptions or errors
  if (@ceedling[:system_wrapper].ruby_success)

    # tell all our plugins the build is done and process results
    @ceedling[:plugin_manager].post_build
    @ceedling[:plugin_manager].print_plugin_failures
    exit(1) if (@ceedling[:plugin_manager].plugins_failed? && !@ceedling[:setupinator].config_hash[:graceful_fail])
  else
    puts "ERROR: Ceedling Failed"
    @ceedling[:plugin_manager].post_error
  end
}
