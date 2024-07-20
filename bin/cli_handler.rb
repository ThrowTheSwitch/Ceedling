# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'mixins' # Built-in Mixins
require 'ceedling/constants' # From Ceedling application

class CliHandler

  constructor :configinator, :projectinator, :cli_helper, :path_validator, :actions_wrapper, :loginator

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
    @path_validator.standardize_paths( options[:project], *options[:mixin], )
    return if !@projectinator.config_available?( filepath:options[:project], env:env )

    list_rake_tasks(
      env:env,
      app_cfg: app_cfg,
      filepath: options[:project],
      mixins: options[:mixin],
      # Silent Ceedling loading unless debug verbosity
      silent: !(verbosity == Verbosity::DEBUG)
    )
  end


  # Public to be used by `-T` ARGV hack handling
  def rake_help(env:, app_cfg:)
    @helper.set_verbosity() # Default to normal

    list_rake_tasks( env:env, app_cfg:app_cfg )
  end


  def new_project(env, app_cfg, options, name, dest)
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

    # Copy in documentation
    @helper.copy_docs( app_cfg[:ceedling_root_path], dest ) if options[:docs]

    # Copy / set up project file
    @helper.create_project_file( dest, options[:local] ) if options[:configs]

    # Copy Git Ignore file
    if options[:gitsupport]
      @actions._copy_file(
        File.join( 'assets', 'default_gitignore' ),
        File.join( dest, '.gitignore' ),
        :force => true
      )
      @actions._touch_file( File.join( dest, 'test/support', '.gitkeep') )
    end

    @loginator.log() # Blank line
    @loginator.log( "New project '#{name}' created at #{dest}/\n", Verbosity::NORMAL, LogLabels::TITLE )
  end


  def upgrade_project(env, app_cfg, options, path)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( path, options[:project] )

    # Check for existing project
    if !@helper.project_exists?( path, :&, options[:project], 'vendor/ceedling/lib/ceedling/version.rb' )
      msg = "Could not find an existing project at #{path}/."
      raise msg
    end

    which, _ = @helper.which_ceedling?( env:env, app_cfg:app_cfg )
    if (which == :gem)
      msg = "Project configuration specifies the Ceedling gem, not vendored Ceedling"
      @loginator.log( msg, Verbosity::NORMAL, LogLabels::NOTICE )
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
      @helper.copy_docs( app_cfg[:ceedling_root_path], path )
    end

    @loginator.log() # Blank line
    @loginator.log( "Upgraded project at #{path}/\n", Verbosity::NORMAL, LogLabels::TITLE )
  end


  def build(env:, app_cfg:, options:{}, tasks:)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( options[:project], options[:logfile], *options[:mixin] )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    default_tasks = @configinator.default_tasks( config:config, default_tasks:app_cfg[:default_tasks] )

    @helper.process_testcase_filters(
      config: config,
      include: options[:test_case],
      exclude: options[:exclude_test_case],
      tasks: tasks,
      default_tasks: default_tasks
    )

    log_filepath = @helper.process_logging( options[:log], options[:logfile] )

    # Save references
    app_cfg.set_project_config( config )
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

    # Enable setup / operations duration logging in Rake context
    app_cfg.set_stopwatch( @helper.process_stopwatch( tasks:tasks, default_tasks:default_tasks ) )

    _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

    @helper.load_ceedling(
      config: config,
      rakefile_path: path,
      default_tasks: default_tasks
    )

    # Hand Rake tasks off to be executed
    @helper.run_rake_tasks( tasks )
  end


  def dumpconfig(env, app_cfg, options, filepath, sections)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( filepath, options[:project], *options[:mixin] )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    # Exception handling to ensure we dump the configuration regardless of config validation errors
    begin
      # If enabled, process the configuration through Ceedling automatic settings, defaults, plugins, etc.
      if options[:app]
        default_tasks = @configinator.default_tasks( config:config, default_tasks:app_cfg[:default_tasks] )

        # Save references
        app_cfg.set_project_config( config )

        _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

        config = @helper.load_ceedling(
          config: config,
          rakefile_path: path,
          default_tasks: default_tasks
        )
      else
        @loginator.log( " > Skipped loading Ceedling application", Verbosity::OBNOXIOUS )
      end
    ensure
      @helper.dump_yaml( config, filepath, sections )

      @loginator.log() # Blank line
      @loginator.log( "Dumped project configuration to #{filepath}\n", Verbosity::NORMAL, LogLabels::TITLE )
    end
  end


  def environment(env, app_cfg, options)
    @helper.set_verbosity( options[:verbosity] )

    @path_validator.standardize_paths( options[:project], *options[:mixin] )

    _, config = @configinator.loadinate( builtin_mixins:BUILTIN_MIXINS, filepath:options[:project], mixins:options[:mixin], env:env )

    # Save references
    app_cfg.set_project_config( config )

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
        name = key.to_s
        env_list << "#{name}: \"#{env[key]}\""
      end
    end

    output = "Environment variables:\n"

    env_list.sort.each do |line|
      output << " • #{line}\n"
    end

    @loginator.log() # Blank line
    @loginator.log( output + "\n", Verbosity::NORMAL, LogLabels::TITLE )
  end


  def list_examples(env, app_cfg, options)
    @helper.set_verbosity( options[:verbosity] )

    # Process which_ceedling for app_cfg modifications but ignore return values
    @helper.which_ceedling?( env:env, app_cfg:app_cfg )

    examples = @helper.lookup_example_projects( app_cfg[:ceedling_examples_path] )

    raise( "No examples projects found") if examples.empty?

    output = "Available example projects:\n"

    examples.each {|example| output << " • #{example}\n" }

    @loginator.log() # Blank line
    @loginator.log( output + "\n", Verbosity::NORMAL, LogLabels::TITLE )
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
    @helper.copy_docs( app_cfg[:ceedling_root_path], dest ) if options[:docs]

    @loginator.log() # Blank line
    @loginator.log( "Example project '#{name}' created at #{dest}/\n", Verbosity::NORMAL, LogLabels::TITLE )
  end


  def version()
    require 'ceedling/version'
    version = <<~VERSION
    Welcome to Ceedling!

       Ceedling => #{Ceedling::Version::CEEDLING}
          CMock => #{Ceedling::Version::CMOCK}
          Unity => #{Ceedling::Version::UNITY}
     CException => #{Ceedling::Version::CEXCEPTION}
    VERSION
    @loginator.log( version, Verbosity::NORMAL, LogLabels::TITLE )
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

    _, path = @helper.which_ceedling?( env:env, config:config, app_cfg:app_cfg )

    @helper.load_ceedling(
      config: config,
      rakefile_path: path,
      default_tasks: app_cfg[:default_tasks]
    )

    msg = "Ceedling build & plugin tasks:\n(Parameterized tasks tend to need enclosing quotes or escape sequences in most shells)"
    @loginator.log( msg, Verbosity::NORMAL, LogLabels::TITLE )

    @helper.print_rake_tasks()
  end

end
