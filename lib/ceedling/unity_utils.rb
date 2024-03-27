# The Unity utils class,
# Store functions to enable test execution of single test case under test file
# and additional warning definitions
class UnityUtils

  constructor :configurator, :streaminator

  def setup
    @test_case_incl = ''
    @test_case_excl = ''
    @not_supported = ''

    # Refering to Unity implementation of the parser implemented in the unit.c :
    #
    # case 'l': /* list tests */
    # case 'f': /* filter tests with name including this string */
    # case 'q': /* quiet */
    # case 'v': /* verbose */
    # case 'x': /* exclude tests with name including this string */
    @arg_option_map =
      {
        'test_case' => 'f',
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
  #
  # @return String - empty if cmdline_args is not set
  #                  In other way properly formated command line for Unity
  def additional_test_run_args(argument, option)
    # Confirm wherever cmdline_args is set to true
    # and parsing arguments under generated test runner in Unity is enabled
    # and passed argument is not nil

    return nil if argument.nil?

    raise TypeError, 'option expects an arg_option_map key' unless \
      option.is_a?(String)
    raise 'Unknown Unity argument option' unless \
      @arg_option_map.key?(option)

    " -#{@arg_option_map[option]} #{argument} "
  end

  # Return test case arguments
  #
  # @return [String] formatted arguments for test file
  def collect_test_runner_additional_args
    "#{@test_case_incl} #{@test_case_excl}"
  end

  # Parse passed by user arguments
  def create_test_runner_additional_args
    if !@configurator.include_test_case.empty?
      if @configurator.project_config_hash[:test_runner_cmdline_args]
        @test_case_incl += additional_test_run_args(
          @configurator.include_test_case,
          'test_case')
      else
        @not_supported += "\n\t--test_case"
      end
    end

    if !@configurator.exclude_test_case.empty?
      if @configurator.project_config_hash[:test_runner_cmdline_args]
        @test_case_excl += additional_test_run_args(
          @configurator.exclude_test_case,
          'exclude_test_case')
      else
        @not_supported += "\n\t--exclude_test_case"
      end
    end

    print_warning_about_not_enabled_cmdline_args() unless @not_supported.empty?
  end

  # Return UNITY_USE_COMMAND_LINE_ARGS define required by Unity to
  # compile unity with enabled cmd line arguments
  #
  # @return [Array] - empty if cmdline_args is not set
  def grab_additional_defines_based_on_configuration()
    @configurator.project_config_hash[:test_runner_cmdline_args] ? ['UNITY_USE_COMMAND_LINE_ARGS'] : []
  end

  # Log warning about lack of support for single test run
  # if cmdline_args is not enabled in project configuration
  def print_warning_about_not_enabled_cmdline_args()
    msg = "WARNING: Option[s]: %<opt>.s cannot be used by test runner. " +
          "Enable :test_runner ↳ :cmdline_args in your project configuration."

    @streaminator.stderr_puts( format(msg, opt: @not_supported), Verbosity::COMPLAIN )
  end
end
