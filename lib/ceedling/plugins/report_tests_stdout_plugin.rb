# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugins/plugin'
require 'ceedling/defaults'

# Base class for stdout test-results reporting plugins.
# Subclasses need only override the private `load_template` method to supply
# a different ERB template string. All hook logic lives here.
class ReportTestsStdoutPlugin < Plugin

  # `Plugin` setup()
  def setup
    @result_list = []
    @mutex = Mutex.new

    # References
    @configurator        = @ceedling[:configurator]
    @plugin_reportinator = @ceedling[:plugin_reportinator]
    @file_path_utils     = @ceedling[:file_path_utils]
    @rake_task_invoker   = @ceedling[:rake_task_invoker]

    # Set the report template (subclass supplies via load_template)
    @plugin_reportinator.register_test_results_template( load_template() )
  end

  # `Plugin` build step hook -- collect result file paths after each test fixture execution
  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]

    # Thread-safe manipulation since test fixtures can be run in child processes
    # spawned within multiple test execution threads.
    @mutex.synchronize do
      if (result_file =~ /#{PROJECT_TEST_RESULTS_PATH}/) && !@result_list.include?(result_file)
        @result_list << arg_hash[:result_file]
      end
    end
  end

  # `Plugin` build step hook -- render a report immediately upon build completion (that invoked tests)
  def post_build(_timestamp_s)
    # Ensure a test task was invoked as part of the build
    return if not @rake_task_invoker.test_task_invoked?

    return if @configurator.plugins_display_raw_test_results

    results = @plugin_reportinator.assemble_test_results( @result_list )
    hash = { :context => TEST_SYM, :results => results }
    verbosity = (results[:counts][:failed] > 0) ? Verbosity::ERRORS : Verbosity::NORMAL

    # Print unit test suite results
    @plugin_reportinator.run_test_results_report( hash, verbosity )
  end

  # `Plugin` build step hook -- render a test results report on demand using results from a previous build
  def summary
    return if @configurator.plugins_display_raw_test_results

    # Build up the list of passing results from all tests
    result_list = @file_path_utils.form_pass_results_filelist(
      PROJECT_TEST_RESULTS_PATH,
      COLLECTION_ALL_TESTS
    )

    hash = {
      :context => TEST_SYM,
      # Collect all existing test results (success or failing) in the filesystem,
      # limited to our test collection
      :results => @plugin_reportinator.assemble_test_results( result_list, {:boom => false} )
    }

    @plugin_reportinator.run_test_results_report( hash )
  end

  private

  # Returns the ERB template string used for test results reports.
  # Default: reads assets/template.erb from the plugin's own root path.
  # Override in a subclass to supply a different template string.
  def load_template
    return @ceedling[:file_wrapper].read( File.join( @plugin_root_path, 'assets/template.erb' ) )
  end

end
