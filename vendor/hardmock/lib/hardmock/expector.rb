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
