# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class RakeTaskInvoker

  constructor :rake_task_registry, :batchinator, :rake_utils, :rake_wrapper

  # Post-execution lookup: returns true if any registered test namespace was invoked.
  def test_build_invoked?
    namespaces = @rake_task_registry.namespaces_for_tag( RakeTaskRegistry::TAG_TEST )
    return false if namespaces.empty?
    pattern = /^(#{namespaces.map { |ns| Regexp.escape(ns) }.join('|')})(:|$)/
    @rake_utils.task_invoked?( pattern )
  end

  # Post-execution lookup: returns true if a `test` task was invoked.
  # Note: This can include tasks that, in turn, invoke test tasks.
  def test_task_invoked?
    @rake_utils.task_invoked?( /^test(:|$)/ )
  end

  # Post-execution lookup: returns true if any registered release namespace was invoked.
  def release_build_invoked?
    namespaces = @rake_task_registry.namespaces_for_tag( RakeTaskRegistry::TAG_RELEASE )
    return false if namespaces.empty?
    pattern = /^(#{namespaces.map { |ns| Regexp.escape(ns) }.join('|')})(:|$)/
    @rake_utils.task_invoked?( pattern )
  end

  # Post-execution lookup: returns true if the matching the given regex was invoked.
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
