
class CliHandler

  constructor :configinator, :cli_helper, :yaml_wrapper, :logger

  def setup()
    # Alias
    @helper = @cli_helper
  end

  def app_help(app_cfg, command, &thor_help)
    # If help requested for a command, show it and skip listing build tasks
    if !command.nil?
      # Block handler
      thor_help.call( command )
      return
    end

    # Call Rake task listing method
    # Provide block to execute after Ceedling is loaded before tasks are listed
    rake_tasks( app_cfg: app_cfg ) { callback.call( command ) }
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

  def app_exec(app_cfg, options, tasks)
    config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

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

    @helper.set_verbosity( options[:verbosity] )

    @helper.load_ceedling( 
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.run_rake_tasks( tasks )
  end

  def rake_exec(app_cfg:, tasks:)
    config = @configinator.loadinate() # Use defaults for project file & mixins

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    # Save references
    app_cfg[:project_config] = config

    @helper.set_verbosity() # Default verbosity

    @helper.load_ceedling( 
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.run_rake_tasks( tasks )
  end

  def dumpconfig(app_cfg, options, filepath, sections)
    config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    # Save references
    app_cfg[:project_config] = config

    @helper.set_verbosity() # Default to normal

    config = @helper.load_ceedling( 
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @helper.dump_yaml( config, filepath, sections )
  end

  def rake_tasks(app_cfg:, project:nil, mixins:[], &post_ceedling_load)
    config = @configinator.loadinate( filepath: project, mixins: mixins )

    # Save reference to loaded configuration
    app_cfg[:project_config] = config

    @helper.set_verbosity() # Default to normal

    @helper.load_ceedling(
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: app_cfg[:default_tasks]
    )

    # Block handler
    post_ceedling_load.call() if post_ceedling_load

    @logger.log( 'Build operations (from project configuration):' )
    @helper.print_rake_tasks()
  end

  def version()
    require 'ceedling/version'
    version = <<~VERSION
        Ceedling:: #{Ceedling::Version::CEEDLING}
           CMock:: #{Ceedling::Version::CMOCK}
           Unity:: #{Ceedling::Version::UNITY}
      CException:: #{Ceedling::Version::CEXCEPTION}
    VERSION
    @logger.log( version )
  end

end
