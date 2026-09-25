# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake'

include Rake::DSL if defined?(Rake::DSL)

class Rake::Task
  attr_reader :already_invoked
end

class RakeWrapper

  def [](task)
    return Rake::Task[task]
  end

  def task_list
    return Rake::Task.tasks
  end

end
