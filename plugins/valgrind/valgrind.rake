# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

##
## This Rakefile plugin is effectively just aliases of `valgrind:` tasks to `test:` tasks.
## Valgrind runs as a test fixture Plugin hook.
##

CLEAN.include(File.join(VALGRIND_ARTIFACTS_PATH, '*'))

task directories: [VALGRIND_ARTIFACTS_PATH]

task :valgrind => [:prepare] do
  Rake.application['test:all'].invoke
end

namespace VALGRIND_SYM do

  desc "Run all unit tests under Valgrind (also just 'valgrind' works)."
  task :all => [:prepare] do
    Rake.application['test:all'].invoke
  end

  desc "Run single Valgrind test ([*] test or source file name, no path)."
  task :* do
    message = "Oops! '#{VALGRIND_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name (no path) in place of the wildcard.\n" +
              "Example: `ceedling #{VALGRIND_ROOT_NAME}:foo.c`"
    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc "Run Valgrind tests by matching regular expression pattern."
  task :pattern, [:regex] => [:prepare] do |t, args|
    Rake.application['test:pattern'].invoke( args.regex )
  end

  desc "Run Valgrind tests whose test path contains [dir] or [dir] substring."
  task :path, [:dir] => [:prepare] do |t, args|
    Rake.application['test:path'].invoke( args.dir )
  end

end

# Use a rule to handle dynamic per-file tasks: valgrind:foo → test:foo
# Mirrors the dependency proc in rules_tests.rake to resolve the test file,
# then redirects to the corresponding test: task (which triggers that rule).
rule(/^#{VALGRIND_TASK_ROOT}\S+$/ => [
  proc do |task_name|
    test = task_name.strip().sub(/^#{VALGRIND_TASK_ROOT}/, '').chomp( EXTENSION_SOURCE )
    test = PROJECT_TEST_FILE_PREFIX + test unless test.start_with?( PROJECT_TEST_FILE_PREFIX )
    @ceedling[:file_finder].find_test_file_from_name( test )
  end
]) do |valgrind_task|
  @ceedling[:rake_wrapper][:prepare].invoke
  test_task = valgrind_task.name.sub( /^#{VALGRIND_TASK_ROOT}/, TEST_TASK_ROOT )
  Rake.application[test_task].invoke
end
