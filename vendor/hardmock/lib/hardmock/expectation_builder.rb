require 'hardmock/expectation'

module Hardmock
  class ExpectationBuilder #:nodoc:
    def build_expectation(options)
      Expectation.new(options)
    end
  end
end
