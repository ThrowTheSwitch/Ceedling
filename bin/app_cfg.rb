
# Create our global application configuration option set
# This approach bridges clean Ruby and Rake
def get_app_cfg()
  app_cfg = {
    # Blank initial value for completeness
    :project_config => {},

    # Default, blank value
    :log_filepath => '',

    # Only specified in project config (no command line or environment variable)
    :default_tasks => ['test:all'],

    # Basic check from working directory
    # If vendor/ceedling exists, default to running vendored Ceedling
    :which_ceedling => (Dir.exist?( 'vendor/ceedling' ) ? 'vendor/ceedling' : 'gem'),

    # Default, blank test case filters
    :include_test_case => '',
    :exclude_test_case => '',

    # Default to no duration logging for setup & build ops in Rake context
    :stopwatch => false,

    # Default to `exit(1)` upon failing test cases
    :tests_graceful_fail => false,
  }

  return app_cfg
end
