# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

##
## This Rakefile plugin runs test executables under Valgrind via the test
## fixture plugin hook. It calls the test invoker directly (same as gcov.rake)
## to avoid marking test: tasks as invoked.
##

CLEAN.include(File.join(VALGRIND_ARTIFACTS_PATH, '*'))

task directories: [VALGRIND_ARTIFACTS_PATH]

task :valgrind => [:prepare] do
  Rake.application['valgrind:all'].invoke
end

namespace VALGRIND_SYM do

  desc "Run all unit tests under Valgrind (also just 'valgrind' works)."
  task :all => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(
      tests: COLLECTION_ALL_TESTS,
      context: VALGRIND_SYM,
      options: { :force_run => true, :build_only => false }.merge(TOOL_COLLECTION_TEST_TASKS)
    )
  end

  desc "Run single Valgrind test ([*] test or source file name, no path)."
  task :* do
    message = "Oops! '#{VALGRIND_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name (no path) in place of the wildcard.\n" +
              "Example: `ceedling #{VALGRIND_ROOT_NAME}:foo.c`"
    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc "Run Valgrind tests by matching regular expression pattern."
  task :pattern, [:regex] => [:prepare] do |_t, args|
    matches = []
    COLLECTION_ALL_TESTS.each { |test| matches << test if test =~ /#{args.regex}/ }
    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke(
        tests: matches,
        context: VALGRIND_SYM,
        options: { :force_run => false }.merge(TOOL_COLLECTION_TEST_TASKS)
      )
    else
      @ceedling[:loginator].log( "Found no tests matching pattern /#{args.regex}/", Verbosity::ERRORS )
    end
  end

  desc "Run Valgrind tests whose test path contains [dir] or [dir] substring."
  task :path, [:dir] => [:prepare] do |_t, args|
    matches = []
    COLLECTION_ALL_TESTS.each { |test| matches << test if File.dirname(test).include?(args.dir.tr('\\', '/')) }
    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke(
        tests: matches,
        context: VALGRIND_SYM,
        options: { :force_run => false }.merge(TOOL_COLLECTION_TEST_TASKS)
      )
    else
      @ceedling[:loginator].log( "Found no tests including the given path or path component", Verbosity::ERRORS )
    end
  end

end

# Use a rule to handle dynamic per-file tasks: valgrind:foo → build and run foo under Valgrind
rule(/^#{VALGRIND_TASK_ROOT}\S+$/ => [
  proc do |task_name|
    test = task_name.strip().sub(/^#{VALGRIND_TASK_ROOT}/, '').chomp(EXTENSION_SOURCE)
    test = PROJECT_TEST_FILE_PREFIX + test unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
    @ceedling[:file_finder].find_test_file_from_name(test)
  end
]) do |test|
  @ceedling[:rake_wrapper][:prepare].invoke
  @ceedling[:test_invoker].setup_and_invoke(
    tests: [test.source],
    context: VALGRIND_SYM,
    options: { :force_run => true, :build_only => false }.merge(TOOL_COLLECTION_TEST_TASKS)
  )
end
