# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class TaskInvoker

  attr_accessor :first_run

  constructor :dependinator, :build_batchinator, :rake_utils, :rake_wrapper

  def setup
    @test_regexs = [/^#{TEST_ROOT_NAME}:/]
    @release_regexs = [/^#{RELEASE_ROOT_NAME}(:|$)/]
    @first_run = true

    # Alias for brevity
    @batchinator = @build_batchinator
  end
  
  def add_test_task_regex(regex)
    @test_regexs << regex
  end

  def add_release_task_regex(regex)
    @release_regexs << regex
  end
  
  def test_invoked?
    invoked = false
    
    @test_regexs.each do |regex|
      invoked = true if (@rake_utils.task_invoked?(regex))
      break if invoked
    end
    
    return invoked
  end
  
  def release_invoked?
    invoked = false
    
    @release_regexs.each do |regex|
      invoked = true if (@rake_utils.task_invoked?(regex))
      break if invoked
    end
    
    return invoked
  end

  def invoked?(regex)
    return @rake_utils.task_invoked?(regex)
  end

  def invoke_test_objects(test:, objects:)
    @batchinator.exec(workload: :compile, things: objects) do |object|
      # Encode context with concatenated compilation target: <test name>+<object file>
      @rake_wrapper["#{test}+#{object}"].invoke
    end
  end

  def invoke_release_objects(objects)
    @batchinator.exec(workload: :compile, things: objects) do |object|
      @rake_wrapper[object].invoke
    end
  end
  
end
