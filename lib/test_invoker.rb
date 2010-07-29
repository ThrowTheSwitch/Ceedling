require 'rubygems'
require 'rake' # for ext()


class TestInvoker

  attr_reader :sources, :tests, :mocks

  constructor :test_invoker_helper, :streaminator, :preprocessinator, :task_invoker, :dependinator, :file_finder, :file_path_utils

  def setup
    @sources = []
    @tests   = []
    @mocks   = []
  end
  
  def invoke_tests(tests, options={:force_run => true})
  
    @tests = tests
  
    tests.each do |test|
      # announce beginning of test run
      header = "Test '#{File.basename(test)}'"
      @streaminator.stdout_puts("\n\n#{header}\n#{'-' * header.length}")
      
      # collect up test components
      runner     = @file_path_utils.form_runner_filepath_from_test(test)
      mock_list  = @preprocessinator.preprocess_test_and_invoke_mocks(test)
      source     = @file_finder.find_source_from_test(test) # source may be nil if test has no corresponding source file
      files      = ([test, runner, source] + mock_list).compact
      
      # clean results files so we have a missing file to kick off rake's dependency rules with
      @test_invoker_helper.clean_results(options, test)

      # runner setup
      @test_invoker_helper.preprocessing_setup_for_runner(runner)
      @task_invoker.invoke_runner(runner)

      # load up auxiliary dependencies so things that deep changes cause rebuilding appropriately
      @test_invoker_helper.process_auxiliary_dependencies(files)

      # plug in a few more dependencies to cause regeneration of generated files
      @dependinator.enhance_vendor_objects_with_environment_dependencies()
      @dependinator.enhance_object_with_environment_dependencies(files)
      @dependinator.setup_executable_dependencies(test)

      # go
      @task_invoker.invoke_results( @file_path_utils.form_pass_results_filepath(test) )
      
      @sources << source if (!source.nil?)
      @mocks   << mock_list
    end
    
    @mocks.flatten!
    @mocks.uniq!
    
    @sources.uniq!
  end

end
