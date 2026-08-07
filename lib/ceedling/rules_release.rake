# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

RELEASE_COMPILE_TASK_ROOT  = RELEASE_TASK_ROOT + 'compile:'  unless defined?(RELEASE_COMPILE_TASK_ROOT)
RELEASE_ASSEMBLE_TASK_ROOT = RELEASE_TASK_ROOT + 'assemble:' unless defined?(RELEASE_ASSEMBLE_TASK_ROOT)

# A single `namespace RELEASE_SYM do` level, not one nested inside another per
# rule -- each rule's own pattern already fully qualifies its required
# "release:compile:"/"release:assemble:" prefix (Rake matches a rule's regex
# against the literal invoked task name regardless of how deeply its `rule()`
# call is textually nested, so an inner `namespace :compile do` here would be
# purely decorative), and RakeTaskRegistry's marker scan resolves a task's
# semantic tags from its *nearest* enclosing namespace -- nesting one more
# level than necessary would make it resolve "compile"/"assemble" rather than
# "release" itself.
namespace RELEASE_SYM do
  # Use rules to increase efficiency for large projects (instead of iterating through all sources and creating defined tasks)

  # Unadvertised Rake task to execute source file compilation in isolation
  rule(/^#{RELEASE_COMPILE_TASK_ROOT}\S+(#{Regexp.escape(EXTENSION_SOURCE)}|#{Regexp.escape(EXTENSION_CORE_SOURCE)})$/ => [ # compile task names by regex
      proc do |task_name|
        source = task_name.sub(/#{RELEASE_COMPILE_TASK_ROOT}/, '')
        @ceedling[:file_finder].find_source_file(source)
      end
  ]) do |compile|
    @ceedling[:rake_wrapper][:prepare].invoke
    @ceedling[:release_invoker].setup_and_invoke( files: [compile.source] )
  end

  # Unadvertised Rake task to execute source file assembly in isolation
  if (RELEASE_BUILD_USE_ASSEMBLY)
  rule(/^#{RELEASE_ASSEMBLE_TASK_ROOT}\S+#{Regexp.escape(EXTENSION_ASSEMBLY)}$/ => [ # assemble task names by regex
      proc do |task_name|
        source = task_name.sub(/#{RELEASE_ASSEMBLE_TASK_ROOT}/, '')
        @ceedling[:file_finder].find_assembly_file(source)
      end
  ]) do |assemble|
    @ceedling[:rake_wrapper][:prepare].invoke
    @ceedling[:release_invoker].setup_and_invoke( files: [assemble.source] )
  end
  end

end
