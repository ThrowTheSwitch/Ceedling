# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================



module Hardmock #:nodoc:
  module MethodCleanout #:nodoc:
    SACRED_METHODS = %w{
      __id__
      __send__
      equal?
      object_id
      send
      nil?
      class
      kind_of?
      respond_to?
      inspect
      method
      to_s
      instance_variables
      instance_eval
      ==
      hm_metaclass
      hm_meta_eval
      hm_meta_def
    }

    def self.included(base) #:nodoc:
      base.class_eval do
        instance_methods.each do |m| 
          undef_method m unless SACRED_METHODS.include?(m.to_s)
        end
      end
    end
  end
end
