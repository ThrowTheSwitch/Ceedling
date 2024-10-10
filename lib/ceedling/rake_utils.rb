# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class RakeUtils
  
  constructor :rake_wrapper

  def task_invoked?(task_regex)
    task_invoked = false
    @rake_wrapper.task_list.each do |task|
      if ((task.already_invoked) and (task.to_s =~ task_regex))
        task_invoked = true
        break
      end
    end
    return task_invoked
  end

end
