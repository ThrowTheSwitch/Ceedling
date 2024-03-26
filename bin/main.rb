require 'cli'
require 'diy'
require 'constructor'

# Create our global application configuration option set
# This approach bridges clean Ruby and Rake
CEEDLING_APPCFG = {
  # Blank initial value for completeness
  :project_config => {},

  # Blank initial value for completeness
  :log_filepath => '',

  # Only specified in project configuration (no command line or environment variable)
  :default_tasks => ['test:all'],

  # Basic check from working directory
  :which_ceedling => (Dir.exist?( 'vendor/ceedling' ) ? 'vendor/ceedling' : 'gem')
}

# Entry point
begin
  # Construct all bootloader objects
  #  1. Add full path to $LOAD_PATH to simplify objects.yml
  #  2. Perform object construction + dependency injection from bin/objects.yml
  #  3. Remove full paths from $LOAD_PATH
  $LOAD_PATH.unshift( CEEDLING_LIB )
  objects = DIY::Context.from_yaml( File.read( File.join( CEEDLING_BIN, 'objects.yml' ) ) )
  objects.build_everything
  $LOAD_PATH.delete( CEEDLING_BIN ) # Loaded in top-level `ceedling` script
  $LOAD_PATH.delete( CEEDLING_LIB )

  # Backwards compatibility command line hack to silently presenve `-T` Rake arg handling
  if (ARGV.size() >= 1 and ARGV[0] == '-T')

    # TODO: Call through to handler for loading Rakefile tasks after config load

  # Otherwise, run command line args through Thor
  elsif (ARGV.size() > 0)
    CeedlingTasks::CLI.source_root( CEEDLING_ROOT )
    CeedlingTasks::CLI.start( ARGV,
      {
        :app_cfg => CEEDLING_APPCFG,
        :objects => objects,
      }
    )
  end

rescue StandardError => e
  $stderr.puts( "ERROR: #{e.message}" )
  $stderr.puts( e.backtrace ) if ( defined?( PROJECT_DEBUG ) and PROJECT_DEBUG )
  exit(1)
end
