
# Create our global application configuration option set
# This approach bridges clean Ruby and Rake
def get_app_cfg()
  app_cfg = {
    # Blank initial value for completeness
    :project_config => {},

    # Default, blank value
    :log_filepath => '',

    # Only specified in project configuration (no command line or environment variable)
    :default_tasks => ['test:all'],

    # Basic check from working directory
    :which_ceedling => (Dir.exist?( 'vendor/ceedling' ) ? 'vendor/ceedling' : 'gem'),

    # Default, blank test case filters
    :include_test_case => '',
    :exclude_test_case => ''
  }

  return app_cfg
end
