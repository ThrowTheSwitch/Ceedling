# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'hardmock/expectation'

module Hardmock
  class ExpectationBuilder #:nodoc:
    def build_expectation(options)
      Expectation.new(options)
    end
  end
end
