require 'ceedling/constants' # From Ceedling application

class CliHandler

  constructor :configinator, :projectinator, :cli_helper, :path_validator, :actions_wrapper, :logger

  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are lengthy and produce a flood of output.
  def inspect
    return this.class.name
  end

  def setup()
    # Aliases
    @helper = @cli_helper
    @actions = @actions_wrapper
  end

  def app_help(env, app_cfg, options, command, &thor_help)
    @helper.set_verbosity( options[:verbosity] )

    # If help requested for a command, show it and skip listing build tasks
    if !command.nil?
      # Block handler
      @logger._print( '🌱 ' )
      thor_help.call( command ) if block_given?
      return
    end

    # Display Thor-generated help listing
    @logger._print( '🌱 ' )
    thor_help.call( command ) if block_given?

    # If it was help for a specific command, we're done
    return if !command.nil?

    # If project configuration is available, also display Rake tasks
    # Use project file defaults (since `help` allows no flags or options)
    @path_validator.standardize_paths( options[:project], *options[:mixin], )
    if @projectinator.config_available?( filepath:options[:project], env:env )
      help_rake_tasks( env:env, app_cfg:app_cfg, options:options  )
    end
  end


  def new_project(ceedling_root, options, name, dest)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( dest )

    # If destination is nil, reassign it to name
    # Otherwise, join the destination and name into a new path
    dest = dest.nil? ? ('./' + name) : File.join( dest, name )

    # Check for existing project (unless --force)
    if @helper.project_exists?( dest, :|, DEFAULT_PROJECT_FILENAME, 'src', 'test' )
      msg = "It appears a project already exists at #{dest}/. Use --force to destroy it and create a new project."
      raise msg
    end unless options[:force]

    # Blow away any existing directories and contents if --force
    @actions.remove_dir( dest ) if options[:force]

    # Create blank directory structure
    ['.', 'src', 'test', 'test/support'].each do |path|
      @actions._empty_directory( File.join( dest, path) )
    end

    # Vendor the tools and install command line helper scripts
    @helper.vendor_tools( ceedling_root, dest ) if options[:local]

    # Copy in documentation
    @helper.copy_docs( ceedling_root, dest ) if options[:docs]

    # Copy / set up project file
    @helper.create_project_file( ceedling_root, dest, options[:local] ) if options[:configs]

    @logger.log( "\n🌱 New project '#{name}' created at #{dest}/\n" )
  end


  def upgrade_project(ceedling_root, options, path)
    @path_validator.standardize_paths( path, options[:project] )

    # Check for existing project
    if !@helper.project_exists?( path, :&, options[:project], 'vendor/ceedling/lib/ceedling.rb' )
      msg = "Could not find an existing project at #{path}/."
      raise msg
    end

    project_filepath = File.join( path, options[:project] )
    _, config = @projectinator.load( filepath:project_filepath, silent:true )

    if (@helper.which_ceedling?( config ) == 'gem')
      msg = "Project configuration specifies the Ceedling gem, not vendored Ceedling"
      raise msg
    end

    # Recreate vendored tools
    vendor_path = File.join( path, 'vendor', 'ceedling' )
    @actions.remove_dir( vendor_path )
    @helper.vendor_tools( ceedling_root, path )

    # Recreate documentation if we find docs/ subdirectory
    docs_path = File.join( path, 'docs' )
    founds_docs = @helper.project_exists?( path, :&, File.join( 'docs', 'CeedlingPacket.md' ) )
    if founds_docs
      @actions.remove_dir( docs_path )
      @helper.copy_docs( ceedling_root, path )
    end

    @logger.log( "\n🌱 Upgraded project at #{path}/\n" )
  end


  def app_exec(env, app_cfg, options, tasks)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( options[:project], options[:logfile], *options[:mixin] )

    project_filepath, config = @configinator.loadinate( filepath:options[:project], mixins:options[:mixin], env:env )

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    @helper.process_testcase_filters(
      config: config,
      include: options[:test_case],
      exclude: options[:exclude_test_case],
      tasks: tasks,
      default_tasks: default_tasks
    )

    log_filepath = @helper.process_logging( options[:log], options[:logfile] )

    # Save references
    app_cfg[:project_config] = config
    app_cfg[:log_filepath] = log_filepath
    app_cfg[:include_test_case] = options[:test_case]
    app_cfg[:exclude_test_case] = options[:exclude_test_case]

    # Set graceful_exit from command line & configuration options
    app_cfg[:tests_graceful_fail] =
     @helper.process_graceful_fail(
        config: config,
        tasks: tasks,
        cmdline_graceful_fail: options[:graceful_fail]
      )

    # Enable setup / operations duration logging in Rake context
    app_cfg[:stopwatch] = @helper.process_stopwatch( tasks: tasks, default_tasks: default_tasks )

    @helper.load_ceedling( 
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    # Hand Rake tasks off to be executed
    @helper.run_rake_tasks( tasks )
  end


  def dumpconfig(env, app_cfg, options, filepath, sections)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( filepath, options[:project], *options[:mixin] )

    project_filepath, config = @configinator.loadinate( filepath:options[:project], mixins:options[:mixin], env:env )

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    # Save references
    app_cfg[:project_config] = config

    config = @helper.load_ceedling( 
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.dump_yaml( config, filepath, sections )

    @logger.log( "\n🌱 Dumped project configuration to #{filepath}\n" )
  end


  def create_example(ceedling_root, examples_path, options, name, dest)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( dest )

    examples = @helper.lookup_example_projects( examples_path )

    if !examples.include?( name )
      raise( "No example project '#{name}' could be found" )
    end

    # If destination is nil, reassign it to name
    # Otherwise, join the destination and name into a new path
    dest = dest.nil? ? ('./' + name) : File.join( dest, name )

    dest_src      = File.join( dest, 'src' )
    dest_test     = File.join( dest, 'test' )
    dest_project  = File.join( dest, DEFAULT_PROJECT_FILENAME )

    @actions._directory( "examples/#{name}/src", dest_src, :force => true )
    @actions._directory( "examples/#{name}/test", dest_test, :force => true )
    @actions._copy_file( "examples/#{name}/#{DEFAULT_PROJECT_FILENAME}", dest_project, :force => true )

    # Vendor the tools and install command line helper scripts
    @helper.vendor_tools( ceedling_root, dest ) if options[:local]

    # Copy in documentation
    @helper.copy_docs( ceedling_root, dest ) if options[:docs]

    @logger.log( "\n🌱 Example project '#{name}' created at #{dest}/\n" )
  end


  def list_examples(examples_path)
    examples = @helper.lookup_example_projects( examples_path )

    raise( "No examples projects found") if examples.empty?

    output = "\n🌱 Available example projects:\n"

    examples.each {|example| output << " - #{example}\n" }

    @logger.log( output + "\n" )
  end


  def version()
    require 'ceedling/version'
    version = <<~VERSION
      🌱 Ceedling => #{Ceedling::Version::CEEDLING}
            CMock => #{Ceedling::Version::CMOCK}
            Unity => #{Ceedling::Version::UNITY}
       CException => #{Ceedling::Version::CEXCEPTION}
    VERSION
    @logger.log( version )
  end

  ### Private ###

  private

  def help_rake_tasks(env:, app_cfg:, options:)
    project_filepath, config = 
      @configinator.loadinate(
        filepath: options[:project],
        mixins: options[:mixin],
        env: env,
        silent: true # Suppress project config load logging
      )

    # Save reference to loaded configuration
    app_cfg[:project_config] = config

    @helper.load_ceedling(
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: app_cfg[:default_tasks]
    )

    @logger.log( '🌱 Build operations:' )
    @helper.print_rake_tasks()
  end

end
