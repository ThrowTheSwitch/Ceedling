# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================



module Hardmock
  module Utils #:nodoc:
    def format_method_call_string(mock,mname,args)
      arg_string = args.map { |a| a.inspect }.join(', ')
      call_text = "#{mock._name}.#{mname}(#{arg_string})"
    end
  end
end
