require 'test/unit/assertions'
require 'hardmock/errors'

module Hardmock
  class Trapper #:nodoc:
    include Hardmock::MethodCleanout

    def initialize(mock,mock_control,expectation_builder)
      @mock = mock
      @mock_control = mock_control
      @expectation_builder = expectation_builder
    end

    def method_missing(mname, *args)
      if block_given?
        raise ExpectationError.new("Don't pass blocks when using 'trap' (setting exepectations for '#{mname}')")
      end
      
      the_block = lambda { |target_block| target_block }
      expectation = @expectation_builder.build_expectation(
        :mock => @mock, 
        :method => mname, 
        :arguments => args, 
        :suppress_arguments_to_block => true,
        :block => the_block)

      @mock_control.add_expectation expectation
      expectation
    end
  end
end
