require 'ceedling/constants'

task :test => [:directories] do
  Rake.application['test:all'].invoke
end

namespace TEST_SYM do

  TOOL_COLLECTION_TEST_TASKS = {
    :test_compiler  => TOOLS_TEST_COMPILER,
    :test_assembler => TOOLS_TEST_ASSEMBLER,
    :test_linker    => TOOLS_TEST_LINKER,
    :test_fixture   => TOOLS_TEST_FIXTURE
  }

  desc "Run all unit tests (also just 'test' works)."
  task :all => [:directories] do
    @ceedling[:test_invoker].setup_and_invoke(
      tests:COLLECTION_ALL_TESTS,
      options:{:force_run => true, :build_only => false}.merge(TOOL_COLLECTION_TEST_TASKS))
  end

  desc "Run single test ([*] test or source file name, no path)."
  task :* do
    message = "\nOops! '#{TEST_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name (no path) in place of the wildcard.\n" +
              "Example: rake #{TEST_ROOT_NAME}:foo.c\n\n"

    @ceedling[:streaminator].stdout_puts( message, Verbosity::ERRORS )
  end

  desc "Just build tests without running."
  task :build_only => [:directories] do
    @ceedling[:test_invoker].setup_and_invoke(tests:COLLECTION_ALL_TESTS, options:{:build_only => true}.merge(TOOL_COLLECTION_TEST_TASKS))
  end

  desc "Run tests by matching regular expression pattern."
  task :pattern, [:regex] => [:directories] do |t, args|
    matches = []

    COLLECTION_ALL_TESTS.each { |test| matches << test if (test =~ /#{args.regex}/) }

    if (matches.size > 0)
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, options:{:force_run => false}.merge(TOOL_COLLECTION_TEST_TASKS))
    else
      @ceedling[:streaminator].stdout_puts( "\nFound no tests matching pattern /#{args.regex}/.", Verbosity::ERRORS )
    end
  end

  desc "Run tests whose test path contains [dir] or [dir] substring."
  task :path, [:dir] => [:directories] do |t, args|
    matches = []

    COLLECTION_ALL_TESTS.each { |test| matches << test if File.dirname(test).include?(args.dir.gsub(/\\/, '/')) }

    if (matches.size > 0)
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, options:{:force_run => false}.merge(TOOL_COLLECTION_TEST_TASKS))
    else
      @ceedling[:streaminator].stdout_puts( "\nFound no tests including the given path or path component.", Verbosity::ERRORS )
    end
  end

end

