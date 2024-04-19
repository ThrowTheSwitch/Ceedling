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
    # Installation location determined from the location of this file
    ceedling_root_path = File.expand_path( File.join( File.dirname( __FILE__ ), '..' ) )

    # Create internal hash of needed values
    @app_cfg = {
      # Base path of any Ceedling installation
      :ceedling_root_path => '',

      # Ceedling installation base path + /lib
      :ceedling_lib_base_path => '',

      # Ceedling installation base path + /lib/ceedling
      :ceedling_lib_path => '',

      # Ceedling installation base path + /vendor
      :ceedling_vendor_path => '',

      # Ceedling installation base path + /examples
      :ceedling_examples_path => '',

      # Blank initial value for completeness
      :project_config => {},

      # Default, blank value
      :log_filepath => '',

      # Only specified in project config (no command line or environment variable)
      :default_tasks => ['test:all'],

      # Default, blank test case filters
      :include_test_case => '',
      :exclude_test_case => '',

      # Default to no duration logging for setup & build ops in Rake context
      :stopwatch => false,

      # Default to `exit(1)` upon failing test cases
      :tests_graceful_fail => false,

      # Get terminal width in columns
      :terminal_width => (IO.console.winsize)[1],
    }

    set_paths( ceedling_root_path )
  end 

  def set_project_config(config)
    @app_cfg[:project_config] = config
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

  def set_stopwatch(enable)
    @app_cfg[:stopwatch] = enable
  end

  def set_tests_graceful_fail(enable)
    @app_cfg[:tests_graceful_fail] = enable
  end

  def set_paths(root_path)
    lib_base_path = File.join( root_path, 'lib' )

    @app_cfg[:ceedling_root_path]     = root_path
    @app_cfg[:ceedling_lib_base_path] = lib_base_path
    @app_cfg[:ceedling_lib_path]      = File.join( lib_base_path, 'ceedling' )
    @app_cfg[:ceedling_vendor_path]   = File.join( root_path, 'vendor' )
    @app_cfg[:ceedling_examples_path] = File.join( root_path, 'examples' )
  end

  # External accessor to preserve hash-like read accesses
  def [](key)
    return @app_cfg[key]
  end

end
