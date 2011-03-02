require 'rubygems'
require 'rake' # for ext()


class TestInvoker

  attr_reader :sources, :tests, :mocks

  constructor :configurator, :test_invoker_helper, :streaminator, :preprocessinator, :task_invoker, :dependinator, :project_config_manager, :file_path_utils

  def setup
    @sources = []
    @tests   = []
    @mocks   = []
  end
  
  def setup_and_invoke(tests, options={:force_run => true})
  
    @tests = tests

    @project_config_manager.process_test_config_change
  
    @tests.each do |test|
      # announce beginning of test run
      header = "Test '#{File.basename(test)}'"
      @streaminator.stdout_puts("\n\n#{header}\n#{'-' * header.length}")

      begin      
        # collect up test fixture pieces & parts
        runner       = @file_path_utils.form_runner_filepath_from_test( test )
        mock_list    = @preprocessinator.preprocess_test_and_invoke_test_mocks( test )
        sources      = @test_invoker_helper.extract_sources( test )
        extras       = @configurator.collection_test_fixture_extra_link_objects
        core         = [test] + mock_list + sources
        objects      = @file_path_utils.form_test_build_objects_filelist( [runner] + core + extras )
        results_pass = @file_path_utils.form_pass_results_filepath( test )
        results_fail = @file_path_utils.form_fail_results_filepath( test )
        
        # clean results files so we have a missing file with which to kick off rake's dependency rules
        @test_invoker_helper.clean_results( {:pass => results_pass, :fail => results_fail}, options )

        # load up auxiliary dependencies so deep changes cause rebuilding appropriately
        @test_invoker_helper.process_auxiliary_dependencies( core )

        # tell rake to create test runner if needed
        @task_invoker.invoke_test_runner( runner )

        # enhance object file dependencies to capture externalities influencing regeneration
        @dependinator.enhance_test_build_object_dependencies( objects )

        # associate object files with executable
        @dependinator.setup_test_executable_dependencies( test, objects )

        # 3, 2, 1... launch
        @task_invoker.invoke_test_results( results_pass )
      rescue => e
        @test_invoker_helper.process_exception(e)
      end
      
      # store away what's been processed
      @mocks.concat( mock_list )
      @sources.concat( sources )
    end

    # post-process collected mock list
    @mocks.uniq!
    
    # post-process collected sources list
    @sources.uniq!
  end

end
