# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'thor'
require 'ceedling/constants' # From Ceedling application

##
## Command Line Handling
## =====================
##
## OVERVIEW
## --------
## Ceedling's command line handling marries Thor and Rake. Thor does not call
## Rake. Rather, a handful of command line conventions, edge case handling,
## and Thor features are stitched together to ensure a given command line is
## processed by Thor and/or Rake.
##
## Ceedling's command line is processed with these mechanisms:
##  1. Special / edge case hacking of ARGV directly.
##  2. Thor for all application commands and flags.
##  3. Handing off to Rake from either (1) or (2) for task listing or running 
##     build tasks.
##
## EDGE CASE HACKING
## -----------------
## Special / edge cases:
##  1. Silent backwards compatibility support for Rake's `-T`.
##  2. Thor does not recognize "naked" Rake build tasks as application commands
##     (`ceedling test:all` instead of `ceedling build test:all`). So, we catch 
##     this exception and then provide the command line back to Thor as a `build` 
##     command line. This also allows us to ensure Thor processes `build` option
##     flags following naked build tasks that would otherwise be ignored if
##     we simply passed a failing command line to Rake.
##
## THOR
## ----
## Thor is configured or overridden with these special attributes:
##  * The default task is `build`. This means that if the `build` keyword is
##    omitted but Thor otherwise recognizes the command line (a `build` flag is
##    the first item on the command line), it will process it as the `build`
##    command. The build command takes flags and tasks. Tasks are handed off to
##    Rake to process. If no `build` keyword is present and `build` flags come
##    after tasks, Thor sees the command line as unhandled commands.
##  * The PermissiveCLI code handles unrecognized command exception so as to 
##    eat the Thor complaint and re-throw the exception for edge case handling.
##
## NOTES
## -----
##  * Ultimately, any unrecognized command or task is processed by Rake, and 
##    Rake makes the complaint.
##


##
## This Class
## ==========
##
## The nature of Thor more-or-less requires this class to be used as a class
## and not as an insantiated object. This shows up in a variety of ways:
##  * The calling convention is `CeedlingTasks::CLI.start( ARGV )`
##  * Many of the methods necessary to configure the CLI class are class
##    methods in Thor and are called that way.
##
## The nature of Thor both requires and allows for some slightly ugly or
## brittle code -- relying on globals, etc.
##
## Because of this, care has been taken that this class contains as little
## logic as possible and is the funnel for any and all necessary global 
## references and other little oddball needs.
##


# Special handling to prevent Thor from barfing on unrecognized CLI arguments 
# (i.e. Rake tasks)
module PermissiveCLI
  def self.extended(base)
    super
    base.check_unknown_options!
  end

  # Redefine the Thor CLI entrypoint and exception handling
  def start(args, config={})
    begin
      # Copy args as Thor changes them within the call chain of dispatch()
      _args = args.clone()

      # Call Thor's handlers as it does in start()
      config[:shell] ||= Thor::Base.shell.new
      dispatch(nil, args, nil, config)

    # Handle undefined commands at top-level and for `help <command>`
    rescue Thor::UndefinedCommandError => ex
      # Handle `help` for an argument that is not an application command such as `new` or `build`
      if _args[0].downcase() == 'help'

        # Raise fatal StandardError to differentiate from UndefinedCommandError
        msg = "Argument '#{_args[1]}' is not a recognized application command with detailed help. " +
              "It may be a build / plugin task without detailed help or simply a goof."
        raise( msg )

      # Otherwise, eat unhandled command errors
      else
        #  - No error message
        #  - No `exit()`
        #  - Re-raise to allow special, external CLI handling logic
        raise ex
      end
    end
  end
end

