# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# The Unity utils class,
# Store functions to enable test execution of single test case under test file
# and additional warning definitions
class UnityUtils

  constructor :configurator

  def setup
    @test_case_incl = ''
    @test_case_excl = ''
    @test_runner_defines = []

    # Refering to Unity implementation of the parser implemented in the unit.c :
    #
    # case 'l': /* list tests */
    # case 'f': /* filter tests with name including this string */
    # case 'q': /* quiet */
    # case 'v': /* verbose */
    # case 'x': /* exclude tests with name including this string */
    @arg_option_map =
      {
        :test_case         => 'f',
        :list_test_cases   => 'l',
        :run_tests_verbose => 'v',
        :exclude_test_case => 'x'
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

    if !@arg_option_map.key?(option)
      keys = @arg_option_map.keys.map{|key| ':' + key.to_s}.join(', ')
      error = "option argument must be a known key {#{keys}}"
      raise TypeError.new( error )
    end

    return " -#{@arg_option_map[option]} #{argument}"
  end

  # Return test case arguments
  #
  # @return [String] formatted arguments for test file
  def collect_test_runner_additional_args
    "#{@test_case_incl} #{@test_case_excl}"
  end

  # Parse passed by user arguments
  def process_test_runner_build_options()
    # Blow up immediately if things aren't right
    return if !test_runner_cmdline_args_configured?()

    @test_runner_defines << 'UNITY_USE_COMMAND_LINE_ARGS'

    if !@configurator.include_test_case.nil? && !@configurator.include_test_case.empty?
      @test_case_incl += additional_test_run_args( @configurator.include_test_case, :test_case )
    end

    if !@configurator.exclude_test_case.nil? && !@configurator.exclude_test_case.empty?
      @test_case_excl += additional_test_run_args( @configurator.exclude_test_case, :exclude_test_case )
    end
  end

  # Return UNITY_USE_COMMAND_LINE_ARGS define required by Unity to compile unity with enabled cmd line arguments
  #
  # @return [Array] - empty if cmdline_args is not set
  def grab_additional_defines_based_on_configuration()
    return @test_runner_defines
  end

  ### Private ###

  private

  # Raise exception if lacking support for test case matching
  def test_runner_cmdline_args_configured?()
    # Command line arguments configured
    cmdline_args = @configurator.test_runner_cmdline_args

    # Test case filters in use
    test_case_filters = (!@configurator.include_test_case.nil? && !@configurator.include_test_case.empty?) || 
                        (!@configurator.exclude_test_case.nil? && !@configurator.exclude_test_case.empty?)

    # Test case filters are in use but test runner command line arguments are not enabled
    if test_case_filters and !cmdline_args
      # Blow up if filters are in use but test runner command line arguments are not enabled
      msg = 'Unity test case filters cannot be used as configured. ' +
            'Enable :test_runner -> :cmdline_args in your project configuration.'

      raise CeedlingException.new( msg )
    end

    return cmdline_args
  end
end
