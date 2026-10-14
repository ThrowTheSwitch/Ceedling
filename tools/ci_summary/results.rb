# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# One CI leg's RSpec results, as the CI summary counts them.
#
# Each test leg uploads its suites' RSpec JSON in an artifact named
# `ci-results-<runner OS>-ruby-<version>`, and that name is the only record of which
# leg produced it.
module CiSummary
  module Results

    LEG_ARTIFACT = /\Aci-results-(?<os>.+)-ruby-(?<ruby>[\d.]+)\z/

    module_function

    # Examples, failures, and pending from an RSpec JSON summary. An error outside any
    # example, such as a spec file that fails to load, fails the suite like a failure.
    def counts(rspec)
      summary = rspec['summary']

      return {
        'examples' => summary['example_count'],
        'failures' => summary['failure_count'] + summary['errors_outside_of_examples_count'].to_i,
        'pending'  => summary['pending_count']
      }
    end

    # `Linux 3.3` from `ci-results-Linux-ruby-3.3`, or nil for any other artifact.
    def leg_name(artifact_name)
      match = LEG_ARTIFACT.match( artifact_name )
      return match.nil? ? nil : "#{match[:os]} #{match[:ruby]}"
    end

  end
end