module CeedlingTasks

  VERBOSITY_NORMAL = 'normal'
  VERBOSITY_DEBUG = 'debug'

  DOC_LOCAL_FLAG = "Install Ceedling plus supporting tools to vendor/"

  DOC_DOCS_FLAG = "Copy all documentation to docs/ subdirectory of project"

  DOC_PROJECT_FLAG = "Loads the filepath as your base project configuration"

  DOC_MIXIN_FLAG = "Merges the configuration mixin by name or filepath."

  LONGDOC_LOCAL_FLAG = "`--local` copies Ceedling and its dependencies to a vendor/ 
    subdirectory in the root of the project. It also installs a 
    platform-appropriate executable script `ceedling` at the root of the 
    project."

  LONGDOC_MIXIN_FLAG = "`--mixin` merges the specified configuration mixin. This 
    flag may be repeated for multiple mixins. A simple mixin name initiates a 
    lookup from within mixin load paths in your project file and among built-in 
    mixins. A filepath and/or filename (with extension) will instead merge the 
    specified YAML file. See documentation for complete details.
    \x5> --mixin my_compiler --mixin my/path/mixin.yml"

  # Intentionally disallowed Linux/Unix/Windows filename characters to minimize the chance
  # of mistakenly filtering various string-base flags missing a parmeter
  CLI_MISSING_PARAMETER_DEFAULT = "/<>\\||*"

  class CLI < Thor
    include Thor::Actions
    extend PermissiveCLI

    # Ensure we bail out with non-zero exit code if the command line is wrong
    def self.exit_on_failure?() true end

    # Allow `build` to be omitted in command line
    default_command( :build )

    # Intercept construction to extract configuration and injected dependencies
    def initialize(args, config, options)
      super(args, config, options)

      @app_cfg = options[:app_cfg]
      @handler = options[:objects][:cli_handler]

      @loginator = options[:objects][:loginator]

      # Set the name for labelling CLI interactions
      CLI::package_name( @loginator.decorate( 'Ceedling application', LogLabels::TITLE ) )
    end


    # Override Thor help to list Rake tasks as well
    desc "help [COMMAND]", "Describe available commands and list build operations"
    method_option :project, :type => :string, :default => nil, :lazy_default => CLI_MISSING_PARAMETER_DEFAULT, :aliases => ['-p'], :desc => DOC_PROJECT_FLAG
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m'], :desc => DOC_MIXIN_FLAG
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling help` provides summary help for all available application commands 
      and build tasks.

      COMMAND is optional and will produce detailed help for a specific application command --
      not a build or plugin task, however.

      `ceedling help` also lists the available build operations from loading your 
      project configuration. Optionally, a project filepath and/or mixins may be 
      provided to load a different project configuration than the default.

      Notes on Optional Flags:

      • #{LONGDOC_MIXIN_FLAG}
      LONGDESC
    ) )
    def help(command=nil)
      @handler.validate_string_param(
        options[:project],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--project is missing a required filepath parameter"
      )

      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      # Call application help with block to execute Thor's built-in help in the help logic
      @handler.app_help( ENV, @app_cfg, _options, command ) { |command| super(command) }
    end


    desc "new NAME [DEST]", "Create a new project structure at optional DEST path"
    method_option :local, :type => :boolean, :default => false, :desc => DOC_LOCAL_FLAG
    method_option :docs, :type => :boolean, :default => false, :desc => DOC_DOCS_FLAG
    method_option :configs, :type => :boolean, :default => true, :desc => "Install starter project file in project root"
    method_option :force, :type => :boolean, :default => false, :desc => "Ignore any existing project and recreate destination"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    method_option :gitsupport, :type => :boolean, :default => false, :desc => "Create .gitignore / .gitkeep files for convenience"
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling new` creates a new project structure.

      NAME is required and will be the containing directory for the new project.

      DEST is an optional directory path for the new project (e.g. <DEST>/<name>).
      The default is your working directory. Nonexistent paths will be created.

      Notes on Optional Flags:

      • #{LONGDOC_LOCAL_FLAG}

      • `--force` completely destroys anything found in the target path for the 
      new project.
      LONGDESC
    ) )
    def new(name, dest=nil)
      require 'version' # lib/version.rb for TAG constant

      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _dest = dest.dup() if !dest.nil?

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.new_project( ENV, @app_cfg, Ceedling::Version::TAG, _options, name, _dest )
    end

    desc "upgrade PATH", "Upgrade vendored installation of Ceedling for a project at PATH"
    method_option :project, :type => :string, :default => DEFAULT_PROJECT_FILENAME, :lazy_default => CLI_MISSING_PARAMETER_DEFAULT, :desc => "Project filename"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling upgrade` updates an existing project.

      PATH is required and should be the root of the project to upgrade.

      This command only meaningfully operates on projects wth a local vendored copy 
      of Ceedling (in <project>/vendor/) and optional documentation (in 
      <project>/docs/).

      Running this command replaces vendored Ceedling with the version running
      this command. If docs are found, they will be replaced.

      A basic check for project existence looks for vendored ceedlng and a project
      configuration file.

      Notes on Optional Flags:

      • `--project` specifies a filename (optionally with leading path) for the 
      project configuration file used in the project existence check. Otherwise,
      the default ./#{DEFAULT_PROJECT_FILENAME} at the root of the project is
      checked.
      LONGDESC
    ) )
    def upgrade(path)
      @handler.validate_string_param(
        options[:project],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--project is missing a required filename parameter"
      )

      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup()
      _path = path.dup()

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.upgrade_project( ENV, @app_cfg, _options, _path )
    end


    desc "build [TASKS...]", "Run build tasks (`build` keyword not required)"
    method_option :project, :type => :string, :default => nil, :lazy_default => CLI_MISSING_PARAMETER_DEFAULT, :aliases => ['-p'], :desc => DOC_PROJECT_FLAG
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m'], :desc => DOC_MIXIN_FLAG
    method_option :verbosity, :type => :string, :default => VERBOSITY_NORMAL, :lazy_default => CLI_MISSING_PARAMETER_DEFAULT, :aliases => ['-v'],
                  :desc => "Sets logging level"
    method_option :log, :type => :boolean, :default => nil,
                  :desc => "Enable logging to <build path>/#{DEFAULT_BUILD_LOGS_PATH}/#{DEFAULT_CEEDLING_LOGFILE}"
    # :lazy_default allows us to check for missing parameters (if no filepath given Thor unhelpfully provides the flag name as its value)
    method_option :logfile, :type => :string, :aliases => ['-l'], :default => '', :lazy_default => CLI_MISSING_PARAMETER_DEFAULT,
                  :desc => "Enables logging to specified filepath"
    method_option :graceful_fail, :type => :boolean, :default => nil, :desc => "Force exit code of 0 for unit test failures"
    method_option :test_case, :type => :string, :default => '', :lazy_default => CLI_MISSING_PARAMETER_DEFAULT,
                  :desc => "Filter for individual unit test names"
    method_option :exclude_test_case, :type => :string, :default => '', :lazy_default => CLI_MISSING_PARAMETER_DEFAULT,
                  :desc => "Prevent matched unit test names from running"
    # Include for consistency with other commands (override --verbosity)
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling build` executes build tasks created from your project configuration.

      NOTE: `build` is not required to run tasks. The following are equivalent:
      \x5    > ceedling test:all
      \x5    > ceedling build test:all

      TASKS are zero or more build operations created from your project configuration.
      If no tasks are provided, built-in default tasks or your :project ↳ 
      :default_tasks will be executed.

      Notes on Optional Flags:

      • #{LONGDOC_MIXIN_FLAG}

      • `--test-case` and its inverse `--exclude-test-case` set test case name 
      matchers to run only a subset of the unit test suite. See docs for full details.

      • `If --log and --logfile are both specified, --logfile will set the log file path.
      If --no-log and --logfile are both specified, no logging will occur.
      LONGDESC
    ) )
    def build(*tasks)
      @handler.validate_string_param(
        options[:project],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--project is missing a required filepath parameter"
      )

      @handler.validate_string_param(
        options[:verbosity],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--verbosity is missing a required parameter"
      )

      @handler.validate_string_param(
        options[:logfile],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--logfile is missing a required filepath parameter"
      )

      @handler.validate_string_param(
        options[:test_case],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--test-case is missing a required test case name parameter"
      )

      @handler.validate_string_param(
        options[:exclude_test_case],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--exclude-test-case is missing a required test case name parameter"
      )

      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }
      _options[:verbosity] = VERBOSITY_DEBUG if options[:debug]
      _options[:logfile] = options[:logfile].dup()

      @handler.build( env:ENV, app_cfg:@app_cfg, options:_options, tasks:tasks )
    end


    desc "dumpconfig FILEPATH [SECTIONS...]", "Process project configuration and write final config to a YAML file"
    method_option :project, :type => :string, :default => nil, :lazy_default => CLI_MISSING_PARAMETER_DEFAULT, :aliases => ['-p'],
                  :desc => DOC_PROJECT_FLAG
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m'], :desc => DOC_MIXIN_FLAG
    method_option :app, :type => :boolean, :default => true, :desc => "Runs Ceedling application and its config manipulations"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling dumpconfig` loads your project configuration, including all manipulations & merges,
      and writes the final config to a YAML file.

      FILEPATH is a required path to a destination YAML file. A nonexistent path will be created.

      SECTIONS is an optional config “path” that extracts a portion of a configuration. The 
      top-level YAML container will be the path’s last element. 
      The following example will produce config.yml containing ':test_compiler: {...}'.
      \x5> ceedling dumpconfig my/path/config.yml tools test_compiler

      Notes on Optional Flags:

      • #{LONGDOC_MIXIN_FLAG}

      • `--app` loads various settings, merges defaults, loads plugin config changes, and validates 
      the configuration. Disabling it dumps project config after any mixins but before any 
      application manipulations.
      LONGDESC
    ) )
    def dumpconfig(filepath, *sections)
      @handler.validate_string_param(
        options[:project],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--project is missing a required filepath parameter"
      )

      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }
      _filepath = filepath.dup()

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.dumpconfig( ENV, @app_cfg, _options, _filepath, sections )
    end


    desc "environment", "List all configured environment variable names with values."
    method_option :project, :type => :string, :default => nil, :lazy_default => CLI_MISSING_PARAMETER_DEFAULT, :aliases => ['-p'],
                  :desc => DOC_PROJECT_FLAG
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m'], :desc => DOC_MIXIN_FLAG
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling environment` displays all environment variables that have been set for project use.

      Notes on Optional Flags:

      • #{LONGDOC_MIXIN_FLAG}
      LONGDESC
    ) )
    def environment()
      @handler.validate_string_param(
        options[:project],
        CLI_MISSING_PARAMETER_DEFAULT,
        "--project is missing a required filepath parameter"
      )

      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.environment( ENV, @app_cfg, _options )
    end


    desc "examples", "List available example projects"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling examples` lists the names of the example projects that come packaged with Ceedling.

      The output of this list is most useful when used by the `ceedling example` (no ‘s’) command 
      to extract an example project to your filesystem.
      LONGDESC
    ) )
    def examples()
      # Get unfrozen copies so we can add / modify
      _options = options.dup()

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.list_examples( ENV, @app_cfg, _options )
    end


    desc "example NAME [DEST]", "Create named example project in optional DEST path"
    method_option :local, :type => :boolean, :default => false, :desc => DOC_LOCAL_FLAG
    method_option :docs, :type => :boolean, :default => false, :desc => DOC_DOCS_FLAG
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling example` extracts the named example project from within Ceedling to 
      your filesystem.

      NAME is required to specify the example to extract. A list of example projects
      is available with the `examples` command. NAME will be the containing directory 
      for the extracted project.

      DEST is an optional containing directory path (ex: <DEST>/<name>). The default 
      is your working directory. A nonexistent path will be created.

      Notes on Optional Flags:

      • #{LONGDOC_LOCAL_FLAG}

      NOTE: `example` is destructive. If the destination path is a previoulsy created
      example project, `ceedling example` will overwrite the contents.
      LONGDESC
    ) )
    def example(name, dest=nil)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _dest = dest.dup() if !dest.nil?

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.create_example( ENV, @app_cfg, _options, name, _dest )
    end


    desc "version", "Display version details of Ceedling components"
    long_desc( CEEDLING_HANDOFF_OBJECTS[:loginator].sanitize(
      <<-LONGDESC
      `ceedling version` displays the version details of Ceedling and its supporting
      frameworks along with Ceedling’s installation paths.

      Ceedling contains launcher and application components. The launcher
      handles set up, loading your project configuration, and processing your
      command line. The application runs your build and plugin tasks. The
      launcher hands off to the application. The two components are not
      necessarily from the same installation or of the same version. Local
      vendoring options, the WHICH_CEEDLING environment variable, and more can
      cause the Ceedling launcher to load a Ceedling application that is run
      from a different path than the launcher.

      If the launcher and application are from different locations, the version
      output lists details for both. If they are from the same location, only a 
      single Ceedling version is provided.

      NOTES:

      • `version` does not load your project file.

      • The build frameworks Unity, CMock, and CException are always sourced from
      the Ceedling application.
      LONGDESC
    ) )
    def version()
      @handler.version( ENV, @app_cfg )
    end

  end
end
