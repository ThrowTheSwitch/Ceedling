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
    #  - Re-raise to allow Rake task handling
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
    def help(command=nil)
      # Get unfrozen copy of options so we can add to it
      _options = options.dup()
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
    # method_option :gitignore, :type => :boolean, :default => false, :desc => "Create .gitignore file to ignore Ceedling-generated files"
    def new(name, dest=nil)
      # Get unfrozen copy of options so we can add to it
      _options = options.dup()
      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil
      @handler.new_project( CEEDLING_ROOT, _options, name, dest )
    end


    desc "upgrade PATH", "Upgrade vendored installation of Ceedling for a project"
    method_option :project, :type => :string, :default => DEFAULT_PROJECT_FILENAME, :desc => "Project filename"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    def upgrade(path)
      # Get unfrozen copy of options so we can add to it
      _options = options.dup()
      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil
      @handler.upgrade_project( CEEDLING_ROOT, _options, path )
    end


    desc "build TASKS", "Run build tasks (`build` keyword optional)"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :verbosity, :enum => ['silent', 'errors', 'warnings', 'normal', 'obnoxious', VERBOSITY_DEBUG], :aliases => ['-v']
    # method_option :num, :type => :numeric, :enum => [0, 1, 2, 3, 4, 5], :aliases => ['-n']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :log, :type => :boolean, :default => false, :aliases => ['-l']
    method_option :logfile, :type => :string, :default => ''
    method_option :graceful_fail, :type => :boolean, :default => nil
    method_option :test_case, :type => :string, :default => ''
    method_option :exclude_test_case, :type => :string, :default => ''
    def build(*tasks)
      @handler.app_exec( ENV, @app_cfg, options, tasks )
    end


    desc "dumpconfig FILEPATH [SECTIONS]", "Process project configuration and dump compelete result to a YAML file"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :debug, :type => :boolean, :default => false, :hide => true
    def dumpconfig(filepath, *sections)
      # Get unfrozen copy of options so we can add to it
      _options = options.dup()
      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil
      @handler.dumpconfig( ENV, @app_cfg, _options, filepath, sections )
    end


    desc "examples", "List available example projects"
    def examples()
      @handler.list_examples( CEEDLING_EXAMPLES_PATH )
    end


    desc "example NAME [DEST]", "Create named example project (in optional DEST path)"
    method_option :local, :type => :boolean, :default => false, :desc => "Install Ceedling plus supporting tools to vendor/"
    method_option :docs, :type => :boolean, :default => false, :desc => "Copy documentation to docs/"
    method_option :debug, :type => :boolean, :default => false, :hide => true
    def example(name, dest=nil)
      # Get unfrozen copy of options so we can add to it
      _options = options.dup()
      _options[:verbosity] = options[:debug] ? VERBOSITY_DEBUG : nil
      @handler.create_example( CEEDLING_ROOT, CEEDLING_EXAMPLES_PATH, _options, name, dest )
    end


    desc "version", "Version details for Ceedling components"
    def version()
      @handler.version()
    end

  end
end
