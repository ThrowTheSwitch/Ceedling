
module Hardmock
  module Utils #:nodoc:
    def format_method_call_string(mock,mname,args)
      arg_string = args.map { |a| a.inspect }.join(', ')
      call_text = "#{mock._name}.#{mname}(#{arg_string})"
    end
  end
end
