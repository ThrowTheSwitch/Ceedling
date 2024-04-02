require 'thor'
require 'ceedling/constants' # From Ceedling application

# Special handler to prevent Thor from barfing on unrecognized CLI arguments (i.e. Rake tasks)
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

  VERBOSITY_DEBUG = 'debug'

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
    `help` provides standard help for all available application commands.

    COMMAND is optional and will produce detailed help for a specific command.

    `help` also lists the available build operations from loading your project configuration.
    Optionally, a project filepath and/or mixins may be provided through command line flags. If not
    provided, default options for loading project configuration will be used.

    Mixin flags may be specified multiple times and may refer to either a mixin name in a load path
    or a specific filepath of a mixin.
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
    `new` creates a new project structure.
    
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
    `upgrades` updates an existing project structure.

    LONGDESC
    def upgrade(path)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup()
      _path = path.dup()

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.upgrade_project( CEEDLING_ROOT, _options, _path )
    end


    desc "build TASKS", "Run build tasks (`build` keyword optional)"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :verbosity, :enum => ['silent', 'errors', 'warnings', 'normal', 'obnoxious', VERBOSITY_DEBUG], :aliases => ['-v']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :log, :type => :boolean, :default => false, :aliases => ['-l']
    method_option :logfile, :type => :string, :default => ''
    method_option :graceful_fail, :type => :boolean, :default => nil
    method_option :test_case, :type => :string, :default => ''
    method_option :exclude_test_case, :type => :string, :default => ''
    long_desc <<-LONGDESC
    `build` executes operations created from your project configuration.
    
    LONGDESC
    def build(*tasks)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _options[:project] = options[:project].dup() if !options[:project].nil?
      _options[:mixin] = []
      options[:mixin].each {|mixin| _options[:mixin] << mixin.dup() }

      @handler.app_exec( ENV, @app_cfg, _options, tasks )
    end


    desc "dumpconfig FILEPATH [SECTIONS]", "Process project configuration and dump compelete result to a YAML file"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `dumpconfig` loads your project configuration, including all manipulations, and dumps the final config to a YAML file.
    
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


    desc "examples", "List available example projects"
    long_desc <<-LONGDESC
    `examples` lists the names of the example projects that come packaged with Ceedling.

    The output of this list is most useful when used with the `example` command to extract an example project to your filesystem.
    LONGDESC
    def examples()
      @handler.list_examples( CEEDLING_EXAMPLES_PATH )
    end


    desc "example NAME [DEST]", "Create named example project (in optional DEST path)"
    method_option :local, :type => :boolean, :default => false, :desc => "Install Ceedling plus supporting tools to vendor/"
    method_option :docs, :type => :boolean, :default => false, :desc => "Copy documentation to docs/"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    long_desc <<-LONGDESC
    `example` extracts the named example project from within Ceedling to your filesystem.

    A list of example projects is available with the `examples` command.

    DEST is an optional directory path in which to place the example project (e.g. <DEST>/<example>).

    The optional `--local` flag copies Ceedling and its dependencies to a vendor/ directory next to the example project.

    The optional `--docs` flag copies all tool documentation to a docs/ directory next to the example project.

    `example` is destructive. It will replace the existing contents of a previoulsy created example project.
    LONGDESC
    def example(name, dest=nil)
      # Get unfrozen copies so we can add / modify
      _options = options.dup()
      _dest = dest.dup() if !dest.nil?

      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil

      @handler.create_example( CEEDLING_ROOT, CEEDLING_EXAMPLES_PATH, _options, name, _dest )
    end


    desc "version", "Version details for Ceedling components"
    def version()
      @handler.version()
    end

  end
end
