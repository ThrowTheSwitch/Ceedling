require 'rbconfig'
require 'ceedling/constants'

class CliRunner

  constructor :yaml_wrapper, :file_wrapper, :config_walkinator, :logger

  def setup
    # ...
  end

  def copy_assets_and_create_structure(name, silent=false, force=false, options = {})

    puts "WARNING: --no_docs deprecated. It is now the default. Specify -docs if you want docs installed." if (options[:no_docs] || options[:nodocs])
    puts "WARNING: --as_gem deprecated. It is now the default. Specify -local if you want ceedling installed to this project." if (options[:as_gem] || options[:asgem])
    puts "WARNING: --with_ignore deprecated. It is now called -gitignore" if (options[:with_ignore] || options[:withignore])

    use_docs     = options[:docs] || false
    use_configs  = !(options[:no_configs] || options[:noconfigs] || false)
    use_gem      = !(options[:local])
    use_ignore   = options[:gitignore] || false
    is_upgrade   = options[:upgrade] || false

    ceedling_path     = File.join(name, 'vendor', 'ceedling')
    source_path       = File.join(name, 'src')
    test_path         = File.join(name, 'test')
    test_support_path = File.join(name, 'test/support')

    # If it's not an upgrade, make sure we have the paths we expect
    if (!is_upgrade)
      [source_path, test_path, test_support_path].each do |d|
        FileUtils.mkdir_p d
      end
    else
      prj_yaml = @yaml_wrapper.load(File.join(name, 'project.yml'))
      test_support_path = if prj_yaml.key?(:path) && \
                             prj_yaml[:path].key?(:support)
                            prj_yaml.key?[:path][:support]
                          else
                            ''
                          end
    end

    # Genarate gitkeep in test support path
    FileUtils.touch(File.join(test_support_path, '.gitkeep')) unless \
      test_support_path.empty?

    # If documentation requested, create a place to dump them and do so
    doc_path = ''
    if use_docs
      doc_path = use_gem ? File.join(name, 'docs') : File.join(ceedling_path, 'docs')
      FileUtils.mkdir_p doc_path

      in_doc_path = lambda {|f| File.join(doc_path, f)}

      # Add documentation from main projects to list
      doc_files = {}
      ['docs','vendor/unity/docs','vendor/cmock/docs','vendor/cexception/docs'].each do |p|
        Dir[ File.expand_path(File.join(CEEDLING_ROOT, p, '*.md')) ].each do |f|
          doc_files[ File.basename(f) ] = f unless(doc_files.include? f)
        end
      end

      # Add documentation from plugins to list
      Dir[ File.join(CEEDLING_ROOT, 'plugins/**/README.md') ].each do |plugin_path|
        k = "plugin_" + plugin_path.split(/\\|\//)[-2] + ".md"
        doc_files[ k ] = File.expand_path(plugin_path)
      end

      # Copy all documentation
      doc_files.each_pair do |k, v|
        copy_file(v, in_doc_path.call(k), :force => force)
      end
    end

    # If installed locally to project, copy ceedling, unity, cmock, & supports to vendor
    unless use_gem
      FileUtils.mkdir_p ceedling_path

      #copy full folders from ceedling gem into project
      %w{plugins lib bin}.map do |f|
        {:src => f, :dst => File.join(ceedling_path, f)}
      end.each do |f|
        directory(f[:src], f[:dst], :force => force)
      end

      # mark ceedling as an executable
      File.chmod(0755, File.join(ceedling_path, 'bin', 'ceedling')) unless windows?

      #copy necessary subcomponents from ceedling gem into project
      sub_components = [
        {:src => 'vendor/c_exception/lib/',     :dst => 'vendor/c_exception/lib'},
        {:src => 'vendor/cmock/config/',        :dst => 'vendor/cmock/config'},
        {:src => 'vendor/cmock/lib/',           :dst => 'vendor/cmock/lib'},
        {:src => 'vendor/cmock/src/',           :dst => 'vendor/cmock/src'},
        {:src => 'vendor/diy/lib',              :dst => 'vendor/diy/lib'},
        {:src => 'vendor/unity/auto/',          :dst => 'vendor/unity/auto'},
        {:src => 'vendor/unity/src/',           :dst => 'vendor/unity/src'},
      ]

      sub_components.each do |c|
        directory(c[:src], File.join(ceedling_path, c[:dst]), :force => force)
      end
    end

    # We're copying in a configuration file if we haven't said not to
    if (use_configs)
      dst_yaml = File.join(name, 'project.yml')
      src_yaml = if use_gem
        File.join(CEEDLING_ROOT, 'assets', 'project_as_gem.yml')
      else
        if windows?
          copy_file(File.join('assets', 'ceedling.cmd'), File.join(name, 'ceedling.cmd'), :force => force)
        else
          copy_file(File.join('assets', 'ceedling'), File.join(name, 'ceedling'), :force => force)
          File.chmod(0755, File.join(name, 'ceedling'))
        end
        File.join(CEEDLING_ROOT, 'assets', 'project_with_guts.yml')
      end

      # Perform the actual clone of the config file, while updating the version
      File.open(dst_yaml,'w') do |dst|
        require File.expand_path(File.join(File.dirname(__FILE__),"..","lib","ceedling","version.rb"))
        dst << File.read(src_yaml).gsub(":ceedling_version: '?'",":ceedling_version: #{Ceedling::Version::CEEDLING}")
        puts "      create  #{dst_yaml}"
      end
    end

    # Copy the gitignore file if requested
    if (use_ignore)
      copy_file(File.join('assets', 'default_gitignore'), File.join(name, '.gitignore'), :force => force)
    end

    unless silent
      puts "\n"
      puts "Project '#{name}' #{force ? "upgraded" : "created"}!"
      puts " - Tool documentation is located in #{doc_path}" if use_docs
      puts " - Execute 'ceedling help' from #{name} to view available test & build tasks"
      puts ''
    end
  end


  def load_ceedling(config:, which:, default_tasks:)
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
    Rake::Task.define_task(:default => default_tasks)

    # Load Ceedling
    Ceedling.load_rakefile()
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
  def set_verbosity(verbosity='')
    verbosity = verbosity.nil? ? Verbosity::NORMAL : VERBOSITY_OPTIONS[verbosity.to_sym()]

    # Create global constant PROJECT_VERBOSITY
    Object.module_eval("PROJECT_VERBOSITY = verbosity")
    PROJECT_VERBOSITY.freeze()

    # Create global constant PROJECT_DEBUG
    debug = (verbosity == Verbosity::DEBUG)
    Object.module_eval("PROJECT_DEBUG = debug")
    PROJECT_DEBUG.freeze()
  end


  def print_version()
    require 'ceedling/version'
    version = <<~VERSION
        Ceedling:: #{Ceedling::Version::CEEDLING}
           CMock:: #{Ceedling::Version::CMOCK}
           Unity:: #{Ceedling::Version::UNITY}
      CException:: #{Ceedling::Version::CEXCEPTION}
    VERSION
    @logger.log( version )
  end

  ### Private ###

  private

def windows?
  return ((RbConfig::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false) if defined?(RbConfig)
  return ((Config::CONFIG['host_os'] =~ /mswin|mingw/) ? true : false)
end

end
