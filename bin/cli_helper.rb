require 'rbconfig'
require 'ceedling/constants'

class CliHelper

  constructor :file_wrapper, :actions_wrapper, :config_walkinator, :logger

  def setup
    #Aliases
    @actions = @actions_wrapper
  end

  def load_ceedling(project_filepath:, config:, which:, default_tasks:[])
    # Determine which Ceedling we're running
    #  1. Copy the which value passed in (most likely a default determined in the first moments of startup)
    #  2. If a :project ↳ :which_ceedling entry exists in the config, use it instead
    _which = which.dup()
    walked = @config_walkinator.fetch_value( config, :project, :which_ceedling )
    _which = walked[:value] if walked[:value]

    if (_which == 'gem')
      # Load the gem
      require 'ceedling'
    else
      # Load Ceedling from a path
      project_path = File.dirname( project_filepath )
      ceedling_path = File.join( project_path, _which, '/lib/ceedling.rb' )

      if !@file_wrapper.exist?( ceedling_path )
        raise "Configuration :project ↳ :which_ceedling => '#{_which}' points to a path relative to your project file that contains no Ceedling installation"
      end

      require( ceedling_path )
    end

    # Set default tasks
    Rake::Task.define_task(:default => default_tasks) if !default_tasks.empty?

    # Load Ceedling
    Ceedling.load_rakefile()

    # Processing the Rakefile in the preceeding line processes the config hash
    return config
  end


  def process_testcase_filters(config:, include:, exclude:, tasks:, default_tasks:)
    # Do nothing if no test case filters
    return if include.empty? and exclude.empty?

    _tasks = tasks.empty?() ? default_tasks : tasks

    # Blow up if a test case filter is provided without any actual test tasks
    if _tasks.none?(/^test:/i)
      raise "Test case filters specified without any test tasks"
    end

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


  def process_graceful_fail(config:, tasks:, cmdline_graceful_fail:)
    _tasks = tasks.empty?() ? default_tasks : tasks

    # Blow up if graceful fail is provided without any actual test tasks
    if _tasks.none?(/^test:/i)
      raise "--graceful-fail specified without any test tasks"
    end

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
    return '' if !enabled and filepath.empty?()

    # Default logfile name (to be placed in default location) if enabled but no filename/filepath
    return DEFAULT_CEEDLING_LOGFILE if enabled and filepath.empty?()

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


  def copy_docs(src_base_path, dest_base_path)
    docs_path = File.join( dest_base_path, 'docs' )

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
      glob = File.join( src_base_path, src, '*.md' )
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
    glob = File.join( src_base_path, 'plugins/**/README.md' )
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
      glob = File.join( src_base_path, src, 'license.txt' )
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


  def vendor_tools(src_base_path, dest_base_path)
    # Copy folders from current Ceedling into project
    %w{plugins lib bin mixins}.each do |folder|
      @actions._directory( folder, File.join( dest_base_path, folder ), :force => true )
    end

    # Mark ceedling as an executable
    File.chmod( 0755, File.join( dest_base_path, 'bin', 'ceedling' ) ) unless windows?

    # Copy necessary subcomponent dirs into project
    components = [
      'vendor/c_exception/lib/',
      'vendor/cmock/config/',   
      'vendor/cmock/lib/',      
      'vendor/cmock/src/',      
      'vendor/diy/lib/',         
      'vendor/unity/auto/',     
      'vendor/unity/src/',      
    ]

    components.each do |path|
      src = File.join( src_base_path, path )
      dest = File.join( dest_base_path, path )
      @actions._directory( src, dest, :force => true )
    end

    # Add licenses from Ceedling and supporting projects
    license_files = {}
    [ # Source paths
      '.', # Ceedling
      'vendor/unity',
      'vendor/cmock',
      'vendor/c_exception',
    ].each do |src|
      glob = File.join( src_base_path, src, 'license.txt' )
      # Look up licenses (use glob as capitalization can be inconsistent)
      listing = @file_wrapper.directory_listing( glob ) # Already case-insensitive
      # Safety check on nil references since we explicitly reference first element
      next if listing.empty?
      filepath = listing.first
      dest = File.join( dest_base_path, src, File.basename( filepath ) )
      license_files[ dest ] = filepath
    end

    license_files.each_pair do |dest, src|
      @actions._copy_file( src, dest, :force => true)
    end

  end

  ### Private ###

  private

def windows?
  return ((RbConfig::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false) if defined?(RbConfig)
  return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
end

end
