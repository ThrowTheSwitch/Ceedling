# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/defaults'

class ReportTestsIdeStdout < Plugin

  # `Plugin` setup()
  def setup
    @result_list = []
    @mutex = Mutex.new

    # Set the report template (which happens to be the Ceedling default)
    @ceedling[:plugin_reportinator].register_test_results_template(
      DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE
      )
  end

  # `Plugin` build step hook -- collect result file paths after each test fixture execution
  def post_test_fixture_execute(arg_hash)
    # Thread-safe manipulation since test fixtures can be run in child processes
    # spawned within multiple test execution threads.
    @mutex.synchronize do
      @result_list << arg_hash[:result_file]
    end
  end

  # `Plugin` build step hook -- render a report immediately upon build completion (that invoked tests)
  def post_build()
    # Ensure a test task was invoked as part of the build
    return if (not @ceedling[:task_invoker].test_invoked?)

    results = @ceedling[:plugin_reportinator].assemble_test_results( @result_list )
    hash = {
      :header => '',
      :results => results
    }

    @ceedling[:plugin_reportinator].run_test_results_report( hash ) do
      message = ''
      message = 'Unit test failures.' if (hash[:results][:counts][:failed] > 0)
      message
    end
  end

  # `Plugin` build step hook -- render a test results report on demand using results from a previous build
  def summary()
    # Build up the list of passing results from all tests
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist(
      PROJECT_TEST_RESULTS_PATH,
      COLLECTION_ALL_TESTS
    )

    hash = {
      :header => '',
      # Collect all existing test results (success or failing) in the filesystem,
      # limited to our test collection
      :results => @ceedling[:plugin_reportinator].assemble_test_results(
        result_list,
        {:boom => false}
      )
    }

    @ceedling[:plugin_reportinator].run_test_results_report( hash )
  end

end
