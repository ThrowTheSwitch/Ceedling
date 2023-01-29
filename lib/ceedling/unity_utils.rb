# The Unity utils class,
# Store functions to enable test execution of single test case under test file
# and additional warning definitions
class UnityUtils
  attr_reader :test_runner_disabled_replay, :arg_option_map
  attr_accessor :test_runner_args, :not_supported

  constructor :configurator

  def setup
    @test_runner_disabled_replay = "NOTICE: \n" \
     "The option[s]: %<opt>.s \ncannot be applied." \
     'To enable it, please add `:cmdline_args` under' \
     ' :test_runner option in your project.yml.'
    @test_runner_args = ''
    @not_supported = ''

    # Refering to Unity implementation of the parser implemented in the unit.c :
    #
    # case 'l': /* list tests */
    # case 'n': /* include tests with name including this string */
    # case 'f': /* an alias for -n */
    # case 'q': /* quiet */
    # case 'v': /* verbose */
    # case 'x': /* exclude tests with name including this string */
    @arg_option_map =
      {
        'test_case' => 'n',
        'list_test_cases' => 'l',
        'run_tests_verbose' => 'v',
        'exclude_test_case' => 'x'
      }
  end

  # Create test runner args which can be passed to executable test file as
  # filter to execute one test case from test file
  #
  # @param [String, #argument] argument passed after test file name
  #                            e.g.: ceedling test:<test_file>:<argument>
  # @param [String, #option] one of the supported by unity arguments.
  #                          At current moment only "test_case_name" to
  #                          run single test
  def additional_test_run_args(argument, option)
    # Confirm wherever cmdline_args is set to true
    # and parsing arguments under generated test runner in Unity is enabled
    # and passed argument is not nil

    return nil if argument.nil?

    raise TypeError, 'option expects an arg_option_map key' unless \
      option.is_a?(String)
    raise 'Unknown Unity argument option' unless \
      @arg_option_map.key?(option)

    @test_runner_args += " -#{@arg_option_map[option]} #{argument} "
  end

  # Return test case arguments
  #
  # @return [String] formatted arguments for test file
  def collect_test_runner_additional_args
    @test_runner_args
  end

  # Parse passed by user arguments
  def create_test_runner_additional_args
    if ENV['CEEDLING_INCLUDE_TEST_CASE_NAME']
      if @configurator.project_config_hash[:test_runner_cmdline_args]
        additional_test_run_args(ENV['CEEDLING_INCLUDE_TEST_CASE_NAME'],
                                 'test_case')
      else
        @not_supported = "\n\t--test_case"
      end
    end

    if ENV['CEEDLING_EXCLUDE_TEST_CASE_NAME']
      if @configurator.project_config_hash[:test_runner_cmdline_args]
        additional_test_run_args(ENV['CEEDLING_EXCLUDE_TEST_CASE_NAME'],
                                 'exclude_test_case')
      else
        @not_supported = "\n\t--exclude_test_case"
      end
    end
    print_warning_about_not_enabled_cmdline_args
  end

  # Return UNITY_USE_COMMAND_LINE_ARGS define required by Unity to
  # compile unity with enabled cmd line arguments
  #
  # @return [Array] - empty if cmdline_args is not set
  def self.update_defines_if_args_enables(in_hash)
    in_hash[:test_runner_cmdline_args] ? ['UNITY_USE_COMMAND_LINE_ARGS'] : []
  end

  # Print on output console warning about lack of support for single test run
  # if cmdline_args is not set to true in project.yml file, that
  def print_warning_about_not_enabled_cmdline_args
    puts(format(@test_runner_disabled_replay, opt: @not_supported)) unless @not_supported.empty?
  end
end
