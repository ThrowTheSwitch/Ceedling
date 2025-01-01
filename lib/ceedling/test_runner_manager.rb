# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class TestRunnerManager

  def initialize()
    @test_case_incl = nil
    @test_case_excl = nil
    @test_runner_defines = []
  end

  def configure_build_options(config)
    cmdline_args = config[:test_runner][:cmdline_args]

    # Should never happen because of external config handling, but...
    return if cmdline_args.nil?

    @test_runner_defines << RUNNER_BUILD_CMDLINE_ARGS_DEFINE if cmdline_args
  end

  def configure_runtime_options(include_test_case, exclude_test_case)
    if !include_test_case.empty?
      @test_case_incl = "-f #{include_test_case}"
    end

    if !exclude_test_case.empty?
      @test_case_excl = "-x #{exclude_test_case}"
    end
  end

  # Return test case arguments (empty if not set)
  def collect_cmdline_args()
    return [ @test_case_incl, @test_case_excl ].compact()
  end

  # Return ['UNITY_USE_COMMAND_LINE_ARGS'] #define required by Unity to enable cmd line arguments
  def collect_defines()
    return @test_runner_defines
  end

end
