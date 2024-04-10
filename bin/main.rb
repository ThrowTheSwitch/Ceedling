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
  objects.build_everything()
  $LOAD_PATH.delete( CEEDLING_BIN ) # Loaded in top-level `ceedling` script
  $LOAD_PATH.delete( CEEDLING_LIB )

  # Keep a copy of the command line for edge case CLI hacking (Thor consumes ARGV)
  _ARGV = ARGV.clone

  # NOTE: See comment block in cli.rb to understand CLI handling.

  # Backwards compatibility command line hack to silently presenve Rake `-T` CLI handling
  if (ARGV.size() == 1 and ARGV[0] == '-T')
    # Call rake task listing handler w/ default handling of project file and mixins
    objects[:cli_handler].rake_help( env:ENV, app_cfg:CEEDLING_APPCFG )

  # Run command line args through Thor
  elsif (ARGV.size() > 0)
    CeedlingTasks::CLI.start( ARGV,
      {
        :app_cfg => CEEDLING_APPCFG,
        :objects => objects,
      }
    )

  # Handle `ceedling` run with no arguments (run default build tasks)
  else
    objects[:cli_handler].build( env:ENV, app_cfg:CEEDLING_APPCFG, tasks:[] )
  end

# Thor application CLI did not handle command line arguments.
rescue Thor::UndefinedCommandError
  # Marrying Thor Rake command line handling creates a gap (see comments in CLI handling).
  # If a user enters only Rake build tasks at the command line followed by Thor flags,
  # our Thor configuration doesn't see those flags.
  # We catch the exception of unrecognized Thor commands here (i.e. the Rake tasks),
  # and try again by forcing the Thor `build` command at the beginning of the command line.
  # This way, our Thor handling will process the flags and pass the Rake tasks along.
  CeedlingTasks::CLI.start( _ARGV.unshift( 'build' ),
    {
      :app_cfg => CEEDLING_APPCFG,
      :objects => objects,
    }
  )

# Bootloader boom handling
rescue StandardError => e
  $stderr.puts( "\n🌱 ERROR: #{e.message}" )
  $stderr.puts( e.backtrace ) if ( defined?( PROJECT_DEBUG ) and PROJECT_DEBUG )
  exit(1)
end
