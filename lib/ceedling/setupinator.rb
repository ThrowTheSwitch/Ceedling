# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Setupinator

  attr_reader :config_hash

  def setup
    @config_hash = {}
  end


  # Override to prevent exception handling from walking & stringifying the object variables.
  # Object variables are gigantic and produce a flood of output.
  def inspect
    # TODO: When identifying information is added to constructor, insert it into `inspect()` string
    return this.class.name
  end


  # Injector method for setting Ceedling application object hash
  def ceedling=(value)
    # Capture application objects hash as instance variable
    @ceedling = value

    # Get our dependencies from object hash rather than DIY constructor
    # This is a shortcut / validates aspects of our setup
    @configurator         = value[:configurator]
    @loginator            = value[:loginator]
    @reportinator         = value[:reportinator]
    @plugin_manager       = value[:plugin_manager]
    @plugin_reportinator  = value[:plugin_reportinator]
    @test_runner_manager  = value[:test_runner_manager]
  end


  # Load up all the constants and accessors our rake files, objects, & external scripts will need.
  def do_setup( app_cfg )
    @config_hash = app_cfg[:project_config]

    ##
    ## 1. Miscellaneous handling and essential configuration prep
    ##

    # Set special purpose test case filters (from command line)
    @configurator.include_test_case = app_cfg[:include_test_case]
    @configurator.exclude_test_case = app_cfg[:exclude_test_case]

    # Verbosity handling
    @configurator.set_verbosity( config_hash )

    # Logging configuration
    @loginator.set_logfile( app_cfg[:log_filepath] )
    @configurator.project_logging = @loginator.project_logging

    log_step( 'Validating configuration contains minimum required sections', heading:false )

    # Complain early about anything essential that's missing
    @configurator.validate_essential( config_hash )

    # Merge any needed runtime settings into user configuration
    @configurator.merge_ceedling_runtime_config( config_hash, CEEDLING_RUNTIME_CONFIG.deep_clone )

    ##
    ## 2. Handle basic configuration
    ##

    log_step( 'Project Configuration Handling' )

    # Evaluate environment vars before plugin configurations that might reference with inline Ruby string expansion
    @configurator.eval_environment_variables( config_hash )

    # Standardize paths and add to Ruby load paths
    plugins_paths_hash = @configurator.prepare_plugins_load_paths( app_cfg[:ceedling_plugins_path], config_hash )

    # Populate Unity configuration with values to tie vendor tool configurations together
    @configurator.populate_unity_config( config_hash )

    # Populate CMock configuration with values to tie vendor tool configurations together
    @configurator.populate_cmock_config( config_hash )

    ##
    ## 3. Plugin Handling
    ##

    log_step( 'Plugin Handling' )

    # Plugin handling
    @configurator.discover_plugins( plugins_paths_hash, config_hash )
    @configurator.merge_config_plugins( config_hash )
    @configurator.populate_plugins_config( plugins_paths_hash, config_hash )

    ##
    ## 4. Collect and apply defaults to user configuration
    ##

    log_step( 'Assembling Default Settings' )

    # Assemble defaults
    defaults_hash = DEFAULT_CEEDLING_PROJECT_CONFIG.deep_clone()
    @configurator.merge_tools_defaults( config_hash, defaults_hash )
    @configurator.populate_cmock_defaults( config_hash, defaults_hash )
    @configurator.merge_plugins_defaults( plugins_paths_hash, config_hash, defaults_hash )

    # Set any missing essential or plugin values in configuration with assembled default values
    @configurator.populate_with_defaults( config_hash, defaults_hash )

    ##
    ## 5. Fill out / modify remaining configuration from user configuration + defaults
    ##

    log_step( 'Completing Project Configuration' )

    # Configure test runner generation
    @configurator.populate_test_runner_generation_config( config_hash )

    @loginator.log( "Unity configuration >> #{config_hash[:unity]}", Verbosity::DEBUG )
    @loginator.log( "CMock configuration >> #{config_hash[:cmock]}", Verbosity::DEBUG )
    @loginator.log( "Test Runner configuration >> #{config_hash[:test_runner]}", Verbosity::DEBUG )
    @loginator.log( "CException configuration >> #{config_hash[:cexception]}", Verbosity::DEBUG )

    # Automagically enable use of exceptions based on CMock settings
    @configurator.populate_exceptions_config( config_hash )

    # Evaluate environment vars again before subsequent configurations that might reference with inline Ruby string expansion
    @configurator.eval_environment_variables( config_hash )

    # Standardize values and expand inline Ruby string substitutions
    @configurator.eval_paths( config_hash )
    @configurator.eval_flags( config_hash )
    @configurator.eval_defines( config_hash )
    @configurator.standardize_paths( config_hash )

    # Fill out any missing tool config value
    @configurator.populate_tools_config( config_hash )

    # From any tool definition shortcuts:
    #  - Redefine executable if set
    #  - Add arguments from tool definition shortcuts if set
    @configurator.populate_tools_shortcuts( config_hash )

    # Configure test runner build & runtime options
    @test_runner_manager.configure_build_options( config_hash )
    @test_runner_manager.configure_runtime_options( app_cfg[:include_test_case], app_cfg[:exclude_test_case] )

    ##
    ## 6. Validate configuration
    ##

    log_step( 'Validating final project configuration', heading:false )

    @configurator.validate_final( config_hash, app_cfg )

    ##
    ## 7. Flatten configuration + process it into globals and accessors
    ##

    # Skip logging this step as the end user doesn't care about this internal preparation

    # Partially flatten config + build Configurator accessors and globals
    @configurator.build( app_cfg[:ceedling_lib_path], app_cfg[:logging_path], config_hash, :environment )

    ##
    ## 8. Final plugins handling
    ##

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

  def reset_defaults(config_hash)
    @configurator.reset_defaults( config_hash )
  end

### Private

private

  # Neaten up a build step with progress message and some scope encapsulation
  def log_step(msg, heading:true)
    if heading
      msg = @reportinator.generate_heading( @loginator.decorate( msg, LogLabels::CONSTRUCT ) )
    else # Progress message
      msg = "\n" + @reportinator.generate_progress( @loginator.decorate( msg, LogLabels::CONSTRUCT ) )
    end

    @loginator.log( msg, Verbosity::OBNOXIOUS )
  end


end
