# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'hardmock/method_cleanout'
require 'hardmock/errors'

module Hardmock
  class Expector #:nodoc:
    include MethodCleanout

    def initialize(mock,mock_control,expectation_builder)
      @mock = mock
      @mock_control = mock_control
      @expectation_builder = expectation_builder
    end

    def method_missing(mname, *args, &block)
      expectation = @expectation_builder.build_expectation(
        :mock => @mock,
        :method => mname,
        :arguments => args,
        :block => block)

      @mock_control.add_expectation expectation
      expectation
    end
  end

end
