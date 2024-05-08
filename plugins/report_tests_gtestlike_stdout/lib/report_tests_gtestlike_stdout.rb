# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/defaults'

class ReportTestsGtestlikeStdout < Plugin

  # `Plugin` setup()
  def setup
    @result_list = []
    @mutex = Mutex.new

    # Fetch the test results template for this plugin
    template = @ceedling[:file_wrapper].read( File.join( @plugin_root_path, 'assets/template.erb' ) )

    # Set the report template
    @ceedling[:plugin_reportinator].register_test_results_template( template )
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
    return if not (@ceedling[:task_invoker].test_invoked?)

    results = @ceedling[:plugin_reportinator].assemble_test_results( @result_list )
    hash = {
      :header => TEST_SYM.upcase(),
      :results => results
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash)
  end

  # `Plugin` build step hook -- render a test results report on demand using results from a previous build
  def summary()
    # Build up the list of passing results from all tests
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist(
      PROJECT_TEST_RESULTS_PATH,
      COLLECTION_ALL_TESTS
    )

    hash = {
      :header => TEST_SYM.upcase(),
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
