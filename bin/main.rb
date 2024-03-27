require 'cli'
require 'diy'
require 'constructor'
require 'app_cfg'

CEEDLING_APPCFG = get_app_cfg()

# Entry point
begin
  # Construct all bootloader objects
  #  1. Add full path to $LOAD_PATH to simplify objects.yml
  #  2. Perform object construction + dependency injection from bin/objects.yml
  #  3. Remove paths from $LOAD_PATH
  $LOAD_PATH.unshift( CEEDLING_LIB )
  objects = DIY::Context.from_yaml( File.read( File.join( CEEDLING_BIN, 'objects.yml' ) ) )
  objects.build_everything
  $LOAD_PATH.delete( CEEDLING_BIN ) # Loaded in top-level `ceedling` script
  $LOAD_PATH.delete( CEEDLING_LIB )

  # Keep a copy of the command line (Thor consumes ARGV)
  _ARGV = ARGV.clone

  # Backwards compatibility command line hack to silently presenve Rake `-T` CLI handling
  if (ARGV.size() == 1 and ARGV[0] == '-T')
    # Call rake task listing handler w/ default handling of project file and mixins
    objects[:cli_handler].rake_tasks( app_cfg: CEEDLING_APPCFG )

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

# Thor application CLI did not handle command line arguments
# Pass along ARGV to Rake instead
rescue Thor::UndefinedCommandError
  objects[:cli_handler].rake_exec( app_cfg: CEEDLING_APPCFG, tasks: _ARGV )

# Bootloader boom handling
rescue StandardError => e
  $stderr.puts( "ERROR: #{e.message}" )
  $stderr.puts( e.backtrace ) if ( defined?( PROJECT_DEBUG ) and PROJECT_DEBUG )
  exit(1)
end
