
class CliHandler

  constructor :configinator, :cli_runner, :logger

  def setup()
    # Alias
    @runner = @cli_runner
  end

  def help(command, app_cfg, &callback)
    # If help requested for a command, show it and skip listing build tasks
    if !command.nil?
      # Block handler
      callback.call( command )
      return
    end

    # Load configuration using default options / environment variables
    # Thor does not allow options added to `help`
    config = @configinator.loadinate()

    # Save reference to loaded configuration
    app_cfg[:project_config] = config

    @runner.set_verbosity() # Default to normal

    @runner.load_ceedling( config: config, which: app_cfg[:which_ceedling] )

    # Block handler
    callback.call( command )

    @logger.log( 'Build operations (from project configuration):' )
    @runner.print_rake_tasks()
  end

  def build(tasks, app_cfg, options)
    config = @configinator.loadinate( filepath: options[:project], mixins: options[:mixin] )

    default_tasks = @configinator.default_tasks( config: config, default_tasks: app_cfg[:default_tasks] )

    @runner.process_testcase_filters(
      config: config,
      include: options[:test_case],
      exclude: options[:exclude_test_case],
      tasks: tasks,
      default_tasks: default_tasks
    )

    log_filepath = @runner.process_logging( options[:log], options[:logfile] )

    # Save references
    app_cfg[:project_config] = config
    app_cfg[:log_filepath] = log_filepath
    app_cfg[:include_test_case] = options[:test_case]
    app_cfg[:exclude_test_case] = options[:exclude_test_case]

    @runner.set_verbosity( options[:verbosity] )

    @runner.load_ceedling( 
      config: config,
      which: app_cfg[:which_ceedling],
      default_tasks: default_tasks
    )

    @runner.run_rake_tasks( tasks )
  end

end
