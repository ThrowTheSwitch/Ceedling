# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Setupinator

  # Configurator steps that fill out the configuration from user configuration and defaults,
  # in the order they run:
  #  - Unity and CMock values that tie vendor tool configurations together
  #  - The Partials configuration reference for dependency-tracker meta
  #  - Test runner generation settings
  #  - Exceptions, enabled automagically by CMock settings
  #  - Environment variables again, before configuration that may reference them by inline
  #    Ruby string expansion
  #  - Paths, flags, and defines expanded, then paths standardized
  COMPLETION_STEPS = %i[populate_unity_config populate_cmock_config populate_partials_config populate_test_runner_generation_config
    populate_exceptions_config eval_environment_variables eval_paths eval_flags eval_defines standardize_paths].freeze

  # Configurator settings taken from the command line, each by its application
  # configuration key: test case filters, whether the requested tasks build tests or a
  # release (which decides what build/vendor needs), and forced test re-execution
  COMMAND_LINE_SETTINGS = { include_test_case: :include_test_case, exclude_test_case: :exclude_test_case,
    test_build_tasks: :test_build_tasks?, release_build_tasks: :release_build_tasks?, force_test_rerun: :force_test_rerun }.freeze

  # The application objects setup uses, taken from the object hash rather than a DIY
  # constructor, which validates aspects of setup
  COLLABORATORS = %i[configurator loginator reportinator plugin_manager plugin_reportinator test_runner_manager].freeze

  attr_reader :config_hash

  def setup
    @config_hash = {}
  end


  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    # TODO: When identifying information is added to constructor, insert it into `inspect()` string
    return self.class.name
  end


  # Injector method for setting Ceedling application object hash
  def ceedling=(value)
    # Capture application objects hash as instance variable
    @ceedling = value
    COLLABORATORS.each { |name| instance_variable_set( "@#{name}", value[name] ) }
  end


  # Load up all the constants and accessors our rake files, objects, & external scripts will need.
  # Each numbered step's order matters.
  def do_setup( app_cfg )
    @config_hash = app_cfg[:project_config]

    apply_command_line( app_cfg )                                      # 1.
    prepare_essential_configuration()                                  # 1.
    plugins_paths_hash = handle_base_configuration( app_cfg )          # 2.
    handle_plugins( plugins_paths_hash )                               # 3.
    assemble_defaults( plugins_paths_hash )                            # 4.
    complete_configuration( app_cfg )                                  # 5.
    validate_final_configuration()                                     # 6.

    # 7. Partially flatten config + build Configurator accessors and globals
    @configurator.build( app_cfg[:ceedling_lib_path], app_cfg[:logging_path], config_hash, :environment )

    load_plugins()                                                     # 8.
  end


### Private

