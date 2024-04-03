require 'thor'
require 'ceedling/constants' # From Ceedling application

##
## Command Line Handling
## =====================
##
## OVERVIEW
## --------
## Ceedling's command line handling marries Thor and Rake.
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
##  2. No command line arguments provided (triggering default tasks build).
##  3. Thor did not recognize "naked" build tasks as application commands
##     (`ceedling test:all` instead of `ceedling build test:all`). We catch 
##     this exception and provide the command line as a `build` command to 
##     Thor. This also allows us to ensure Thor processes `build` flags
##     following naked build tasks that it would otherwise ignore.
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



# Special handler to prevent Thor from barfing on unrecognized CLI arguments 
# (i.e. Rake tasks)
module PermissiveCLI
  def self.extended(base)
    super
    base.check_unknown_options!
  end

  def start(args, config={})
    config[:shell] ||= Thor::Base.shell.new
    dispatch(nil, args, nil, config)
  rescue Thor::UndefinedCommandError
    # Eat unhandled command errors
    #  - No error message
    #  - No `exit()`
    #  - Re-raise to allow Rake task CLI handling elsewhere
    raise
  end
end

module CeedlingTasks

  VERBOSITY_NORMAL = 'normal'
  VERBOSITY_DEBUG = 'debug'

  DOC_LOCAL_FLAG = "`--local` copies Ceedling and its dependencies to a vendor/ 
    subdirectory in the root of the project. It also installs a 
    platform-appropriate executable script `ceedling` at the root of the 
    project."

  DOC_DOCS_FLAG = "`--docs` copies all tool documentation to a docs/ 
    subdirectory in the root of the project."

  DOC_PROJECT_FLAG = "`--project` loads the specified project file as your 
    base configuration."

  DOC_MIXIN_FLAG = "`--mixin` merges the specified configuration mixin. This 
    flag may be repeated for multiple mixins. A simple mixin name will initiate a 
    lookup from within mixin load paths specified in your project file and among 
    Ceedling’s internal mixin load path. A filepath and/or filename (having an 
    extension) will instead merge the specified mixin configuration YAML file. 
    See documentation for complete details on mixins.
    \x5> --mixin my_compiler --mixin my/path/mixin.yml"

  CEEDLING_EXAMPLES_PATH = File.join( CEEDLING_ROOT, 'examples' )

  class CLI < Thor
    include Thor::Actions
    extend PermissiveCLI

    # Ensure we bail out with non-zero exit code if the command line is wrong
    def self.exit_on_failure?() true end

    # Allow `build` to be omitted in command line
    default_task :build

    # Intercept construction to extract configuration and injected dependencies
    def initialize(args, config, options)
      super(args, config, options)

      @app_cfg = options[:app_cfg]
      @handler = options[:objects][:cli_handler]
    end


    # Override Thor help to list Rake tasks as well
    desc "help [COMMAND]", "Describe available commands and list build operations"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `ceedling help` provides standard help for all available application commands 
    and build tasks.

    COMMAND is optional and will produce detailed help for a specific command.

    `ceedling help` also lists the available build operations from loading your 
    project configuration. Optionally, a project filepath and/or mixins may be 
    provided (see below) to load a different project configuration. If not
    provided, the default options for loading project configuration will be used.

    Optional Flags:

    • #{DOC_PROJECT_FLAG}

    • #{DOC_MIXIN_FLAG}
    LONGDESC
    def help(command=nil)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      # Call application help with block to execute Thor's built-in help in the help logic
      @handler.app_help( ENV, @app_cfg, _options, command ) { |command| super(command) }
    end


    desc "new NAME [DEST]", "Create a new project"
    method_option :local, :type => :boolean, :default => false, :desc => "Install Ceedling plus supporting tools to vendor/"
    method_option :docs, :type => :boolean, :default => false, :desc => "Copy documentation to docs/"
    method_option :configs, :type => :boolean, :default => true, :desc => "Install starter configuration files"
    method_option :force, :type => :boolean, :default => false, :desc => "Ignore any existing project and remove destination"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `ceedling new` creates a new project structure.

    NAME is required and will be the containing directory for the new project.

    DEST is an optional directory path in which to place the new project (e.g. 
    <DEST>/<name>). The default desintation is your working directory. If the 
    containing path does not exist, it will be created.

    Optional Flags:

    • #{DOC_LOCAL_FLAG}

    • #{DOC_DOCS_FLAG}

    • `--configs` copies a starter project configuration file into the root of the 
    new project.

    • `--force` overrides protectons preventing a new project from overwriting an 
    existing project. This flag completely destroys anything found in the target
    path for the new project.
    LONGDESC
    def new(name, dest=nil)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _dest = dest.dup() if !dest.nil?

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.new_project( CEEDLING_ROOT, _options, name, _dest )
    end


    desc "upgrade PATH", "Upgrade vendored installation of Ceedling for a project"
    method_option :project, :type => :string, :default => DEFAULT_PROJECT_FILENAME, :desc => "Project filename"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `ceedling upgrade` updates an existing project.

    PATH is required and should be the root of the project to upgrade.

    This command only meaningfully operates on projects wth a local vendored copy 
    of Ceedlng (in <project>/vendor/) and optionally a local copy of the 
    documentation (in <project>/docs/).

    Running this command will replace vendored Ceedling with the version carrying
    out this command. If documentation is found, it will replace it with the bundle
    accompanying the version of Ceedling carrying out this command.

    A basic check for project existence looks for vendored ceedlng and a project
    configuration file.

    Optional Flags:

    • `--project` specifies a filename (optionally with leading path) for the 
    project configuration file used in the project existence check. Otherwise,
    the default ./#{DEFAULT_PROJECT_FILENAME} at the root of the project is
    checked.
    LONGDESC
    def upgrade(path)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup()
      _path = path.dup()

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.upgrade_project( CEEDLING_ROOT, _options, _path )
    end


    desc "build [TASKS...]", "Run build tasks (`build` keyword not required)"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :verbosity, :enum => ['silent', 'errors', 'warnings', VERBOSITY_NORMAL, 'obnoxious', VERBOSITY_DEBUG], :default => VERBOSITY_NORMAL, :aliases => ['-v']
    method_option :log, :type => :boolean, :default => false, :aliases => ['-l']
    method_option :logfile, :type => :string, :default => ''
    method_option :graceful_fail, :type => :boolean, :default => nil
    method_option :test_case, :type => :string, :default => ''
    method_option :exclude_test_case, :type => :string, :default => ''

    long_desc <<-LONGDESC
    `ceedling build` executes build tasks created from your project configuration.

    NOTE: `build` is not required to run tasks. The following usages are equivalent:
    \x5    > ceedling test:all
    \x5    > ceedling build test:all

    TASKS are zero or more build operations created from your project configuration.
    If no tasks are provided, the built-in default tasks or your :project ↳ 
    :default_tasks will be executed.

    Optional Flags:

    • #{DOC_PROJECT_FLAG}

    • #{DOC_MIXIN_FLAG}

    • `--verbosity` sets the logging level.

    • `--log` enables logging to the default filename and path location within your 
    project build directory.

    • `--logfile` enables logging to the specified log filepath 
    (ex: my/path/file.log).

    • `--graceful-fail` ensures an exit code of 0 even when unit tests fail. See
    documentation for full details.

    • `--test-case` sets a test case name matcher to run only a subset of test
    suite’s unit test cases. See documentation for full details.

    • `--exclude-test-case` is the inverse of `--test-case`. See documentation for
    full details.
    LONGDESC
    def build(*tasks)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }

      @handler.build( env:ENV, app_cfg:@app_cfg, options:_options, tasks:tasks )
    end


    desc "dumpconfig FILEPATH [SECTIONS...]", "Process project configuration and write final result to a YAML file"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `ceedling dumpconfig` loads your project configuration, including all manipulations & merges,
    and writes the final config to a YAML file.

    FILEPATH is a required path to a destination YAML file. If the containing path does not exist, 
    it will be created.

    SECTIONS is an optional configuration section “path” that extracts only a portion of a 
    configuration. The resulting top-level YAML container will be the last element of the path. 
    The following example will produce a config.yml containing :test_compiler: {...}.
    No section path produces a complete configuration.
    \x5> ceedling dumpconfig my/path/config.yml tools test_compiler

    Optional Flags:

    • #{DOC_PROJECT_FLAG}

    • #{DOC_MIXIN_FLAG}
    LONGDESC
    def dumpconfig(filepath, *sections)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }
      _filepath = filepath.dup()

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.dumpconfig( ENV, @app_cfg, _options, _filepath, sections )
    end


    desc "environment", "List all configured environment variable names and string values."
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `ceedling environment` displays all environment variables that have been set for project use.

    Optional Flags:

    • #{DOC_PROJECT_FLAG}

    • #{DOC_MIXIN_FLAG}
    LONGDESC
    def environment()
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.environment( ENV, @app_cfg, _options )
    end

    desc "examples", "List available example projects"
    long_desc <<-LONGDESC
    `ceedling examples` lists the names of the example projects that come packaged with Ceedling.

    The output of this list is most useful when used by the `ceedling example` (no ‘s’) command 
    to extract an example project to your filesystem.
    LONGDESC
    def examples()
      @handler.list_examples( CEEDLING_EXAMPLES_PATH )
    end


    desc "example NAME [DEST]", "Create named example project (in optional DEST path)"
    method_option :local, :type => :boolean, :default => false, :desc => "Install Ceedling plus supporting tools to vendor/"
    method_option :docs, :type => :boolean, :default => false, :desc => "Copy documentation to docs/"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `ceedling example` extracts the named example project from within Ceedling to 
    your filesystem.

    NAME is required to specify the example to extract. A list of example projects
    is available with the `examples` command. NAME will be the containing directory 
    for the extracted project.

    DEST is an optional directory path in which to place the example project (ex: 
    <DEST>/<name>). The default desintation is your working directory. If the 
    containing path does not exist, it will be created.

    Optional Flags:

    • #{DOC_LOCAL_FLAG}

    • #{DOC_DOCS_FLAG}

    NOTE: `example` is destructive. If the destination path is a previoulsy created
    example project, `ceedling example` will forcibly overwrite the contents.
    LONGDESC
    def example(name, dest=nil)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _dest = dest.dup() if !dest.nil?

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.create_example( CEEDLING_ROOT, CEEDLING_EXAMPLES_PATH, _options, name, _dest )
    end


    desc "version", "Display version details for Ceedling components"
    # No long_desc() needed
    def version()
      @handler.version()
    end

  end
end
