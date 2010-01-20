require 'hardmock/utils'

module Hardmock
  class MockControl #:nodoc:
    include Utils
    attr_accessor :name

    def initialize
      clear_expectations
    end

    def happy?
      @expectations.empty?
    end

    def disappointed?
      @disappointed
    end

    def add_expectation(expectation)
#      puts "MockControl #{self.object_id.to_s(16)} adding expectation: #{expectation}"
      @expectations << expectation
    end

    def apply_method_call(mock,mname,args,block)
      # Are we even expecting any sort of call?
      if happy?
        @disappointed = true
        raise ExpectationError.new("Surprise call to #{format_method_call_string(mock,mname,args)}")
      end

      begin
        @expectations.shift.apply_method_call(mock,mname,args,block)
      rescue Exception => ouch
        @disappointed = true
        raise ouch
      end
    end

    def verify
#      puts "MockControl #{self.object_id.to_s(16)} verify: happy? #{happy?}"
      @disappointed = !happy?
      raise VerifyError.new("Unmet expectations", @expectations) unless happy?
    end

    def clear_expectations
      @expectations = []
      @disappointed = false
    end

  end

end
