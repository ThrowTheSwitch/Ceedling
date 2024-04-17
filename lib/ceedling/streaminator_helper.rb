# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class StreaminatorHelper

  def extract_name(stream)
    name = case (stream.fileno)
      when 0 then '#<IO:$stdin>'
      when 1 then '#<IO:$stdout>'
      when 2 then '#<IO:$stderr>'
      else stream.inspect
    end
    
    return name
  end

end
