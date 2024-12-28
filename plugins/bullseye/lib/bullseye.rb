# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/constants'
require 'ceedling/exceptions'

BULLSEYE_ROOT_NAME         = 'bullseye'
BULLSEYE_TASK_ROOT         = BULLSEYE_ROOT_NAME + ':'
BULLSEYE_SYM               = BULLSEYE_ROOT_NAME.to_sym

BULLSEYE_BUILD_PATH        = "#{PROJECT_BUILD_ROOT}/#{BULLSEYE_ROOT_NAME}"
BULLSEYE_BUILD_OUTPUT_PATH = "#{BULLSEYE_BUILD_PATH}/out"
BULLSEYE_RESULTS_PATH      = "#{BULLSEYE_BUILD_PATH}/results"
BULLSEYE_DEPENDENCIES_PATH = "#{BULLSEYE_BUILD_PATH}/dependencies"
BULLSEYE_ARTIFACTS_PATH    = "#{PROJECT_BUILD_ARTIFACTS_ROOT}/#{BULLSEYE_ROOT_NAME}"

BULLSEYE_IGNORE_SOURCES    = ['unity', 'cmock', 'cexception']


class Bullseye < Plugin

  def setup
    # TODO: Remove `raise` when Bullseye plugin has been updated for Ceedling >= 1.0.0
    raise CeedlingException.new( "The Bullseye plugin is disabled until it can be updated for this version of Ceedling" )
    @result_list = []
    @environment = [ {:covfile => File.join( BULLSEYE_ARTIFACTS_PATH, 'test.cov' )} ]
    @coverage_template_all = @ceedling[:file_wrapper].read( File.join( @plugin_root_path, 'assets/template.erb' ) )
  end

  def config
    {
      :project_test_build_output_path     => BULLSEYE_BUILD_OUTPUT_PATH,
      :project_test_build_output_c_path   => BULLSEYE_BUILD_OUTPUT_PATH,
      :project_test_results_path          => BULLSEYE_RESULTS_PATH,
      :project_test_dependencies_path     => BULLSEYE_DEPENDENCIES_PATH,
      :defines_test                       => DEFINES_TEST + ['CODE_COVERAGE'],
      :collection_defines_test_and_vendor => COLLECTION_DEFINES_TEST_AND_VENDOR + ['CODE_COVERAGE']
    }
  end

  def generate_coverage_object_file(source, object)
    arg_hash = {:tool => TOOLS_BULLSEYE_INSTRUMENTATION, :context => BULLSEYE_SYM, :source => source, :object => object}
    @ceedling[:plugin_manager].pre_compile_execute(arg_hash)

    @ceedling[:loginator].log("Compiling #{File.basename(source)} with coverage...")
    compile_command  = 
      @ceedling[:tool_executor].build_command_line(
        TOOLS_BULLSEYE_COMPILER,
        @ceedling[:flaginator].flag_down( OPERATION_COMPILE_SYM, BULLSEYE_SYM, source ),
        source,
        object,
        @ceedling[:file_path_utils].form_test_build_list_filepath( object ) )
    coverage_command = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_INSTRUMENTATION, [], compile_command[:line] )

    shell_result     = @ceedling[:tool_executor].exec( coverage_command[:line], coverage_command[:options] )
    
    arg_hash[:shell_result] = shell_result
    @ceedling[:plugin_manager].post_compile_execute(arg_hash)
  end

  def post_test_fixture_execute(arg_hash)
    result_file = arg_hash[:result_file]
  
    if ((result_file =~ /#{BULLSEYE_RESULTS_PATH}/) and (not @result_list.include?(result_file)))
      @result_list << arg_hash[:result_file]
    end
  end

  def post_build
    return if (not @ceedling[:task_invoker].invoked?(/^#{BULLSEYE_TASK_ROOT}/))

    # test results
    results = @ceedling[:plugin_reportinator].assemble_test_results(@result_list)
    hash = {
      :header => BULLSEYE_ROOT_NAME.upcase,
      :results => results
    }
    
    @ceedling[:plugin_reportinator].run_test_results_report(hash) do
      message = ''
      message = 'Unit test failures.' if (results[:counts][:failed] > 0)
      message
    end
    
    # coverage results
    return if (verify_coverage_file() == false)
    if (@ceedling[:task_invoker].invoked?(/^#{BULLSEYE_TASK_ROOT}(all|delta)/))
      command      = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_REPORT_COVSRC, [])
      shell_result = @ceedling[:tool_executor].exec( command )
      report_coverage_results_all(shell_result[:output])
    else
      report_per_function_coverage_results(@ceedling[:test_invoker].sources)
    end
  end

  def summary
    return if (verify_coverage_file() == false)
    result_list = @ceedling[:file_path_utils].form_pass_results_filelist( BULLSEYE_RESULTS_PATH, COLLECTION_ALL_TESTS )

    # test results
    # get test results for only those tests in our configuration and of those only tests with results on disk
    hash = {
      :header => BULLSEYE_ROOT_NAME.upcase,
      :results => @ceedling[:plugin_reportinator].assemble_test_results(result_list, {:boom => false})
    }

    @ceedling[:plugin_reportinator].run_test_results_report(hash)
    
    # coverage results
    command = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_REPORT_COVSRC)
    shell_result = @ceedling[:tool_executor].exec( command )
    report_coverage_results_all(shell_result[:output])
  end
  
  def enableBullseye(enable)
    if BULLSEYE_AUTO_LICENSE
      if (enable)
        args = ['push', 'on']
        @ceedling[:loginator].log("Enabling Bullseye")
      else
        args = ['pop']
        @ceedling[:loginator].log("Reverting Bullseye to previous state")
      end

      args.each do |arg| 
        command = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_BUILD_ENABLE_DISABLE, [], arg)
        shell_result = @ceedling[:tool_executor].exec( command )
      end

    end
  end
  
  private ###################################

  def report_coverage_results_all(coverage)
    results = {
      :header => BULLSEYE_ROOT_NAME.upcase,
      :coverage => {
        :functions => nil,
        :branches  => nil
      }
    }

    if (coverage =~ /^Total.*?=\s+([0-9]+)\%/)
      results[:coverage][:functions] = $1.to_i
    end
    
    if (coverage =~ /^Total.*=\s+([0-9]+)\%\s*$/)
      results[:coverage][:branches] = $1.to_i
    end

    @ceedling[:plugin_reportinator].run_report( @coverage_template_all, results )
  end

  def report_per_function_coverage_results(sources)
    banner = @ceedling[:plugin_reportinator].generate_banner( "#{BULLSEYE_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
    @ceedling[:loginator].log "\n" + banner

    coverage_sources = sources.clone
    coverage_sources.delete_if {|item| item =~ /#{CMOCK_MOCK_PREFIX}.+#{EXTENSION_SOURCE}$/}
    coverage_sources.delete_if {|item| item =~ /#{BULLSEYE_IGNORE_SOURCES.join('|')}#{EXTENSION_SOURCE}$/}

    coverage_sources.each do |source|
      command          = @ceedling[:tool_executor].build_command_line(TOOLS_BULLSEYE_REPORT_COVFN, [], source)
      shell_results    = @ceedling[:tool_executor].exec( command )
      coverage_results = shell_results[:output].deep_clone
      coverage_results.sub!(/.*\n.*\n/,'') # Remove the Bullseye tool banner
      if (coverage_results =~ /warning cov814: report is empty/)
        coverage_results = "#{source} contains no coverage data"
        @ceedling[:loginator].log(coverage_results, Verbosity::COMPLAIN)
      else
        coverage_results += "\n"
        @ceedling[:loginator].log(coverage_results)
      end
    end
  end

  def verify_coverage_file
    exist = @ceedling[:file_wrapper].exist?( ENVIRONMENT_COVFILE )

    if (!exist)
      banner = @ceedling[:plugin_reportinator].generate_banner( "#{BULLSEYE_ROOT_NAME.upcase}: CODE COVERAGE SUMMARY" )
      @ceedling[:loginator].log "\n" + banner + "\nNo coverage file.\n\n"
    end
    
    return exist
  end
  
end


# end blocks always executed following rake run
END {
  # cache our input configurations to use in comparison upon next execution
  if (@ceedling[:task_invoker].invoked?(/^#{BULLSEYE_TASK_ROOT}/))
    @ceedling[BULLSEYE_SYM].enableBullseye(false)
  end
}
