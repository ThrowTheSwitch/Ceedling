# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

##
## This Rakefile plugin builds and runs test executables with sanitizers via its
## build hooks. It calls the test invoker directly (same as gcov.rake)
## to avoid marking test: tasks as invoked.
##

# The plugin's own build context, kept apart from test builds
CLEAN.include(File.join(SANITIZE_BUILD_PATH, BUILD_OUT_DIR, '*'))
CLEAN.include(File.join(SANITIZE_BUILD_PATH, BUILD_RESULTS_DIR, '*'))
CLEAN.include(File.join(SANITIZE_BUILD_PATH, BUILD_DEPENDENCIES_DIR, '*'))
CLEAN.include(File.join(SANITIZE_ARTIFACTS_PATH, '**/*'))

CLOBBER.include(File.join(SANITIZE_BUILD_PATH, '**/*'))

# The artifacts path as a Rake directory task, so the `directories` prerequisite below
# can resolve it
directory(SANITIZE_ARTIFACTS_PATH)

task directories: [SANITIZE_ARTIFACTS_PATH]

# Every sanitize: task depends on this. It is the one place the host platform and
# the fixture tool are checked, so a build that never runs a sanitize: task
# never requires them. See Sanitize#validate_environment!.
task :sanitize_deps do
  @ceedling[SANITIZE_SYM].validate_environment!
end

task :sanitize => [:prepare, :sanitize_deps] do
  Rake.application['sanitize:all'].invoke
end

namespace SANITIZE_SYM do

  desc "Run all unit tests with sanitizers (also just 'sanitize' works)."
  task :all => [:prepare, :sanitize_deps] do
    @ceedling[:test_invoker].setup_and_invoke(
      tests: COLLECTION_ALL_TESTS,
      context: SANITIZE_SYM,
      options: []
    )
  end

  desc "Run single sanitized test ([*] test or source file name, no path)."
  task :* do
    message = "Oops! '#{SANITIZE_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name (no path) in place of the wildcard.\n" +
              "Example: `ceedling #{SANITIZE_ROOT_NAME}:foo.c`"
    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc "Run sanitized tests by matching regular expression pattern."
  task :pattern, [:regex] => [:prepare, :sanitize_deps] do |_t, args|
    matches = []
    # Compile the user's pattern once rather than once per test in the collection
    pattern = Regexp.new( args.regex )
    COLLECTION_ALL_TESTS.each { |test| matches << test if test.match?( pattern ) }
    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke(
        tests: matches,
        context: SANITIZE_SYM,
        options: []
      )
    else
      @ceedling[:loginator].log( "Found no tests matching pattern /#{args.regex}/", Verbosity::ERRORS )
    end
  end

  desc "Run sanitized tests whose test path contains [dir] or [dir] substring."
  task :path, [:dir] => [:prepare, :sanitize_deps] do |_t, args|
    matches = []
    COLLECTION_ALL_TESTS.each { |test| matches << test if File.dirname(test).include?(args.dir.tr('\\', '/')) }
    if !matches.empty?
      @ceedling[:test_invoker].setup_and_invoke(
        tests: matches,
        context: SANITIZE_SYM,
        options: []
      )
    else
      @ceedling[:loginator].log( "Found no tests including the given path or path component", Verbosity::ERRORS )
    end
  end

end

# Use a rule to handle dynamic per-file tasks: sanitize:foo → build and run foo with sanitizers
rule(/^#{SANITIZE_TASK_ROOT}\S+$/ => [
  proc do |task_name|
    test = task_name.strip().sub(/^#{SANITIZE_TASK_ROOT}/, '')
    EXTENSION_SOURCE.each { |ext| test = test.chomp(ext) }
    test = PROJECT_TEST_FILE_PREFIX + test unless test.start_with?(PROJECT_TEST_FILE_PREFIX)
    @ceedling[:file_finder].find_test_file_from_name(test)
  end
]) do |test|
  @ceedling[:rake_wrapper][:prepare].invoke
  @ceedling[:rake_wrapper][:sanitize_deps].invoke
  @ceedling[:test_invoker].setup_and_invoke(
    tests: [test.source],
    context: SANITIZE_SYM,
    options: []
  )
end
