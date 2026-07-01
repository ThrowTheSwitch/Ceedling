# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'thor'
require 'mixins' # Built-in Mixins
require 'ceedling/constants' # From Ceedling application
require 'ceedling/rake_app/rake_task_registry' # From Ceedling application
require 'versionator' # Outisde DIY context

class CliHandler

  DOCS_SUBDIR = 'docs'

  constructor :configinator, :projectinator, :cli_helper, :path_validator, :rake_task_registry, :actions_wrapper, :loginator

  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are lengthy and produce a flood of output.
  def inspect
    return this.class.name
  end


  def setup()
    # Aliases
    @helper = @cli_helper
    @actions = @actions_wrapper
    @registry = @rake_task_registry
  end


  def validate_string_param( param, missing, message )
    if param == missing
      raise Thor::Error.new( message )
    end
  end


  # Thor application help + Rake help (if available)
  def app_help(env, app_cfg, options, command, &thor_help)
    verbosity = @helper.set_verbosity( options[:verbosity] )

    # If help requested for a command, show it and skip listing build tasks
    if !command.nil?
      # Block handler
      thor_help.call( command ) if block_given?
      return
    end

    # Display Thor-generated help listing
    thor_help.call( command ) if block_given?

    # If it was help for a specific command, we're done
    return if !command.nil?

    # If project configuration is available, also display Rake tasks
    @path_validator.standardize_paths( options[:project], *@helper.process_mixin_filepaths(options[:mixin]) )
    if @projectinator.config_available?( filepath:options[:project], env:env )
      list_rake_tasks(
        env:env,
        app_cfg: app_cfg,
        filepath: options[:project],
        mixins: options[:mixin],
        # Silent Ceedling loading unless debug verbosity
        silent: !(verbosity == Verbosity::DEBUG)
      )
    else
      # If no project configuration is available then note why we aren't displaying more
      msg = "Run help commands in a directory with a project file to list additional options\n\n"
      @loginator.console( msg, LogLabels::NOTICE )
    end

    version = @helper.manufacture_app_version( app_cfg )

    @helper.help_footer( version.ceedling_tag )
  end


  # Public to be used by `-T` ARGV hack handling
  def rake_help(env:, app_cfg:)
    @helper.set_verbosity( Verbosity::ERRORS )

    list_rake_tasks( env:env, app_cfg:app_cfg )
  end


  def new_project(env, app_cfg, ceedling_tag, options, dest)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( dest )

    # If destination is nil, assume it's the working directory
    dest ||= '.'

    # Check for existing project (unless --force)
    if @helper.project_exists?( dest, :|, DEFAULT_PROJECT_FILENAME, 'src', 'test' )
      msg = "It appears a project already exists at \"#{dest}/\"! Use --force to destroy it and create a new project."
      raise msg
    end unless options[:force]

    # Update app_cfg paths (ignore return values)
    @helper.which_ceedling?( env:env, app_cfg:app_cfg )

    # Thor Actions for project tasks use paths in relation to this path
    ActionsWrapper.source_root( app_cfg[:ceedling_root_path] )

    # Blow away any existing directories and contents if --force
    @actions.remove_dir( dest ) if options[:force]

    # Create blank directory structure
    ['.', 'src', 'test', 'test/support'].each do |path|
      @actions._empty_directory( File.join( dest, path) )
    end

    # Vendor the tools and install command line helper scripts
    @helper.vendor_tools( app_cfg[:ceedling_root_path], dest ) if options[:local]

    # Copy / set up project file
    @helper.create_project_file( dest, options[:local], ceedling_tag ) if options[:configs]
    
    # Copy in documentation
    @helper.copy_docs( app_cfg[:ceedling_root_path], File.join( dest, DOCS_SUBDIR ) ) if options[:docs]

    # Copy Git Ignore file 
    if options[:gitsupport]
      @actions._copy_file(
        File.join( 'assets', 'default_gitignore' ),
        File.join( dest, '.gitignore' ),
        :force => true
      )
      @actions._touch_file( File.join( dest, 'test/support', '.gitkeep') )
    end
    
    @loginator.console( "\nNew project created at #{File.absolute_path(dest)}/\n", LogLabels::TITLE )
  end


  def upgrade_project(env, app_cfg, options, path)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( path, options[:project] )

    # Check for existing project
    if !@helper.project_exists?( path, :&, options[:project], 'vendor/ceedling/lib/version.rb' )
      msg = "Could not find an existing project at #{path}/."
      raise msg
    end

    which, _ = @helper.which_ceedling?( env:env, app_cfg:app_cfg )
    if (which == :gem)
      msg = "Project configuration specifies the Ceedling gem, not vendored Ceedling"
      @loginator.console( msg, LogLabels::NOTICE )
    end

    # Thor Actions for project tasks use paths in relation to this path
    ActionsWrapper.source_root( app_cfg[:ceedling_root_path] )

    # Recreate vendored tools
    vendor_path = File.join( path, 'vendor', 'ceedling' )
    @actions.remove_dir( vendor_path )
    @helper.vendor_tools( app_cfg[:ceedling_root_path], path )

    # Recreate documentation if we find docs/ subdirectory
    docs_path = File.join( path, 'docs' )
    founds_docs = @helper.project_exists?( path, :&, File.join( 'docs', 'CeedlingPacket.md' ) )
    if founds_docs
      @actions.remove_dir( docs_path )
      @helper.copy_docs( app_cfg[:ceedling_root_path], File.join( path, DOCS_SUBDIR ) )
    end

    @loginator.console( "\nUpgraded project at #{path}/\n", LogLabels::TITLE )
  end


  def build(env:, app_cfg:, options:{}, tasks:)
    # No override, allow build verbosity to be set by config or command line
    # But, we may change verbosity just before processing the project configuration and running tasks (at bottom)
    _verbosity = options[:verbosity]
    @helper.set_verbosity( _verbosity, override: false )

    @path_validator.standardize_paths( options[:project], options[:logfile], *@helper.process_mixin_filepaths(options[:mixin]) )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    @cli_helper.log_project_name( config )

    # Populate Rake task registry early (Pass 1) so the same instance is reused by
    # rakefile.rb via CEEDLING_HANDOFF_OBJECTS injection and re-scanned (Pass 2)
    # after all .rake files are loaded with constants fully resolved.
    @helper.build_rake_task_registry( config:config )

    default_tasks = @configinator.default_tasks( config:config, default_tasks:app_cfg[:default_tasks] )

    @helper.process_testcase_filters(
      config: config,
      include: options[:test_case],
      exclude: options[:exclude_test_case],
      tasks: tasks,
      default_tasks: default_tasks
    )

    logging_path = @helper.process_logging_path( config )
    log_filepath = @helper.process_log_filepath( logging_path, options[:log], options[:logfile] )

    @loginator.console( " > Logfile: #{log_filepath}" ) if !log_filepath.empty?

    # Save references
    app_cfg.set_project_config( config )
    app_cfg.set_logging_path( logging_path )
    app_cfg.set_log_filepath( log_filepath )
    app_cfg.set_include_test_case( options[:test_case] )
    app_cfg.set_exclude_test_case( options[:exclude_test_case] )

    # Set graceful_exit from command line & configuration options
    app_cfg.set_tests_graceful_fail(
      @helper.process_graceful_fail(
        config: config,
        cmdline_graceful_fail: options[:graceful_fail],
        tasks: tasks,
        default_tasks: default_tasks
      )
    )

    # Look up if any tasks we will execute are build tasks
    build_tasks = @helper.build_task?( tasks: (tasks.empty? ? default_tasks : tasks ) )

    # Enable setup / operations duration logging in Rake context if build tasks are being invoked
    app_cfg.set_build_tasks( build_tasks )

    _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

    # Log Ceedling Application version information
    _version = Versionator.new(
      app_cfg[:ceedling_root_path],
      app_cfg[:ceedling_vendor_path]
    )

    @loginator.lazy( Verbosity::OBNOXIOUS, LogLabels::CONSTRUCT ) do 
      <<~VERSION
      \nApplication & Build Frameworks
         Ceedling => #{_version.ceedling_build}
            CMock => #{_version.cmock_tag}
            Unity => #{_version.unity_tag}
       CException => #{_version.cexception_tag}
      VERSION
    end
  
    # If no build tasks are to be invoked, then quiet down logging during configuration processing.
    # This prevents a flood of often non-relevant configuration processing logging during simple tasks.
    # (Unless debug verbosity)
    if (!build_tasks and options[:verbosity] != Verbosity::DEBUG)
      @helper.set_verbosity( Verbosity::ERRORS )
    end

    @helper.load_ceedling(
      config: config,
      rakefile_path: path,
      default_tasks: default_tasks
    )

    # Restore original verbosity state after optionally quieting down configuration processing logging
    @helper.set_verbosity( _verbosity )

    # Hand Rake tasks off to be executed
    @helper.run_rake_tasks( tasks )
  end


  def dumpconfig(env, app_cfg, options, filepath, sections)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( filepath, options[:project], *@helper.process_mixin_filepaths(options[:mixin]) )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    @cli_helper.log_project_name( config )

    # Exception handling to ensure we dump the configuration regardless of config validation errors
    begin
      # If enabled, process the configuration through Ceedling automatic settings, defaults, plugins, etc.
      if options[:app]
        default_tasks = @configinator.default_tasks( config:config, default_tasks:app_cfg[:default_tasks] )

        # Save references
        app_cfg.set_project_config( config )
        app_cfg.set_logging_path( @helper.process_logging_path( config ) )

        _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

        config = @helper.load_ceedling( 
          config: config,
          rakefile_path: path,
          default_tasks: default_tasks
        )
      else
        @loginator.console( " > Skipped loading Ceedling application" )
      end
    ensure
      @helper.dump_yaml( config, filepath, sections )

      @loginator.console( "Dumped project configuration to #{filepath}\n", LogLabels::TITLE )      
    end
  end


  def check(env, app_cfg, options)
    # Force obnoxious (or debug) verbosity, overriding any prior verbosity state
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( options[:project], *@helper.process_mixin_filepaths(options[:mixin]) )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    @cli_helper.log_project_name( config )

    default_tasks = @configinator.default_tasks( config:config, default_tasks:app_cfg[:default_tasks] )

    # Save references; explicitly disable log file output
    app_cfg.set_project_config( config )
    app_cfg.set_logging_path( @helper.process_logging_path( config ) )
    app_cfg.set_log_filepath( '' )

    _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

    begin
      @helper.load_ceedling(
        config: config,
        rakefile_path: path,
        default_tasks: default_tasks
      )
    ensure
      @loginator.console( "\nProject configuration processed.\n\n", LogLabels::TITLE )
    end
  end


  def environment(env, app_cfg, options)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( options[:project], *@helper.process_mixin_filepaths(options[:mixin]) )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    @cli_helper.log_project_name( config )

    # Save references
    app_cfg.set_project_config( config )
    app_cfg.set_logging_path( @helper.process_logging_path( config ) )

    _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

    config = @helper.load_ceedling(
      config: config,
      rakefile_path: path
    )

    env_list = []

    # Process external environment -- filter for Ceedling variables
    env.each do |var, value|
      next if !(var =~ /ceedling/i)
      name = var.to_s
      env_list << "#{name}: \"#{value}\""
    end

    # Process environment created by configuration
    config[:environment].each do |env|
      env.each_key do |key|
        name = key.to_s.upcase
        env_list << "#{name}: \"#{env[key]}\""
      end
    end

    output = "Environment variables:"

    env_list.sort.each do |line|
      output << "\n • #{line}"
    end

    if env_list.empty?
      output << " <none>\n"
    else
      output << "\n"
    end

    @loginator.console( "#{output}\n", LogLabels::TITLE )
  end


  def list_examples(env, app_cfg, options)
    @helper.set_verbosity( options[:verbosity] )

    # Process which_ceedling for app_cfg modifications but ignore return values
    @helper.which_ceedling?( env:env, app_cfg:app_cfg )

    examples = @helper.lookup_example_projects( app_cfg[:ceedling_examples_path] )

    raise( "No examples projects found") if examples.empty?

    output = "Available example projects:\n"

    examples.each {|example| output << " • #{example}\n" }

    @loginator.console(
      "#{output}\n",
      LogLabels::TITLE
    )

    @loginator.console(
      "See Ceedling documentation for details of each project.\n",
      LogLabels::DOCUMENTATION
    )
  end


  def create_example(env, app_cfg, options, name, dest)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( dest )

    # Process which_ceedling for app_cfg modifications but ignore return values
    @helper.which_ceedling?( env:env, app_cfg:app_cfg )

    examples = @helper.lookup_example_projects( app_cfg[:ceedling_examples_path] )

    if !examples.include?( name )
      raise( "No example project '#{name}' could be found" )
    end

    # If destination is nil, reassign it to name
    # Otherwise, join the destination and name into a new path
    dest = dest.nil? ? ('./' + name) : File.join( dest, name )

    dest_src      = File.join( dest, 'src' )
    dest_test     = File.join( dest, 'test' )
    dest_mixin    = File.join( dest, 'mixin' )
    dest_project  = File.join( dest, DEFAULT_PROJECT_FILENAME )
    dest_readme   = File.join( dest, 'README.md' )

    # Thor Actions for project tasks use paths in relation to this path
    ActionsWrapper.source_root( app_cfg[:ceedling_root_path] )

    @actions._directory( "examples/#{name}/src", dest_src, :force => true )
    @actions._directory( "examples/#{name}/test", dest_test, :force => true )
    @actions._directory( "examples/#{name}/mixin", dest_mixin, :force => true )
    @actions._copy_file( "examples/#{name}/#{DEFAULT_PROJECT_FILENAME}", dest_project, :force => true )
    @actions._copy_file( "examples/#{name}/README.md", dest_readme, :force => true )

    # Vendor the tools and install command line helper scripts
    @helper.vendor_tools( app_cfg[:ceedling_root_path], dest ) if options[:local]

    # Copy in documentation
    @helper.copy_docs( app_cfg[:ceedling_root_path], File.join( dest, DOCS_SUBDIR ) ) if options[:docs]

    @loginator.console(
      "\nExample project '#{name}' created at #{dest}/\n\n",
      LogLabels::TITLE
    )

    @loginator.console(
      "See #{dest}/README.md for project details.\n",
      LogLabels::DOCUMENTATION
    )
  end


  def docs(app_cfg, dest)
    # Thor Actions file operations require an anchored source root
    ActionsWrapper.source_root( app_cfg[:ceedling_root_path] )

    # Default to current working directory when no destination is given
    dest ||= '.'

    # Written directly to chosen destination path
    @helper.copy_docs( app_cfg[:ceedling_root_path], dest )
  end


  def version(env, app_cfg)
    # Versionator is not needed to persist. So, it's not built in the DIY collection.

    @helper.set_verbosity( Verbosity::ERRORS )

    # Ceedling bootloader
    launcher = Versionator.new( app_cfg[:ceedling_root_path] )

    # This call updates Ceedling paths in app_cfg if which Ceedling has been modified
    @helper.which_ceedling?( env:env, app_cfg:app_cfg )

    # Ceedling application
    application = @helper.manufacture_app_version( app_cfg )

    # Blank Ceedling version block to be built out conditionally below
    ceedling = nil

    # A simple Ceedling version block because launcher and application are the same
    if launcher.ceedling_install_path == application.ceedling_install_path
      ceedling = <<~CEEDLING
      Ceedling => #{application.ceedling_build}
      ----------------------
      #{application.ceedling_install_path + '/'}
      CEEDLING

    # Full Ceedling version block because launcher and application are not the same
    else
      ceedling = <<~CEEDLING
      Ceedling Launcher => #{launcher.ceedling_build}
      ----------------------
      #{launcher.ceedling_install_path + '/'}

      Ceedling App => #{application.ceedling_build}
      ----------------------
      #{application.ceedling_install_path + '/'}
      CEEDLING
    end

    build_frameworks = <<~BUILD_FRAMEWORKS
    Build Frameworks
    ----------------------
         CMock => #{application.cmock_tag}
         Unity => #{application.unity_tag}
    CException => #{application.cexception_tag}
    BUILD_FRAMEWORKS

    # Assemble version details
    version = ceedling + "\n" + build_frameworks

    # Add some indent
    version = version.split( "\n" ).map {|line| '  ' + line}.join( "\n" )

    # Add a header
    version = "Welcome to Ceedling!\n\n" + version

    @loginator.console( version, LogLabels::TITLE )
  end


  ### Private ###

  private

  def list_rake_tasks(env:, app_cfg:, filepath:nil, mixins:[], silent:false)
    _, config = 
      @configinator.loadinate(
        builtin_mixins:BUILTIN_MIXINS,
        filepath: filepath,
        mixins: mixins,
        env: env,
        silent: silent
      )

    # Save reference to loaded configuration
    app_cfg.set_project_config( config )
    app_cfg.set_logging_path( @helper.process_logging_path( config ) )

    _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

    @helper.load_ceedling(
      config: config,
      rakefile_path: path,
      default_tasks: app_cfg[:default_tasks]
    )

    msg = "Ceedling build & plugin tasks:\n(Parameterized tasks tend to need enclosing quotes or escape sequences in most shells)"
    @loginator.console( msg, LogLabels::TITLE )

    @helper.print_rake_tasks()
  end

end
