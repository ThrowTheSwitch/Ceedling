require 'ceedling/plugin'
require 'ceedling/constants'
require 'gcov_constants'

class Gcov < Plugin
  attr_reader :config

  def setup
    @result_list = []

    @config = {
      gcov_html_report_filter: GCOV_FILTER_EXCLUDE
    }

    @plugin_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    @coverage_template_all = @ceedling[:file_wrapper].read(File.join(@plugin_root, 'assets/template.erb'))
  end

  def generate_coverage_object_file(test, source, object)
    tool = TOOLS_TEST_COMPILER
    msg = nil

    # If a source file (not unity, mocks, etc.) is to be compiled use code coverage compiler
    if @ceedling[:configurator].collection_all_source.to_a.include?(source)
      tool = TOOLS_GCOV_COMPILER
      msg = "Compiling #{File.basename(source)} with coverage..."
    end

    @ceedling[:test_invoker].compile_test_component(
      tool:    tool,
      context: GCOV_SYM,
      test:    test,
      source:  source,
      object:  object,
      msg:     msg
      )
  end

  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]

    if (result_file =~ /#{GCOV_RESULTS_PATH}/) && !@result_list.include?(result_file)
      @result_list << arg_hash[:result_file]
    end
  end

  def post_build
    return unless @ceedling[:task_invoker].invoked?(/^#{GCOV_TASK_ROOT}/)

    # test results
    results = @ceedling[:plugin_reportinator].assemble_test_results(@result_list)
    hash = {
      header: GCOV_ROOT_NAME.upcase,
      results: results
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash) do
      message = ''
      message = 'Unit test failures.' if results[:counts][:failed] > 0
      message
    end

    report_per_file_coverage_results()
  end

  def summary
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist(GCOV_RESULTS_PATH, COLLECTION_ALL_TESTS)

    # test results
    # get test results for only those tests in our configuration and of those only tests with results on disk
    hash = {
      header: GCOV_ROOT_NAME.upcase,
      results: @ceedling[:plugin_reportinator].assemble_test_results(result_list, boom: false)
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash)
  end

  private ###################################

  def report_per_file_coverage_results()
    banner = @ceedling[:plugin_reportinator].generate_banner( "#{GCOV_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @ceedling[:streaminator].stdout_puts "\n" + banner

    # Iterate over each test run and its list of source files
    @ceedling[:test_invoker].each_test_with_sources do |test, sources|
      heading = @ceedling[:plugin_reportinator].generate_heading( test )
      @ceedling[:streaminator].stdout_puts(heading)

      sources = @ceedling[:project_config_manager].filter_internal_sources(sources)
      sources.each do |source|
        filename = File.basename(source)
        name     = filename.ext('')
        command  = @ceedling[:tool_executor].build_command_line(
                     TOOLS_GCOV_REPORT,
                     [], # No additional arguments
                     filename, # .c source file that should have been compiled with coverage
                     File.join(GCOV_BUILD_OUTPUT_PATH, test) # <build>/gcov/out/<test name> for coverage data files
                   )

        # Run the gcov tool and collect raw coverage report
        shell_results  = @ceedling[:tool_executor].exec(command[:line], command[:options])
        results        = shell_results[:output].strip

        # Skip to next loop iteration if no coverage results.
        # A source component may have been compiled with coverage but none of its code actually called in a test.
        # In this case, gcov does not produce an error, only blank results.
        if results.empty?
          @ceedling[:streaminator].stdout_puts("#{filename} : No functions called or code paths exercised by test\n")
          next
        end

        # If results include intended source, extract details from console
        if results =~ /(File\s+'#{Regexp.escape(source)}'.+$)/m
          # Reformat from first line as filename banner to each line labeled with the filename
          # Only extract the first four lines of the console report (to avoid spidering coverage reports through libs, etc.)
          report = Regexp.last_match(1).lines.to_a[1..4].map { |line| filename + ' | ' + line }.join('')
          @ceedling[:streaminator].stdout_puts(report + "\n")
        
        # Otherwise, no coverage results were found
        else
          msg = "ERROR: Could not find coverage results for #{source} component of #{test}"
          @ceedling[:streaminator].stderr_puts( msg, Verbosity::NORMAL )
        end
      end
    end
  end

end

# end blocks always executed following rake run
END {
  # cache our input configurations to use in comparison upon next execution
  @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash) if @ceedling[:task_invoker].invoked?(/^#{GCOV_TASK_ROOT}/)
}
