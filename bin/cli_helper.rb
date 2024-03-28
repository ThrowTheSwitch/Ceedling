require 'rbconfig'
require 'ceedling/constants'

class CliHelper

  constructor :file_wrapper, :actions_wrapper, :config_walkinator, :logger

  def setup
    #Aliases
    @actions = @actions_wrapper
  end

  def load_ceedling(config:, which:, default_tasks:[])
    # Determine which Ceedling we're running
    #  1. Copy the value passed in (most likely a default determined in the first moments of startup)
    #  2. If a :project ↳ :which_ceedling entry exists in the config, use it instead
    _which = which.dup()
    walked = @config_walkinator.fetch_value( config, :project, :which_ceedling )
    _which = walked[:value] if walked[:value]

    if (_which == 'gem')
      # Load the gem
      require 'ceedling'
    else
      # Load Ceedling from a path
      require File.join( _which, '/lib/ceedling.rb' )
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

      # Update _config to subconfig
      _config = walked[:value]
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


  # def copy_docs()
  #   doc_path = use_gem ? File.join(name, 'docs') : File.join(ceedling_path, 'docs')
  #   FileUtils.mkdir_p doc_path

  #   in_doc_path = lambda {|f| File.join(doc_path, f)}

  #   # Add documentation from main projects to list
  #   doc_files = {}
  #   ['docs','vendor/unity/docs','vendor/cmock/docs','vendor/cexception/docs'].each do |p|
  #     Dir[ File.expand_path(File.join(CEEDLING_ROOT, p, '*.md')) ].each do |f|
  #       doc_files[ File.basename(f) ] = f unless(doc_files.include? f)
  #     end
  #   end

  #   # Add documentation from plugins to list
  #   Dir[ File.join(CEEDLING_ROOT, 'plugins/**/README.md') ].each do |plugin_path|
  #     k = "plugin_" + plugin_path.split(/\\|\//)[-2] + ".md"
  #     doc_files[ k ] = File.expand_path(plugin_path)
  #   end

  #   # Copy all documentation
  #   doc_files.each_pair do |k, v|
  #     @actions._copy_file(v, File.join( doc_path, k ), :force => force)
  #   end
  # end


  def vendor_tools(base_path)
    ceedling_path = File.join( base_path, 'vendor', 'ceedling' )

    # Copy folders from current Ceedling into project
    %w{plugins lib bin mixins}.each do |folder|
      @actions._directory( folder, File.join( ceedling_path, folder ), :force => true )
    end

    # Mark ceedling as an executable
    File.chmod( 0755, File.join( ceedling_path, 'bin', 'ceedling' ) ) unless windows?

    # Copy necessary subcomponents from current ceedling into project
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
      @actions._directory( path, File.join( ceedling_path, path ), :force => true )
    end
  end

  ### Private ###

  private

def windows?
  return ((RbConfig::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false) if defined?(RbConfig)
  return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
end

end
