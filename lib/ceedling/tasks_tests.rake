require 'ceedling/constants'

task :test_deps => [:directories] do
  # Copy Unity C files into build/vendor directory structure
  @ceedling[:file_wrapper].cp_r(
    # '/.' to cause cp_r to copy directory contents
    File.join( UNITY_VENDOR_PATH, UNITY_LIB_PATH, '/.' ),
    PROJECT_BUILD_VENDOR_UNITY_PATH )

  # Copy CMock C files into build/vendor directory structure
  @ceedling[:file_wrapper].cp_r(
    # '/.' to cause cp_r to copy directory contents
    File.join( CMOCK_VENDOR_PATH, CMOCK_LIB_PATH, '/.' ),
    PROJECT_BUILD_VENDOR_CMOCK_PATH ) if PROJECT_USE_MOCKS

  # Copy CException C files into build/vendor directory structure
  @ceedling[:file_wrapper].cp_r(
    # '/.' to cause cp_r to copy directory contents
    File.join( CEXCEPTION_VENDOR_PATH, CEXCEPTION_LIB_PATH, '/.' ),
    PROJECT_BUILD_VENDOR_CEXCEPTION_PATH ) if PROJECT_USE_EXCEPTIONS
end

task :test => [:test_deps] do
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
  task :all => [:test_deps] do
    @ceedling[:test_invoker].setup_and_invoke(
      tests:COLLECTION_ALL_TESTS,
      options:{:force_run => true, :build_only => false}.merge(TOOL_COLLECTION_TEST_TASKS))
  end

  desc "Run single test ([*] test or source file name, no path)."
  task :* do
    message = "\nOops! '#{TEST_ROOT_NAME}:*' isn't a real task. " +
              "Use a real test or source file name (no path) in place of the wildcard.\n" +
              "Example: rake #{TEST_ROOT_NAME}:foo.c\n\n"

    @ceedling[:streaminator].stdout_puts( message )
  end

  desc "Just build tests without running."
  task :build_only => [:test_deps] do
    @ceedling[:test_invoker].setup_and_invoke(tests:COLLECTION_ALL_TESTS, options:{:build_only => true}.merge(TOOL_COLLECTION_TEST_TASKS))
  end

  desc "Run tests by matching regular expression pattern."
  task :pattern, [:regex] => [:test_deps] do |t, args|
    matches = []

    COLLECTION_ALL_TESTS.each { |test| matches << test if (test =~ /#{args.regex}/) }

    if (matches.size > 0)
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, options:{:force_run => false}.merge(TOOL_COLLECTION_TEST_TASKS))
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests matching pattern /#{args.regex}/.")
    end
  end

  desc "Run tests whose test path contains [dir] or [dir] substring."
  task :path, [:dir] => [:test_deps] do |t, args|
    matches = []

    COLLECTION_ALL_TESTS.each { |test| matches << test if File.dirname(test).include?(args.dir.gsub(/\\/, '/')) }

    if (matches.size > 0)
      @ceedling[:test_invoker].setup_and_invoke(tests:matches, options:{:force_run => false}.merge(TOOL_COLLECTION_TEST_TASKS))
    else
      @ceedling[:streaminator].stdout_puts("\nFound no tests including the given path or path component.")
    end
  end

end

