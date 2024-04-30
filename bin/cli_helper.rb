# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rbconfig'
require 'app_cfg'
require 'ceedling/constants' # From Ceedling application

class CliHelper

  constructor :file_wrapper, :actions_wrapper, :config_walkinator, :path_validator, :streaminator

  def setup
    #Aliases
    @actions = @actions_wrapper

    @streaminator.decorate( !windows? )
  end


  def project_exists?( path, op, *components )
    exists = []

    components.each do |f|
      _path = File.join( path, f )
      exists << (@file_wrapper.exist?( _path ) or @file_wrapper.directory?( _path ))
    end

    return exists.reduce(op)
  end


  def create_project_file(dest, local)
    project_filepath = File.join( dest, DEFAULT_PROJECT_FILENAME )
    source_filepath = ''

    if local
      source_filepath = File.join( 'assets', 'project_with_guts.yml' )
    else
      source_filepath = File.join( 'assets', 'project_as_gem.yml' )
    end

    # Clone the project file and update internal version
    require 'ceedling/version'
    @actions._copy_file( source_filepath, project_filepath, :force => true)
    @actions._gsub_file( project_filepath, /:ceedling_version:\s+'\?'/, ":ceedling_version: #{Ceedling::Version::CEEDLING}" )
  end


  # Returns two value: (1) symbol :gem or :path and (2) path for Ceedling installation
  def which_ceedling?(env:, config:{}, app_cfg:)
    # Determine which Ceedling we're running (in priority)
    #  1. If there's an environment variable set, validate it, and return :gem or a path
    #  2. If :project ↳ :which_ceedling exists in the config, validate it, and return :gem or a path
    #  3. If there's a vendor/ceedling/ path in our working directory, return it as a path
    #  4. If nothing is set, default to :gem and return it
    #  5. Update app_cfg paths if not the gem

    # Nil for prioritized case checking logic blocks that follow
    which_ceedling = nil

    # Environment variable
    if !env['WHICH_CEEDLING'].nil?
      @streaminator.stream_puts( " > Set which Ceedling using environment variable WHICH_CEEDLING", Verbosity::OBNOXIOUS )
      which_ceedling = env['WHICH_CEEDLING'].strip()
      which_ceedling = :gem if (which_ceedling.casecmp( 'gem' ) == 0)
    end

    # Configuration file
    if which_ceedling.nil?
      walked = @config_walkinator.fetch_value( config, :project, :which_ceedling )
      if !walked[:value].nil?
        which_ceedling = walked[:value].strip()
        @streaminator.stream_puts( " > Set which Ceedling from config :project ↳ :which_ceedling => #{which_ceedling}", Verbosity::OBNOXIOUS )
        which_ceedling = :gem if (which_ceedling.casecmp( 'gem' ) == 0)
      end
    end

    # Working directory
    if which_ceedling.nil?
      if @file_wrapper.directory?( 'vendor/ceedling' )
        which_ceedling = 'vendor/ceedling'
        @streaminator.stream_puts( " > Set which Ceedling to be vendored installation", Verbosity::OBNOXIOUS )
      end
    end

    # Default to gem
    if which_ceedling.nil?
      which_ceedling = :gem
      @streaminator.stream_puts( " > Defaulting to running Ceedling from Gem", Verbosity::OBNOXIOUS )
    end

    # If we're launching from the gem, return :gem and initial Rakefile path
    if which_ceedling == :gem
      return which_ceedling, app_cfg[:ceedling_rakefile_filepath]
    end

    # Otherwise, handle which_ceedling as a base path
    ceedling_path = which_ceedling.dup()
    @path_validator.standardize_paths( ceedling_path )
    if !@file_wrapper.directory?( ceedling_path )
      raise "Configured Ceedling launch path #{ceedling_path}/ does not exist"
    end

    # Update Ceedling installation paths
    app_cfg.set_paths( ceedling_path )

    # Check updated Ceedling paths
    if !@file_wrapper.exist?( app_cfg[:ceedling_rakefile_filepath] )
      raise "Configured Ceedling launch path #{ceedling_path}/ contains no Ceedling installation"
    end

    # Update variable to full application start path
    ceedling_path = app_cfg[:ceedling_rakefile_filepath]
    
    @streaminator.stream_puts( " > Launching Ceedling from #{ceedling_path}/", Verbosity::OBNOXIOUS )

    return :path, ceedling_path
  end


  def load_ceedling(config:, rakefile_path:, default_tasks:[])
    # Set default tasks
    Rake::Task.define_task(:default => default_tasks) if !default_tasks.empty?

    # Load Ceedling application from Rakefile path
    require( rakefile_path )

    # Loading the Rakefile manipulates the config hash, return it as a convenience
    return config
  end


  def process_testcase_filters(config:, include:, exclude:, tasks:, default_tasks:)
    # Do nothing if no test case filters
    return if (include.nil? || include.empty?) && (exclude.nil? || exclude.empty?)

    # TODO: When we can programmatically check if a task is a test task,
    #       raise an exception if --graceful-fail is set without test operations

    # Add test runner configuration setting necessary to use test case filters
    walked = @config_walkinator.fetch_value( config, :test_runner )
    if walked[:value].nil?
      # If no :test_runner section, create the whole thing
      config[:test_runner] = {:cmdline_args => true}
    else
      # If a :test_runner section, just set :cmdlne_args
      walked[:value][:cmdline_args] = true
    end
  end


  def process_graceful_fail(config:, cmdline_graceful_fail:, tasks:, default_tasks:)
    # TODO: When we can programmatically check if a task is a test task,
    #       raise an exception if --graceful-fail is set without test operations

    # Precedence
    #  1. Command line option
    #  2. Configuration entry

    # If command line option was set, use it
    return cmdline_graceful_fail if !cmdline_graceful_fail.nil?

    # If configuration contains :graceful_fail, use it
    walked = @config_walkinator.fetch_value( config, :test_build, :graceful_fail )
    return walked[:value] if !walked[:value].nil?

    return false
  end


  def process_logging(enabled, filepath)
    # No log file if neither enabled nor a specific filename/filepath
    return '' if !enabled && (filepath.nil? || filepath.empty?())

    # Default logfile name (to be placed in default location) if enabled but no filename/filepath
    return DEFAULT_CEEDLING_LOGFILE if enabled && filepath.empty?()

    # Otherwise, a filename/filepath was provided that implicitly enables logging
    dir = File.dirname( filepath )

    # Ensure logging directory path exists
    if not dir.empty?
      @file_wrapper.mkdir( dir )
    end

    # Return filename/filepath
    return filepath
  end


  def process_stopwatch(tasks:, default_tasks:)
    _tasks = tasks.empty?() ? default_tasks.dup() : tasks.dup()

    # Namespace-less (clobber, clean, etc.), files:, and paths: tasks should not have stopwatch logging
    #  1. Filter out tasks lacking a namespace
    #  2. Look for any tasks other than paths: or files:
    _tasks.select! {|t| t.include?( ':') }
    _tasks.reject! {|t| t =~ /(^files:|^paths:)/}

    return !_tasks.empty?
  end

  def print_rake_tasks()
    Rake.application.standard_exception_handling do
      # (This required digging into Rake internals a bit.)
      Rake.application.define_singleton_method(:name=) {|n| @name = n}
      Rake.application.name = 'ceedling'
      Rake.application.options.show_tasks = :tasks
      Rake.application.options.show_task_pattern = /^(?!.*build).*$/
      Rake.application.display_tasks_and_comments()
    end
  end


  def run_rake_tasks(tasks)
    Rake.application.standard_exception_handling do
      Rake.application.collect_command_line_tasks( tasks )
      Rake.application.top_level()
    end
  end


  # Set global consts for verbosity and debug
  def set_verbosity(verbosity=nil)
    verbosity = verbosity.nil? ? Verbosity::NORMAL : VERBOSITY_OPTIONS[verbosity.to_sym()]

    # If we already set verbosity, there's nothing more to do here
    return if Object.const_defined?('PROJECT_VERBOSITY')

    # Create global constant PROJECT_VERBOSITY
    Object.module_eval("PROJECT_VERBOSITY = verbosity")
    PROJECT_VERBOSITY.freeze()

    # Create global constant PROJECT_DEBUG
    debug = (verbosity == Verbosity::DEBUG)
    Object.module_eval("PROJECT_DEBUG = debug")
    PROJECT_DEBUG.freeze()
  end


  def dump_yaml(config, filepath, sections)
    # Default to dumping entire configuration
    _config = config

    # If sections were provided, process them
    if !sections.empty?
      # Symbolify section names
      _sections = sections.map {|section| section.to_sym}
      
      # Try to extract subconfig from section path
      walked = @config_walkinator.fetch_value( config, *_sections )

      # If we fail to find the section path, blow up
      if walked[:value].nil?
        # Reformat list of symbols to list of :<section>s
        _sections.map! {|section| ":#{section.to_s}"}
        msg = "Cound not find configuration section #{_sections.join(' ↳ ')}"
        raise(msg)
      end

      # Update _config to subconfig with final sections path element as container
      _config = { _sections.last => walked[:value] }
    end

    File.open( filepath, 'w' ) {|out| YAML.dump( _config, out )}
  end


  def lookup_example_projects(examples_path)
    examples = []

    # Examples directory listing glob
    glob = File.join( examples_path, '*' )

    @file_wrapper.directory_listing(glob).each do |path|
      # Skip anything that's not a directory
      next if !@file_wrapper.directory?( path )

      # Split the directory path into elements, indexing the last one
      project = (path.split( File::SEPARATOR ))[-1]

      examples << project
    end

    return examples
  end


  def copy_docs(ceedling_root, dest)
    docs_path = File.join( dest, 'docs' )

    # Hash that will hold documentation copy paths
    #  - Key: (modified) destination documentation path
    #  - Value: source path
    doc_files = {}

    # Add docs to list from Ceedling (docs/) and supporting projects (docs/<project>)
    { # Source path => docs/ destination path
      'docs'                    => '.',
      'vendor/unity/docs'       => 'unity',
      'vendor/cmock/docs'       => 'cmock',
      'vendor/c_exception/docs' => 'c_exception'
    }.each do |src, dest|
      # Form glob to collect all markdown files
      glob = File.join( ceedling_root, src, '*.md' )
      # Look up markdown files
      listing = @file_wrapper.directory_listing( glob ) # Already case-insensitive
      # For each markdown filepath, add to hash
      listing.each do |filepath|
        # Reassign destination
        _dest = File.join( dest, File.basename(filepath) )
        doc_files[ _dest ] = filepath
      end
    end

    # Add docs to list from Ceedling plugins (docs/plugins)
    glob = File.join( ceedling_root, 'plugins/**/README.md' )
    listing = @file_wrapper.directory_listing( glob ) # Already case-insensitive
    listing.each do |path|
      # 'README.md' => '<name>.md' where name extracted from containing path
      rename = path.split(/\\|\//)[-2] + '.md'
      # For each Ceedling plugin readme, add to hash
      dest = File.join( 'plugins', rename )
      doc_files[ dest ] = path
    end

    # Add licenses from Ceedling (docs/) and supporting projects (docs/<project>)
    { # Destination path => Source path
      '.'           => '.', # Ceedling
      'unity'       => 'vendor/unity',
      'cmock'       => 'vendor/cmock',
      'c_exception' => 'vendor/c_exception',
    }.each do |dest, src|
      glob = File.join( ceedling_root, src, 'license.txt' )
      # Look up licenses (use glob as capitalization can be inconsistent)
      listing = @file_wrapper.directory_listing( glob ) # Already case-insensitive
      # Safety check on nil references since we explicitly reference first element
      next if listing.empty?
      filepath = listing.first
      # Reassign dest
      dest = File.join( dest, File.basename( filepath ) )
      doc_files[ dest ] = filepath
    end

    # Copy all documentation
    doc_files.each_pair do |dest, src|
      @actions._copy_file(src, File.join( docs_path, dest ), :force => true)
    end
  end


  def vendor_tools(ceedling_root, dest)
    vendor_path = File.join( dest, 'vendor', 'ceedling' )

    # Copy folders from current Ceedling into project
    %w{plugins lib bin}.each do |folder|
      @actions._directory( 
        folder,
        File.join( vendor_path, folder ),
        :force => true
      )
    end

    # Mark ceedling as an executable
    @actions._chmod( File.join( vendor_path, 'bin', 'ceedling' ), 0755 ) unless windows?

    # Assembly necessary subcomponent dirs
    components = [
      'vendor/c_exception/lib/',
      'vendor/cmock/config/',   
      'vendor/cmock/lib/',      
      'vendor/cmock/src/',      
      'vendor/diy/lib/',         
      'vendor/unity/auto/',     
      'vendor/unity/src/',      
    ]

    # Copy necessary subcomponent dirs into project
    components.each do |path|
      _src = path
      _dest = File.join( vendor_path, path )
      @actions._directory( _src, _dest, :force => true )
    end

    # Add licenses from Ceedling and supporting projects
    license_files = {}
    [ # Source paths
      '.', # Ceedling
      'vendor/unity',
      'vendor/cmock',
      'vendor/c_exception',
    ].each do |src|
      glob = File.join( ceedling_root, src, 'license.txt' )

      # Look up licenses (use glob as capitalization can be inconsistent)
      listing = @file_wrapper.directory_listing( glob ) # Already case-insensitive
      
      # Safety check on nil references since we explicitly reference first element
      next if listing.empty?
      
      # Add license copying to hash      
      license = listing.first
      filepath = File.join( vendor_path, src, File.basename( license ) )
      license_files[ filepath ] = license
    end

    # Copy license files into place
    license_files.each_pair do |dest, src|
      @actions._copy_file( src, dest, :force => true)
    end

    # Create executable helper scripts in project root
    if windows?
      # Windows command prompt launch script
      @actions._copy_file(
        File.join( 'assets', 'ceedling.cmd'),
        File.join( dest, 'ceedling.cmd'),
        :force => true
      )
    else
      # Unix shell launch script
      launch = File.join( dest, 'ceedling')
      @actions._copy_file(
        File.join( 'assets', 'ceedling'),
        launch,
        :force => true
      )
      @actions._chmod( launch, 0755 )
    end
  end

  ### Private ###

  private

  def windows?
    return ((RbConfig::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false) if defined?( RbConfig )
    return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
  end

end
