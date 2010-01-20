require 'test/unit/assertions'

module Test::Unit #:nodoc:#
  module Assertions #:nodoc:#
    # A better 'assert_raise'.  +patterns+ can be one or more Regexps, or a literal String that 
    # must match the entire error message.
    def assert_error(err_type,*patterns,&block)
      assert_not_nil block, "assert_error requires a block"
      assert((err_type and err_type.kind_of?(Class)), "First argument to assert_error has to be an error type")
      err = assert_raise(err_type) do
        block.call
      end
      patterns.each do |pattern|
        case pattern
        when Regexp
          assert_match(pattern, err.message) 
        else
          assert_equal pattern, err.message
        end
      end
    end
  end
end
