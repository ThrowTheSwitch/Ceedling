
class CliHandler

  constructor :configinator, :projectinator, :cli_helper, :actions_wrapper, :logger

  def setup()
    # Aliases
    @helper = @cli_helper
    @actions = @actions_wrapper
  end

  # Complemented by `rake_tasks()` that can be called independently
  def app_help(app_cfg, command, &thor_help)
    # If help requested for a command, show it and skip listing build tasks
    if !command.nil?
      # Block handler
      thor_help.call( command )
      return
    end

    # Display Thor-generated help listing
    thor_help.call( command )

    # If it was help for a specific command, we're done
    return if !command.nil?

    # If project configuration is available, also display Rake tasks
    rake_tasks( app_cfg: app_cfg ) if @projectinator.config_available?
  end

  def copy_assets_and_create_structure(name, silent=false, force=false, options = {})

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
    FileUtils.touch(File.join(test_support_path, '.gitkeep')) unless test_support_path.empty?

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

  def app_exec(app_cfg, options, tasks)
    project_filepath, config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

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

    @helper.set_verbosity( options[:verbosity] )

    @helper.load_ceedling( 
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.run_rake_tasks( tasks )
  end

  def rake_exec(app_cfg:, tasks:)
    project_filepath, config = @configinator.loadinate() # Use defaults for project file & mixins

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    # Save references
    app_cfg[:project_config] = config

    # Enable setup / operations duration logging in Rake context
    app_cfg[:stopwatch] = @helper.process_stopwatch( tasks: tasks, default_tasks: default_tasks )

    @helper.set_verbosity() # Default verbosity

    @helper.load_ceedling( 
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.run_rake_tasks( tasks )
  end

  def dumpconfig(app_cfg, options, filepath, sections)
    project_filepath, config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    # Save references
    app_cfg[:project_config] = config

    @helper.set_verbosity( options[:verbosity] )

    config = @helper.load_ceedling( 
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.dump_yaml( config, filepath, sections )
  end

  def rake_tasks(app_cfg:, project:nil, mixins:[], verbosity:nil)
    project_filepath, config = @configinator.loadinate( filepath: project, mixins: mixins )

    # Save reference to loaded configuration
    app_cfg[:project_config] = config

    @helper.set_verbosity( verbosity ) # Default to normal

    @helper.load_ceedling(
      project_filepath: project_filepath,
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: app_cfg[:default_tasks]
    )

    @logger.log( 'Build operations:' )
    @helper.print_rake_tasks()
  end


  def create_example(ceedling_root, examples_path, options, name, dest)
    examples = @helper.lookup_example_projects( examples_path )

    if !examples.include?( name )
      raise( "No example project '#{name}' could be found" )
    end

    @helper.set_verbosity( options[:verbosity] )

    # If destination is nil, reassign it to name
    # Otherwise, join the destination and name into a new path
    dest = dest.nil? ? name : File.join( dest, name )

    dest_src      = File.join( dest, 'src' )
    dest_test     = File.join( dest, 'test' )
    dest_project  = File.join( dest, 'project.yml' )

    @actions._directory( "examples/#{name}/src", dest_src )
    @actions._directory( "examples/#{name}/test", dest_test )
    @actions._copy_file( "examples/#{name}/project.yml", dest_project )

    vendored_ceedling = File.join( dest, 'vendor', 'ceedling' )

    @helper.vendor_tools( ceedling_root, vendored_ceedling ) if options[:local]
    @helper.copy_docs( ceedling_root, dest ) if options[:docs]

    @logger.log( "\nExample project '#{name}' created at #{dest}/\n" )
  end


  def list_examples(examples_path)
    examples = @helper.lookup_example_projects( examples_path )

    raise( "No examples projects found") if examples.empty?

    @logger.log( "\nAvailable exmple projects:" )

    examples.each {|example| @logger.log( " - #{example}" ) }

    @logger.log( "\n" )
  end


  def version()
    require 'ceedling/version'
    version = <<~VERSION
        Ceedling => #{Ceedling::Version::CEEDLING}
           CMock => #{Ceedling::Version::CMOCK}
           Unity => #{Ceedling::Version::UNITY}
      CException => #{Ceedling::Version::CEXCEPTION}
    VERSION
    @logger.log( version )
  end

end
