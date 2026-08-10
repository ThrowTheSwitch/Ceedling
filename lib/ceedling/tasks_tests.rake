# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

task :test => [:prepare] do
  Rake.application['test:all'].invoke
end

namespace TEST_SYM do

  desc "Run all unit tests (also just 'test' works)."
  task :all => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests: COLLECTION_ALL_TESTS, options: [:refresh_dependencies])
  end

  desc "Run single test ([*] test or source file name, with path if needed to disambiguate)."
  task :* do
    message = "Oops! '#{TEST_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name in place of the wildcard, " +
              "adding as much of its path as needed to identify one file among any same-named tests.\n" +
              "Example: `ceedling #{TEST_ROOT_NAME}:foo.c` or `ceedling #{TEST_ROOT_NAME}:unit/foo.c`"

    @ceedling[:loginator].log( message, Verbosity::ERRORS )
  end

  desc "Just build tests without running."
  task :build_only => [:prepare] do
    @ceedling[:test_invoker].setup_and_invoke(tests: COLLECTION_ALL_TESTS, options: [:build_only])
  end

  desc "Run tests by matching regular expression pattern."
  task :pattern, [:regex] => [:prepare] do |t, args|
    matches = []

    COLLECTION_ALL_TESTS.each { |test| matches << test if (test =~ /#{args.regex}/) }

    if (matches.size > 0)
      @ceedling[:test_invoker].setup_and_invoke(tests: matches, options: [])
    else
      @ceedling[:loginator].log( "Found no tests matching pattern /#{args.regex}/", Verbosity::ERRORS )
    end
  end

  desc "Run tests whose test path contains [dir] or [dir] substring."
  task :path, [:dir] => [:prepare] do |t, args|
    matches = []

    COLLECTION_ALL_TESTS.each { |test| matches << test if File.dirname(test).include?(args.dir.gsub(/\\/, '/')) }

    if (matches.size > 0)
      @ceedling[:test_invoker].setup_and_invoke(tests: matches, options: [])
    else
      @ceedling[:loginator].log( "Found no tests including the given path or path component", Verbosity::ERRORS )
    end
  end

end
