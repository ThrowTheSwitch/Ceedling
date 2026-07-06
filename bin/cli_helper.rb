# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'app_cfg'

# From Ceedling application
require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/rake_app/rakefile_component_resolver'
require 'versionator' # Outisde DIY context

class CliHelper

  constructor :file_wrapper, :actions_wrapper, :config_walkinator, :path_validator, :rake_task_registry, :loginator, :reportinator, :system_wrapper

  def setup
    # Aliases
    @actions = @actions_wrapper
    @registry = @rake_task_registry
  end

  # For simple CLI commands needing immediate logging with no verbosity management
  def console_project_name(config)
    banner = project_name_banner( config )
    @loginator.console( banner ) if banner
  end

  
  # For CLI commands needing logging with verbosity management
  def log_project_name(config)
    banner = project_name_banner( config )
    @loginator.log( "\n" + banner ) if banner
  end

  def manufacture_app_version(app_cfg)
    return Versionator.new(
      app_cfg[:ceedling_root_path],
      app_cfg[:ceedling_vendor_path]
    )
  end


  def help_footer(ceedling_tag='master')
    @loginator.console() # Blank line for spacing

    # Documentation incorporating Ceedling version tag in URL
    msg = "Ceedling Packet User Manual (v#{ceedling_tag})\n" +
          "https://throwtheswitch.github.io/Ceedling/#{ceedling_tag}/\n\n"
    @loginator.console( msg, LogLabels::DOCUMENTATION )

    # Ceedling Suite
    msg = "Ceedling Suite can help you do more ➡️ https://www.thingamabyte.com/ceedling\n\n"
    @loginator.console( msg, LogLabels::COMMERCIAL )

    # GitHub Sponsors
    msg = "Please consider supporting this work ➡️ https://github.com/sponsors/throwtheswitch\n\n"
    @loginator.console( msg, LogLabels::REQUEST )
  end


  def project_exists?(path, op, *components)
    exists = []

    components.each do |f|
      _path = File.join( path, f )
      exists << (@file_wrapper.exist?( _path ) or @file_wrapper.directory?( _path ))
    end

    return exists.reduce(op)
  end


  def create_project_file(dest, local, ceedling_tag)
    project_filepath = File.join( dest, DEFAULT_PROJECT_FILENAME )
    source_filepath = File.join( 'assets', DEFAULT_PROJECT_FILENAME )

    # Clone the project file
    @actions._copy_file( source_filepath, project_filepath, :force => true)

    # Silently update internal version
    @actions._gsub_file(
      project_filepath,
      /:ceedling_version:\s+'\?'/,
      ":ceedling_version: #{ceedling_tag}",
      :verbose => false
    )

    # Silently path to point at local install
    if local
      @actions._gsub_file(
        project_filepath,
        /:which_ceedling:\s+gem/,
        ":which_ceedling: vendor/ceedling",
        :verbose => false
      )
    end
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
      @loginator.console( " > Set which Ceedling using environment variable WHICH_CEEDLING" ) 
      which_ceedling = env['WHICH_CEEDLING'].strip()
      which_ceedling = :gem if (which_ceedling.casecmp( 'gem' ) == 0)
    end

    # Configuration file
    if which_ceedling.nil?
      value, _ = @config_walkinator.fetch_value( :project, :which_ceedling, hash:config )
      if !value.nil?
        which_ceedling = value.strip()
        @loginator.lazy( Verbosity::OBNOXIOUS ) { " > Set which Ceedling from config :project ↳ :which_ceedling => #{which_ceedling}" }
        which_ceedling = :gem if (which_ceedling.casecmp( 'gem' ) == 0)
      end
    end

    # Working directory
    if which_ceedling.nil?
      if @file_wrapper.directory?( 'vendor/ceedling' )
        which_ceedling = 'vendor/ceedling'
        @loginator.log( " > Set which Ceedling to be vendored installation", Verbosity::OBNOXIOUS )
      end
    end

    # Default to gem
    if which_ceedling.nil?
      which_ceedling = :gem
      @loginator.log( " > Defaulting to running Ceedling from Gem", Verbosity::OBNOXIOUS )
    end

    # If we're launching from the gem, return :gem and initial Rakefile path
    if which_ceedling == :gem
      @loginator.log( " > Launching Ceedling from #{app_cfg[:ceedling_root_path]}/", Verbosity::OBNOXIOUS )
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
    
    @loginator.log( " > Launching Ceedling from #{app_cfg[:ceedling_root_path]}/", Verbosity::OBNOXIOUS )

    return :path, ceedling_path
  end


  def build_rake_task_registry(config:)
    paths = RakefileComponentResolver.resolve(
      config,
      CEEDLING_APPCFG[:ceedling_lib_path],
      CEEDLING_APPCFG[:ceedling_plugins_path]
    )

    @registry.register_test_tasks( paths )
    @registry.register_release_tasks( paths )
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

    unless test_task?( tasks: (tasks.empty? ? default_tasks : tasks ) )
      raise CeedlingException.new( "Test case filters are only applicable to test tasks. No test tasks were specified." )
    end

    already_enabled = false

    # Add test runner configuration setting necessary to use test case filters
    value, _ = @config_walkinator.fetch_value( :test_runner, hash:config )
    if value.nil?
      # If no :test_runner section, create the whole thing
      config[:test_runner] = {:cmdline_args => true}
      already_enabled = false
    else
      # If a :test_runner section, just set :cmdline_args
      already_enabled = (value[:cmdline_args] == true)
      value[:cmdline_args] = true
    end

    # Only log if we actually changed something.
    # No need to notify the user that we enabled a setting that was already enabled.
    unless already_enabled
      @loginator.log( "Enabled :test_runner ↳ :cmdline_args because test case filters are in use.", Verbosity::COMPLAIN, LogLabels::NOTICE )
    end
  end


  def process_graceful_fail(config:, cmdline_graceful_fail:, tasks:, default_tasks:)
    # Precedence
    #  1. Command line option
    #  2. Configuration entry

    # If command line option was set, use it
    if !cmdline_graceful_fail.nil?

      if cmdline_graceful_fail && !test_task?( tasks: (tasks.empty? ? default_tasks : tasks ) )
        raise CeedlingException.new( "The graceful fail option is only applicable to test tasks. No test tasks were specified." )
      end

      return cmdline_graceful_fail
    end

    # If configuration contains :graceful_fail, use it
    value, _ = @config_walkinator.fetch_value( :test_build, :graceful_fail, hash:config )
    return value if value.nil?

    return false
  end


  def process_mixin_filepaths(mixins)
    mixins.reject {|m| m.start_with?(MIXIN_SIGIL_INLINE_YAML)}
  end


  def process_logging_path(config)
    build_root, _ = @config_walkinator.fetch_value( :project, :build_root, hash:config )

    return '' if build_root.nil?

    return File.join( build_root, DEFAULT_BUILD_LOGS_PATH )
  end


  def process_log_filepath(logging_path, log, logfile)
    filepath = nil

    # --log => nil (default / not set), false (explicitly disabled), true (explicitly enabled)
    if log == false
      return ''
    end

    # --logfile => '' default or a path
    if not logfile.empty?
      filepath = logfile
    # If logging is enabled without a filepath in --logfile, then set up the default path
    elsif log
      filepath = File.join( logging_path, DEFAULT_CEEDLING_LOGFILE )
    elsif logfile.empty?
      return ''
    end

    filepath = File.expand_path( filepath )

    dir = File.dirname( filepath )

    # Ensure logging directory path exists
    if !File.exist?( dir )
      @file_wrapper.mkdir( dir )
    end

    # Return filename/filepath
    return filepath
  end


  def test_task?(tasks:)
    return tasks.any? { |task| @registry.task_is?( task, RakeTaskRegistry::TAG_TEST ) }
  end


  def build_task?(tasks:)
    return tasks.any? { |task| @registry.task_is?( task, RakeTaskRegistry::TAG_BUILD ) }
  end


  def print_rake_tasks()
    # This all required digging into Rake internals a bit.

    # Monkey patch Rake::Application class to prevent writing to $stdout directly
    require 'rake_patches'
    Rake::Application.include( CaptureHelpOutput )

    Rake.application.define_singleton_method(:name=) {|n| @name = n}
    Rake.application.name = 'ceedling'
    Rake.application.options.show_tasks = :tasks
    Rake.application.options.show_task_pattern = /^(?!.*build).*$/

    # Use our monkey patched help string accessor instead of Rake's `display_tasks_and_comments()`
    rake_tasks = Rake.application.capture_display_tasks()
    # Indent task help to match Thow
    indentation = ' ' * 2
    rake_tasks.gsub!(/^/, indentation)

    # Print Rake task list directly to the console
    @loginator.console( rake_tasks )
  end


  def run_rake_tasks(tasks)
    Rake.application.collect_command_line_tasks( tasks )
    
    # Replace Rake's exception message to reduce any confusion
    begin
      Rake.application.top_level()

    rescue RuntimeError => ex
      # Check if exception contains an unknown Rake task message
      matches = ex.message.match( /how to build task '(.+)'/i )

      # If it does, replacing the message with our own
      if !matches.nil? and matches.size == 2
        message = "Unrecognized build task '#{matches[1]}'. List available build tasks with `ceedling help`."
        raise CeedlingException.new( message )
      
      # Otherwise, just re-raise
      else
        raise
      end
    end

  end


  # Sets global PROJECT_VERBOSITY and PROJECT_DEBUG constants used throughout
  # the Ceedling application. Once set, subsequent calls are no-ops — the method
  # returns the already-established verbosity — unless `override:` is true.
  #
  # `verbosity` accepts:
  #   - nil            → defaults to Verbosity::NORMAL
  #   - Integer        → used directly as a Verbosity level (e.g. Verbosity::OBNOXIOUS)
  #   - numeric string → parsed as an integer verbosity level (e.g. '4')
  #   - named string   → looked up in VERBOSITY_OPTIONS hash (e.g. 'debug', 'normal')
  def set_verbosity(verbosity=nil, override: true)
    # Idempotency guard: if verbosity is already established, return it as-is.
    # `override: true` bypasses this to allow forced re-configuration (check command).
    return PROJECT_VERBOSITY if !override && @system_wrapper.constants_include?('PROJECT_VERBOSITY')

    verbosity = 
      if verbosity.nil?
        Verbosity::NORMAL

      # Integer Verbosity constants (e.g. Verbosity::OBNOXIOUS) pass through directly
      elsif verbosity.is_a?( Integer )
        verbosity

      # Numeric string (e.g. '4') — convert to integer
      elsif verbosity.to_i.to_s == verbosity
        verbosity.to_i

      # Named string (e.g. 'debug', 'normal') — look up integer value
      elsif VERBOSITY_OPTIONS.include? verbosity.to_sym
        VERBOSITY_OPTIONS[verbosity.to_sym]

      else
        raise "Unkown Verbosity '#{verbosity}' specified"
      end

    # Create global constant PROJECT_VERBOSITY
    Object.send(:remove_const, 'PROJECT_VERBOSITY') if Object.const_defined?('PROJECT_VERBOSITY')
    Object.module_eval("PROJECT_VERBOSITY = verbosity")
    PROJECT_VERBOSITY.freeze()

    # Create global constant PROJECT_DEBUG
    debug = (verbosity == Verbosity::DEBUG)
    Object.send(:remove_const, 'PROJECT_DEBUG') if Object.const_defined?('PROJECT_DEBUG')
    Object.module_eval("PROJECT_DEBUG = debug")
    PROJECT_DEBUG.freeze()

    return verbosity
  end


  def dump_yaml(config, filepath, sections)
    # Default to dumping entire configuration
    _config = config

    # If sections were provided, process them
    if !sections.empty?
      # Symbolify section names
      _sections = sections.map {|section| section.to_sym}
      
      # Try to extract subconfig from section path
      value, _ = @config_walkinator.fetch_value( *_sections, hash:config )

      # If we fail to find the section path, blow up
      if value.nil?
        # Reformat list of symbols to list of :<section>s
        _sections.map! {|section| ":#{section.to_s}"}
        msg = "Cound not find configuration section #{_sections.join(' ↳ ')}"
        raise(msg)
      end

      # Update _config to subconfig with final sections path element as container
      _config = { _sections.last => value }
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
    docs_path_ceedling = File.join( dest, 'ceedling' )

    # Hash that will hold documentation copy paths
    #  - Key: (modified) destination documentation path
    #  - Value: source path
    doc_files = {}

    # Add docs to list from Ceedling (docs/) and supporting projects (docs/<project>)
    { # Source path => docs/ destination path
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

    # Copy all individual documentation files gathered up
    doc_files.each_pair do |_dest, src|
      @actions._copy_file(src, File.join( dest, _dest ), :force => true )
    end

    # If present copy internl HTML documentation bundle (site-local/) to docs/ceedling/
    site_local_path = File.join( ceedling_root, DOCS_SITE_LOCAL_PATH )
    if @file_wrapper.directory?( site_local_path )
      @actions._directory( site_local_path, docs_path_ceedling, :force => true )
    else
      @loginator.console( "Internal HTML documentation bundle not found", LogLabels::WARNING )
      return
    end

    ceedling_index_html_filepath = File.absolute_path( File.join( docs_path_ceedling, 'index.html' ) )
    @loginator.console(
      "\nCeedling documentation available at #{ceedling_index_html_filepath}",
      LogLabels::DOCUMENTATION
    )
    
    dest_abs = File.absolute_path( dest )
    @loginator.console( " > All other documentation available at #{dest_abs}/\n" )
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
    @actions._chmod( File.join( vendor_path, 'bin', 'ceedling' ), 0755 ) unless @system_wrapper.windows?

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
      # Copy entire directory, filter out any junk files
      @actions._directory(
        _src, _dest,
        :force => true
      )
    end

    # Add licenses from Ceedling and supporting projects
    license_files = {}
    [ # Source paths
      '.', # Ceedling
      'vendor/unity',
      'vendor/cmock',
      'vendor/c_exception',
      'vendor/diy'
    ].each do |src|
      # Look up licenses using a Glob as capitalization can be inconsistent
      glob = File.join( ceedling_root, src, 'license.txt' )
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

    # Silently copy Git SHA file for version #.#.#-build lookups if it exists
    if @file_wrapper.exist?( File.join( ceedling_root, GIT_COMMIT_SHA_FILENAME) )
      @actions._copy_file(
        GIT_COMMIT_SHA_FILENAME,
        File.join( vendor_path, GIT_COMMIT_SHA_FILENAME ),
        :force => true, :verbose => false
      )
    end

    # Create executable helper scripts in project root
    if @system_wrapper.windows?
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


  private

  def project_name_banner(config)
    name, _ = @config_walkinator.fetch_value( :project, :name, hash:config )
    return nil if name.nil? || name.empty?

    @reportinator.generate_banner(
      @loginator.decorate( name.upcase, LogLabels::TITLE )
    )
  end

end
