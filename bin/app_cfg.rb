# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require "io/console"

# Create our global application configuration option set
# This approach bridges clean Ruby and Rake

class CeedlingAppConfig

  def initialize()
    # Default installation location determined from the location of this file
    ceedling_root_path = File.join( File.dirname( __FILE__ ), '..' )

    # Create internal hash of needed values
    @app_cfg = {
      # Base path of any Ceedling installation
      :ceedling_root_path => '',

      # Ceedling installation base path + /lib
      :ceedling_lib_base_path => '',

      # Ceedling installation base path + /lib/ceedling
      :ceedling_lib_path => '',

      # Ceedling installation base path + /plugins
      :ceedling_plugins_path => '',

      # Ceedling installation base path + /vendor
      :ceedling_vendor_path => '',

      # Ceedling installation base path + /examples
      :ceedling_examples_path => '',

      # Ceedling lib path + lib/ceedling/rakefile.rb
      :ceedling_rakefile_filepath => '',

      # Blank initial value for completeness
      :project_config => {},

      # Default path (in build directory) to hold logs
      :logging_path => '',

      # If logging enabled, the filepath for Ceedling's log (may be explicitly set to be outside :logging_path)
      :log_filepath => '',

      # Only specified in project config (no command line or environment variable)
      :default_tasks => ['test:all'],

      # Default, blank test case filters
      :include_test_case => '',
      :exclude_test_case => '',

      # Default to task categry other than build/plugin tasks
      :build_tasks? => false,

      # Default to `exit(1)` upon failing test cases
      :tests_graceful_fail? => false,

      # Set terminal width (in columns) to a default
      :terminal_width => 120,
    }

    set_paths( ceedling_root_path )

    # Try to query terminal width (not always available on all platforms)
    begin
      @app_cfg[:terminal_width] = (IO.console.winsize)[1]
    rescue
      # Do nothing; allow value already set to stand as default
    end
  end 

  def set_project_config(config)
    @app_cfg[:project_config] = config
  end

  def set_logging_path(path)
    @app_cfg[:logging_path] = path
  end

  def set_log_filepath(filepath)
    @app_cfg[:log_filepath] = filepath
  end

  def set_include_test_case(matcher)
    @app_cfg[:include_test_case] = matcher
  end

  def set_exclude_test_case(matcher)
    @app_cfg[:exclude_test_case] = matcher
  end

  def set_build_tasks(enable)
    @app_cfg[:build_tasks?] = enable
  end

  def set_tests_graceful_fail(enable)
    @app_cfg[:tests_graceful_fail?] = enable
  end

  def set_paths(root_path)
    _root_path = File.expand_path( root_path )
    lib_base_path = File.join( _root_path, 'lib' )
    lib_path = File.join( lib_base_path, 'ceedling' )

    @app_cfg[:ceedling_root_path]     = _root_path
    @app_cfg[:ceedling_lib_base_path] = lib_base_path
    @app_cfg[:ceedling_lib_path]      = lib_path
    @app_cfg[:ceedling_vendor_path]   = File.join( _root_path, 'vendor' )
    @app_cfg[:ceedling_plugins_path]  = File.join( _root_path, 'plugins' )
    @app_cfg[:ceedling_examples_path] = File.join( _root_path, 'examples' )

    @app_cfg[:ceedling_rakefile_filepath] = File.join( lib_path, 'rakefile.rb' )
  end

  def build_tasks?()
    return @app_cfg[:build_tasks?]
  end

  def tests_graceful_fail?()
    return @app_cfg[:tests_graceful_fail?]
  end

  # External accessor to preserve hash-like read accesses
  def [](key)
    return @app_cfg[key]
  end

end
