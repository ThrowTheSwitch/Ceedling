require 'rbconfig'
require 'ceedling/constants'

class CliHelper

  constructor :file_wrapper, :config_walkinator, :logger

  def setup
    # ...
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

  ### Private ###

  private

def windows?
  return ((RbConfig::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false) if defined?(RbConfig)
  return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
end

end
