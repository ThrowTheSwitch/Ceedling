# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

class TestRunnerManager

  constructor :configurator

  def setup
    @test_case_incl = nil
    @test_case_excl = nil
    @test_runner_defines = []
  end

  # Return test case arguments (empty if not set)
  def collect_cmdline_args()
    return [ @test_case_incl, @test_case_excl ].compact()
  end

  def validate_and_configure_options()
    # Blow up immediately if things aren't right
    return if !validated_and_configured?()

    @test_runner_defines << 'UNITY_USE_COMMAND_LINE_ARGS'

    if !@configurator.include_test_case.empty?
      @test_case_incl = "-f #{@configurator.include_test_case}"
    end

    if !@configurator.exclude_test_case.empty?
      @test_case_excl = "-x #{@configurator.exclude_test_case}"
    end
  end

  # Return ['UNITY_USE_COMMAND_LINE_ARGS'] #define required by Unity to enable cmd line arguments
  def collect_defines()
    return @test_runner_defines
  end

  ### Private ###

  private

  # Raise exception if lacking support for test case matching
  def validated_and_configured?()
    # Command line arguments configured
    cmdline_args = @configurator.test_runner_cmdline_args

    # Test case filters in use
    test_case_filters = (!@configurator.include_test_case.nil? && !@configurator.include_test_case.empty?) || 
                        (!@configurator.exclude_test_case.nil? && !@configurator.exclude_test_case.empty?)

    # Test case filters are in use but test runner command line arguments are not enabled
    if test_case_filters and !cmdline_args
      # Blow up if filters are in use but test runner command line arguments are not enabled
      msg = 'Unity test case filters cannot be used as configured. ' +
            'Enable :test_runner ↳ :cmdline_args in your project configuration.'

      raise CeedlingException.new( msg )
    end

    return cmdline_args
  end
end
