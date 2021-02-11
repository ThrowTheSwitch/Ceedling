require 'ceedling/constants'
require 'ceedling/par_map'
require 'thread'

class TestInvoker

  attr_reader :sources, :tests, :mocks

  constructor :configurator,
              :test_invoker_helper,
              :plugin_manager,
              :streaminator,
              :preprocessinator,
              :task_invoker,
              :dependinator,
              :project_config_manager,
              :build_invoker_utils,
              :file_path_utils,
              :file_wrapper

  def setup
    @sources = []
    @tests   = []
    @mocks   = []
    @lock    = Mutex.new
  end


  # Convert libraries configuration form YAML configuration
  # into a string that can be given to the compiler.
  def convert_libraries_to_arguments()
    args = ((@configurator.project_config_hash[:libraries_test] || []) + ((defined? LIBRARIES_SYSTEM) ? LIBRARIES_SYSTEM : [])).flatten
    if (defined? LIBRARIES_FLAG)
      args.map! {|v| LIBRARIES_FLAG.gsub(/\$\{1\}/, v) }
    end
    return args
  end

  def get_library_paths_to_arguments()
    paths = (defined? PATHS_LIBRARIES) ? (PATHS_LIBRARIES || []).clone : []
    if (defined? LIBRARIES_PATH_FLAG)
      paths.map! {|v| LIBRARIES_PATH_FLAG.gsub(/\$\{1\}/, v) }
    end
    return paths
  end

  def setup_and_invoke(tests, context=TEST_SYM, options={:force_run => true, :build_only => false})

    @tests = tests

    @project_config_manager.process_test_config_change

    # Create Storage For Works In Progress
    testables = {}
    mock_list = []
    @tests.each do |test|
      testables[test] = {}
    end

    # Collect Defines For Each Test    
    # test_specific_defines = @configurator.project_config_hash.keys.select {|k| k.to_s.match /defines_\w+/}
    # if test_specific_defines.size > 0
    #   puts test_specific_defines.inspect
    #   @streaminator.stdout_puts("\nCollecting Definitions", Verbosity::NORMAL)
    #   @streaminator.stdout_puts("------------------------", Verbosity::NORMAL) 
    #   par_map(PROJECT_TEST_THREADS, @tests) do |test|
    #     test_name ="#{File.basename(test)}".chomp('.c')
    #     def_test_key="defines_#{test_name.downcase}"
    #     has_specific_defines = test_specific_defines.include?(def_test_key)

    #     if has_specific_defines || @configurator.defines_use_test_definition
    #       defs_bkp = Array.new(COLLECTION_DEFINES_TEST_AND_VENDOR)
    #       tst_defs_cfg = Array.new(defs_bkp)
    #       if has_specific_defines
    #         tst_defs_cfg.replace(@configurator.project_config_hash[def_test_key.to_sym])
    #         tst_defs_cfg .concat(COLLECTION_DEFINES_VENDOR) if COLLECTION_DEFINES_VENDOR
    #       end
    #       if @configurator.defines_use_test_definition
    #         tst_defs_cfg << File.basename(test, ".*").strip.upcase.sub(/@.*$/, "")
    #       end
    #       COLLECTION_DEFINES_TEST_AND_VENDOR.replace(tst_defs_cfg)
    #     end

    #     # redefine the project out path and preprocessor defines
    #     if has_specific_defines
    #       @streaminator.stdout_puts("Updating test definitions for #{test_name}", Verbosity::NORMAL)
    #       orig_path = @configurator.project_test_build_output_path
    #       @configurator.project_config_hash[:project_test_build_output_path] = File.join(@configurator.project_test_build_output_path, test_name)
    #       @file_wrapper.mkdir(@configurator.project_test_build_output_path)
    #     end
    #   end
    # end

    # Preprocess Test Files
    if (@configurator.project_use_test_preprocessor)
      @streaminator.stdout_puts("\nPreprocessing Test Files", Verbosity::NORMAL)
      @streaminator.stdout_puts("------------------------", Verbosity::NORMAL)
      par_map(PROJECT_TEST_THREADS, @tests) do |test|
        testables[test][:mock_list] = @preprocessinator.preprocess_test_file( test )
      end
    end

    # Determine Runners & Mocks For All Tests
    @streaminator.stdout_puts("\nDetermining Requirements", Verbosity::NORMAL)
    par_map(PROJECT_TEST_THREADS, @tests) do |test|
      testables[test][:runner] = @file_path_utils.form_runner_filepath_from_test( test )
      testables[test][:mock_list] = @preprocessinator.fetch_mock_list_for_test_file( test )

      @lock.synchronize do
        mock_list += testables[test][:mock_list]
      end
    end
    mock_list.uniq!

    # Preprocess Header Files
    if @configurator.project_use_test_preprocessor
      @streaminator.stdout_puts("\nPreprocessing Header Files", Verbosity::NORMAL)
      @streaminator.stdout_puts("--------------------------", Verbosity::NORMAL) 
      par_map(PROJECT_TEST_THREADS, @tests) do |test|
        @preprocessinator.preprocess_mockable_headers( testables[test][:mock_list] )
      end
    end
    
    # Build Mocks For All Tests
    @streaminator.stdout_puts("\nGenerating Mocks", Verbosity::NORMAL)
    @streaminator.stdout_puts("----------------", Verbosity::NORMAL)
    @task_invoker.invoke_test_mocks( mock_list )
    @mocks.concat( mock_list )

    # Preprocess Test Files
    @streaminator.stdout_puts("\nPreprocess Test Files", Verbosity::NORMAL)
    #@streaminator.stdout_puts("---------------------", Verbosity::NORMAL) if @configurator.project_use_auxiliary_dependencies
    par_map(PROJECT_TEST_THREADS, @tests) do |test|   
      @preprocessinator.preprocess_remainder(test)     
    end

    # Determine Objects Required For Each Test
    @streaminator.stdout_puts("\nDetermining Objects to Be Built", Verbosity::NORMAL)
    par_map(PROJECT_TEST_THREADS, @tests) do |test|        
      # collect up test fixture pieces & parts
      testables[test][:sources]      = @test_invoker_helper.extract_sources( test )
      testables[test][:extras]       = @configurator.collection_test_fixture_extra_link_objects
      testables[test][:core]         = [test] + testables[test][:mock_list] + testables[test][:sources]
      testables[test][:objects]      = @file_path_utils.form_test_build_objects_filelist( [testables[test][:runner]] + testables[test][:core] + testables[test][:extras] ).uniq
      testables[test][:results_pass] = @file_path_utils.form_pass_results_filepath( test )
      testables[test][:results_fail] = @file_path_utils.form_fail_results_filepath( test )

      # identify all the objects shall not be linked and then remove them from objects list.
      testables[test][:no_link_objects] = @file_path_utils.form_test_build_objects_filelist(@preprocessinator.preprocess_shallow_source_includes( test ))
      testables[test][:objects] = testables[test][:objects].uniq - testables[test][:no_link_objects]
    end

    # Handle Test Define Changes
    # @project_config_manager.process_test_defines_change(@project_config_manager.filter_internal_sources(sources))

    # clean results files so we have a missing file with which to kick off rake's dependency rules
    if @configurator.project_use_deep_dependencies
      @streaminator.stdout_puts("\nGenerating Dependencies", Verbosity::NORMAL)
      @streaminator.stdout_puts("-----------------------", Verbosity::NORMAL)
    end 
    par_map(PROJECT_TEST_THREADS, @tests) do |test|
      @test_invoker_helper.clean_results( {:pass => testables[test][:results_pass], :fail => testables[test][:results_fail]}, options )

      @test_invoker_helper.process_deep_dependencies( testables[test][:core] ) do |dependencies_list|
        @dependinator.load_test_object_deep_dependencies( dependencies_list )
      end
    end

    # Build Runners For All Tests
    @streaminator.stdout_puts("\nGenerating Runners", Verbosity::NORMAL)
    @streaminator.stdout_puts("------------------", Verbosity::NORMAL)
    par_map(PROJECT_TEST_THREADS, @tests) do |test|
      @task_invoker.invoke_test_runner( testables[test][:runner] )
    end

    # Update All Dependencies
    @streaminator.stdout_puts("\nPreparing to Build", Verbosity::NORMAL)
    par_map(PROJECT_TEST_THREADS, @tests) do |test|
      # enhance object file dependencies to capture externalities influencing regeneration
      @dependinator.enhance_test_build_object_dependencies( testables[test][:objects] )

      # associate object files with executable
      @dependinator.enhance_test_executable_dependencies( test, testables[test][:objects] )
    end

    # Build All Test objects
    @streaminator.stdout_puts("\nBuilding Objects", Verbosity::NORMAL)
    @streaminator.stdout_puts("----------------", Verbosity::NORMAL)
    par_map(PROJECT_TEST_THREADS, @tests) do |test|
      @task_invoker.invoke_test_objects( testables[test][:objects] )
    end

    # Invoke Final Tests And/Or Executable Links
    @streaminator.stdout_puts("\nExecuting", Verbosity::NORMAL)
    @streaminator.stdout_puts("---------", Verbosity::NORMAL)
    par_map(PROJECT_TEST_THREADS, @tests) do |test|
      begin
        @plugin_manager.pre_test( test )
        test_name ="#{File.basename(test)}".chomp('.c')

        if (options[:build_only])
          # If the option build_only has been specified, build the executable but do not run test
          executable = @file_path_utils.form_test_executable_filepath( test )
          @task_invoker.invoke_test_executable( executable )
        else
          # 3, 2, 1... Launch (build & execute test)
          @task_invoker.invoke_test_results( testables[test][:results_pass] )
        end
      rescue => e
        @build_invoker_utils.process_exception( e, context )
      ensure

        @lock.synchronize do
          @sources.concat( testables[test][:sources] )
        end
        @plugin_manager.post_test( test )
        # # restore the project test defines
        # if @configurator.project_config_hash.has_key?(def_test_key.to_sym) || @configurator.defines_use_test_definition
        #   COLLECTION_DEFINES_TEST_AND_VENDOR.replace(defs_bkp)
        #   if @configurator.project_config_hash.has_key?(def_test_key.to_sym)
        #     @configurator.project_config_hash[:project_test_build_output_path] = orig_path
        #     @streaminator.stdout_puts("Restored defines and build path to standard", Verbosity::NORMAL)
        #   end
        # end
      end
    end

    # post-process collected mock list
    @mocks.uniq!

    # post-process collected sources list
    @sources.uniq!
  end


  def refresh_deep_dependencies
    @file_wrapper.rm_f(
      @file_wrapper.directory_listing(
        File.join( @configurator.project_test_dependencies_path, '*' + @configurator.extension_dependencies ) ) )

    @test_invoker_helper.process_deep_dependencies(
      @configurator.collection_all_tests + @configurator.collection_all_source )
  end

end
