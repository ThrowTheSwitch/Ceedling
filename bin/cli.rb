require 'thor'

# Special handler to prevent Thor from barfing on unrecognized Rake tasks
module PermissiveCLI
  def self.extended(base)
    super
    base.check_unknown_options!
  end

  def start(args, config={})
    config[:shell] ||= Thor::Base.shell.new
    dispatch(nil, args, nil, config)
  rescue Thor::UndefinedCommandError
    # Eat unhandled command errors so we can pass on to more command line processing
  end
end

module CeedlingTasks
  class CLI < Thor
    include Thor::Actions
    extend PermissiveCLI

    # Ensure we bail out with non-zero exit code if the command line is wrong
    def self.exit_on_failure?() true end

    default_task :build

    # Intercept construction to extract configuration and injected dependencies
    def initialize(args, config, options)
      super(args, config, options)

      @app_cfg = options[:app_cfg]
      @configinator = options[:objects][:configinator]
      @runner = options[:objects][:cli_runner]
      @logger = options[:objects][:logger]
    end

    # Override Thor help to list Rake tasks as well
    desc "help [COMMAND]", "Describe available commands and list build operations"
    def help(command=nil)
      # If help requested for a command, show it and skip listing build tasks
      if !command.nil?
        super(command)
        return
      end

      # Load configuration using default options / environment variables
      # Thor does not allow options added to `help`
      config = @configinator.loadinate()

      # Save reference to loaded configuration
      @app_cfg[:project_config] = config

      @runner.set_verbosity() # Default to normal

      @runner.load_ceedling(
        config: config,
        which: @app_cfg[:which_ceedling],
        default_tasks: @app_cfg[:default_tasks]
      )

      super(command)

      @logger.log( 'Build operations (from project configuration):' )
      @runner.print_rake_tasks()
    end

    desc "new PROJECT_NAME", "create a new ceedling project"
    method_option :docs, :type => :boolean, :default => false, :desc => "Add docs in project vendor directory"
    method_option :local, :type => :boolean, :default => false, :desc => "Create a copy of Ceedling in the project vendor directory"
    method_option :gitignore, :type => :boolean, :default => false, :desc => "Create a gitignore file for ignoring ceedling generated files"
    method_option :no_configs, :type => :boolean, :default => false, :desc => "Don't install starter configuration files"
    method_option :noconfigs, :type => :boolean, :default => false

    #deprecated:
    method_option :no_docs, :type => :boolean, :default => false
    method_option :nodocs, :type => :boolean, :default => false
    method_option :as_gem, :type => :boolean, :default => false
    method_option :asgem, :type => :boolean, :default => false
    method_option :with_ignore, :type => :boolean, :default => false
    method_option :withignore, :type => :boolean, :default => false
    def new(name, silent = false)
      @runner.copy_assets_and_create_structure(name, silent, false, options)
    end

    desc "upgrade PROJECT_NAME", "upgrade ceedling for a project (not req'd if gem used)"
    def upgrade(name, silent = false)
      as_local = true
      yaml_path = File.join(name, "project.yml")
      begin
        require File.join(CEEDLING_ROOT,"lib","ceedling","yaml_wrapper.rb")
        as_local = (YamlWrapper.new.load(yaml_path)[:project][:which_ceedling] != 'gem')
      rescue
        raise "ERROR: Could not find valid project file '#{yaml_path}'"
      end
      found_docs = File.exist?( File.join(name, "docs", "CeedlingPacket.md") )
      @runner.copy_assets_and_create_structure(name, silent, true, {:upgrade => true, :no_configs => true, :local => as_local, :docs => found_docs})
    end


    # desc "verbosity", "List verbosity or set with flags"
    # method_option :level, :enum => ['silent', 'errors', 'warnings', 'normal', 'obnoxious', 'debug'], :aliases => ['-l']
    # method_option :num, :type => :numeric, :enum => [0, 1, 2, 3, 4, 5], :aliases => ['-n']
    # def verbosity()
    #   puts 'Verbosity'
    #   puts options

    #   if options.empty?
    #     puts 'Some options'
    #   end
    # end

    desc "build TASKS", "Run build tasks"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :verbosity, :enum => ['silent', 'errors', 'warnings', 'normal', 'obnoxious', 'debug'], :aliases => ['-v']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    method_option :log, :type => :boolean, :default => false, :aliases => ['-l']
    method_option :logfile, :type => :string, :default => ''
    method_option :test_case, :type => :string, :default => ''
    method_option :exclude_test_case, :type => :string, :default => ''
    def build(*tasks)
      config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

      default_tasks = @configinator.default_tasks( config: config, default_tasks: @app_cfg[:default_tasks] )

      # Test case filters
      # ENV['CEEDLING_INCLUDE_TEST_CASE_NAME'] = $1
      # ENV['CEEDLING_EXCLUDE_TEST_CASE_NAME'] = $1
      @runner.process_testcase_filters(
        config: config,
        include: options[:test_case],
        exclude: options[:exclude_test_case],
        tasks: tasks,
        default_tasks: default_tasks
      )

      log_filepath = @runner.process_logging( options[:log], options[:logfile] )

      # Save references
      @app_cfg[:project_config] = config
      @app_cfg[:log_filepath] = log_filepath

      @runner.set_verbosity( options[:verbosity] )

      @runner.load_ceedling( 
        config: config,
        which: @app_cfg[:which_ceedling],
        default_tasks: default_tasks
      )

      @runner.run_rake_tasks( tasks )
    end

    desc "dumpconfig FILEPATH", "Assemble project configuration and write to a YAML file"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    def dumpconfig(filepath)
      # options[:filepath]
      # options[:mixin]

      puts 'Dump'
    end

    # desc "mixins", "Commands to mix settings into base configuration"
    # subcommand "mixins", Mixins

    desc "tasks", "List all build operations"
    method_option :project, :type => :string, :default => nil, :aliases => ['-p']
    method_option :mixin, :type => :string, :default => [], :repeatable => true, :aliases => ['-m']
    def tasks()
      config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

      # Save reference to loaded configuration
      @app_cfg[:project_config] = config

      @runner.set_verbosity() # Default to normal

      @runner.load_ceedling(
        config: config,
        which: @app_cfg[:which_ceedling],
        default_tasks: @app_cfg[:default_tasks]
      )

      @logger.log( 'Build operations (from project configuration):' )
      @runner.print_rake_tasks()
    end

    desc "examples", "list available example projects"
    def examples()
      puts "Available sample projects:"
      FileUtils.cd(File.join(CEEDLING_ROOT, "examples")) do
        Dir["*"].each {|proj| puts "  #{proj}"}
      end
    end

    desc "example PROJ_NAME [DEST]", "new specified example project (in DEST, if specified)"
    def example(proj_name, dest=nil)
      if dest.nil? then dest = proj_name end

      copy_assets_and_create_structure(dest, true, false, {:local=>true, :docs=>true})

      dest_src      = File.join(dest,'src')
      dest_test     = File.join(dest,'test')
      dest_project  = File.join(dest,'project.yml')

      directory "examples/#{proj_name}/src",         dest_src
      directory "examples/#{proj_name}/test",        dest_test
      remove_file dest_project
      copy_file "examples/#{proj_name}/project.yml", dest_project

      puts "\n"
      puts "Example project '#{proj_name}' created!"
      puts " - Tool documentation is located in vendor/ceedling/docs"
      puts " - Execute 'ceedling help' to view available test & build tasks"
      puts ''
    end

    desc "version", "Version details for Ceedling components"
    def version()
      @runner.print_version()
    end

  end
end