private

  ##
  ## 1. Miscellaneous handling and essential configuration prep
  ##

  def apply_command_line(app_cfg)
    COMMAND_LINE_SETTINGS.each { |setting, key| @configurator.public_send( "#{setting}=", app_cfg[key] ) }

    # Verbosity handling
    @configurator.set_verbosity()

    # Logging configuration
    @loginator.set_logfile( app_cfg[:log_filepath] )
    @configurator.project_logging = @loginator.project_logging
  end

  def prepare_essential_configuration
    log_step( 'Validating configuration contains minimum required sections', heading: false )

    # Complain early about anything essential that's missing
    @configurator.validate_essential( config_hash )

    # Merge any needed runtime settings into user configuration
    @configurator.merge_ceedling_runtime_config( config_hash, CEEDLING_RUNTIME_CONFIG.deep_clone )

    return unless config_hash[:project][:use_partials]

    log_step( 'Processing Partials configuration', heading: false, verbosity: Verbosity::NORMAL )
    # Set configuration settings derived from enabling partials
    @configurator.set_partials_derived_config( config_hash )
  end

  ##
  ## 2. Handle basic configuration
  ##

  def handle_base_configuration(app_cfg)
    log_step( 'Base configuration handling', heading: false )

    # Evaluate environment vars before plugin configurations that might reference with inline Ruby string expansion
    @configurator.eval_environment_variables( config_hash )

    # Standardize paths and add to Ruby load paths
    return @configurator.prepare_plugins_load_paths( app_cfg[:ceedling_plugins_path], config_hash )
  end

  ##
  ## 3. Plugin Handling
  ##

  def handle_plugins(plugins_paths_hash)
    log_step( 'Plugin Handling' )

    @configurator.discover_plugins( plugins_paths_hash, config_hash )
    @configurator.merge_config_plugins( config_hash )
    @configurator.populate_plugins_config( plugins_paths_hash, config_hash )
  end

  ##
  ## 4. Collect and apply defaults to user configuration
  ##

  def assemble_defaults(plugins_paths_hash)
    log_step( 'Assembling Default Settings' )

    # Assemble defaults
    defaults_hash = DEFAULT_CEEDLING_PROJECT_CONFIG.deep_clone()
    @configurator.merge_tools_defaults( config_hash, defaults_hash )
    @configurator.populate_cmock_defaults( config_hash, defaults_hash )
    @configurator.merge_plugins_defaults( plugins_paths_hash, config_hash, defaults_hash )

    # Set any missing essential or plugin values in configuration with assembled default values
    @configurator.populate_with_defaults( config_hash, defaults_hash )
  end

  ##
  ## 5. Fill out / modify remaining configuration from user configuration + defaults
  ##

  def complete_configuration(app_cfg)
    log_step( 'Completing Project Configuration' )

    COMPLETION_STEPS.each { |step| @configurator.public_send( step, config_hash ) }
    complete_tools_and_runners( app_cfg )
  end

  def complete_tools_and_runners(app_cfg)
    # Fill out any missing tool config value
    @configurator.populate_tools_config( config_hash )

    # Probe whether the configured C preprocessor supports -fdirectives-only output.
    # Must run after tool configs are populated (executable name resolved) and before
    # build() flattens the config ➡️ the new key is picked up by accessor generation.
    log_step( 'Probing directives-only preprocessor support', heading: false )
    @configurator.resolve_directives_only_preprocessing( config_hash, @ceedling[:tool_executor] )

    # From any tool definition shortcuts:
    #  - Redefine executable if set
    #  - Add arguments from tool definition shortcuts if set
    @configurator.populate_tools_shortcuts( config_hash )

    # Configure test runner build & runtime options
    @test_runner_manager.configure_build_options( config_hash )
    @test_runner_manager.configure_runtime_options( app_cfg[:include_test_case], app_cfg[:exclude_test_case] )
  end

  ##
  ## 6. Validate configuration
  ##

  def validate_final_configuration
    log_step( 'Validating final project configuration', heading: false )

    @configurator.validate_final( config_hash )
  end

  ##
  ## 8. Final plugins handling
  ##

  def load_plugins
    # Detailed logging already happend for plugin processing
    log_step( 'Loading Plugins' )

    @configurator.insert_rake_plugins( @configurator.rake_plugins )

    # Merge in any environment variables that plugins specify after the main build
    @plugin_manager.load_programmatic_plugins( @configurator.programmatic_plugins, @ceedling ) do |env|
      # Evaluate environment vars that plugins may have added
      @configurator.eval_environment_variables( env )
      @configurator.build_supplement( config_hash, env )
    end

    # Inject dependencies for plugin needs
    @plugin_reportinator.set_system_objects( @ceedling )
  end

  # Neaten up a build step with progress message and some scope encapsulation
  def log_step(msg, heading: true, verbosity: Verbosity::OBNOXIOUS )
    @loginator.lazy( verbosity ) do
      decorated = @loginator.decorate( msg, LogLabels::CONSTRUCT )
      heading ? @reportinator.generate_heading( decorated ) : "\n" + @reportinator.generate_progress( decorated )
    end
  end


end
