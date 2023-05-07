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

    options[:symbol] = context

    # Create Storage For Works In Progress
    testables = {}
    mock_list = []
    runner_list = []
    @tests.each do |test|
      testables[test] = {}
    end

    # Group definition sets into collections
    collections = []
    general_collection = { :tests   => tests.clone,
                           :build   => @configurator.project_test_build_output_path,
                           :defines => COLLECTION_DEFINES_TEST_AND_VENDOR.clone }  
    test_specific_defines = @configurator.project_config_hash.keys.select {|k| k.to_s.match /defines_\w+/}
    if test_specific_defines.size > 0
      @streaminator.stdout_puts("\nCollecting Definitions", Verbosity::NORMAL)
      @streaminator.stdout_puts("------------------------", Verbosity::NORMAL) 
      par_map(PROJECT_TEST_THREADS, @tests) do |test|
        test_name ="#{File.basename(test)}".chomp('.c')
        def_test_key="defines_#{test_name.downcase}".to_sym
        has_specific_defines = test_specific_defines.include?(def_test_key)

        if has_specific_defines || @configurator.defines_use_test_definition
          @streaminator.stdout_puts("Updating test definitions for #{test_name}", Verbosity::NORMAL)
          defs_bkp = Array.new(COLLECTION_DEFINES_TEST_AND_VENDOR)
          tst_defs_cfg = Array.new(defs_bkp)
          if has_specific_defines
            tst_defs_cfg.replace(@configurator.project_config_hash[def_test_key])
            tst_defs_cfg .concat(COLLECTION_DEFINES_VENDOR) if COLLECTION_DEFINES_VENDOR
          end
          if @configurator.defines_use_test_definition
            tst_defs_cfg << File.basename(test, ".*").strip.upcase.sub(/@.*$/, "")
          end

          # add this to our collection of things to build
          collections << { :tests => [ test ],
                           :build => has_specific_defines ? File.join(@configurator.project_test_build_output_path, test_name) : @configurator.project_test_build_output_path,
                           :defines => tst_defs_cfg }

          # remove this test from the general collection
          general_collection[:tests].delete(test)
        end
      end
    end

    # add a general collection if there are any files remaining for it
    collections << general_collection unless general_collection[:tests].empty?

    # Run Each Collection
      #TODO: eventually, if we pass ALL arguments to the build system, this can be done in parallel
    collections.each do |collection|

      # Switch to the things that make this collection unique
      COLLECTION_DEFINES_TEST_AND_VENDOR.replace( collection[:defines] )
      @configurator.project_config_hash[:project_test_build_output_path] = collection[:build]
      @file_wrapper.mkdir(@configurator.project_test_build_output_path)

      # Determine Includes from Test Files
      @streaminator.stdout_puts("\nGetting Includes From Test Files", Verbosity::NORMAL)
      @streaminator.stdout_puts("--------------------------------", Verbosity::NORMAL)
      par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|
        @preprocessinator.preprocess_test_file( test )
      end

      # Determine Runners & Mocks For All Tests
      @streaminator.stdout_puts("\nDetermining Requirements", Verbosity::NORMAL)
      par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|
        test_runner = @file_path_utils.form_runner_filepath_from_test( test )
        test_mock_list = @preprocessinator.fetch_mock_list_for_test_file( test )

        @lock.synchronize do
          testables[test][:runner] = test_runner
          testables[test][:mock_list] = test_mock_list
          mock_list += testables[test][:mock_list]
          runner_list << test_runner
        end
      end
      mock_list.uniq!
      runner_list.uniq!

      # Preprocess Header Files
      if @configurator.project_use_test_preprocessor
        @streaminator.stdout_puts("\nPreprocessing Header Files", Verbosity::NORMAL)
        @streaminator.stdout_puts("--------------------------", Verbosity::NORMAL)
        mockable_headers = @file_path_utils.form_preprocessed_mockable_headers_filelist(mock_list) 
        par_map(PROJECT_TEST_THREADS, mockable_headers) do |mockable_header|
          @preprocessinator.preprocess_mockable_header( mockable_header )
        end
      end

      # Generate Mocks For All Tests
      @streaminator.stdout_puts("\nGenerating Mocks", Verbosity::NORMAL)
      @streaminator.stdout_puts("----------------", Verbosity::NORMAL)
      @test_invoker_helper.generate_mocks_now(mock_list)
      #@task_invoker.invoke_test_mocks( mock_list )
      @mocks.concat( mock_list )

      # Preprocess Test Files
      @streaminator.stdout_puts("\nPreprocess Test Files", Verbosity::NORMAL)
      #@streaminator.stdout_puts("---------------------", Verbosity::NORMAL) if @configurator.project_use_auxiliary_dependencies
      par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|   
        @preprocessinator.preprocess_remainder(test)     
      end

      # Determine Objects Required For Each Test
      @streaminator.stdout_puts("\nDetermining Objects to Be Built", Verbosity::NORMAL)
      core_testables = []
      object_list = []
      par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|        
        # collect up test fixture pieces & parts
        test_sources      = @test_invoker_helper.extract_sources( test )
        test_extras       = @configurator.collection_test_fixture_extra_link_objects
        test_core         = [test] + testables[test][:mock_list] + test_sources
        test_objects      = @file_path_utils.form_test_build_objects_filelist( [testables[test][:runner]] + test_core + test_extras ).uniq
        test_pass         = @file_path_utils.form_pass_results_filepath( test )
        test_fail         = @file_path_utils.form_fail_results_filepath( test )

        # identify all the objects shall not be linked and then remove them from objects list.
        test_no_link_objects = @file_path_utils.form_test_build_objects_filelist(@preprocessinator.preprocess_shallow_source_includes( test ))
        test_objects = test_objects.uniq - test_no_link_objects

        @lock.synchronize do
          testables[test][:sources]         = test_sources
          testables[test][:extras]          = test_extras
          testables[test][:core]            = test_core
          testables[test][:objects]         = test_objects
          testables[test][:no_link_objects] = test_no_link_objects
          testables[test][:results_pass]    = test_pass
          testables[test][:results_fail]    = test_fail

          core_testables += test_core
          object_list += test_objects
        end

        # remove results files for the tests we plan to run
        @test_invoker_helper.clean_results( {:pass => test_pass, :fail => test_fail}, options )

      end
      core_testables.uniq!
      object_list.uniq!

      # clean results files so we have a missing file with which to kick off rake's dependency rules
      if @configurator.project_use_deep_dependencies
        @streaminator.stdout_puts("\nGenerating Dependencies", Verbosity::NORMAL)
        @streaminator.stdout_puts("-----------------------", Verbosity::NORMAL)
      end 
      par_map(PROJECT_TEST_THREADS, core_testables) do |dependency|
        @test_invoker_helper.process_deep_dependencies( dependency ) do |dep|
          @dependinator.load_test_object_deep_dependencies( dep)
        end
      end

      # Build Runners For All Tests
      @streaminator.stdout_puts("\nGenerating Runners", Verbosity::NORMAL)
      @streaminator.stdout_puts("------------------", Verbosity::NORMAL)
      @test_invoker_helper.generate_runners_now(runner_list)
      #par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|
      #  @task_invoker.invoke_test_runner( testables[test][:runner] )
      #end

      # Update All Dependencies
      @streaminator.stdout_puts("\nPreparing to Build", Verbosity::NORMAL)
      par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|
        # enhance object file dependencies to capture externalities influencing regeneration
        @dependinator.enhance_test_build_object_dependencies( testables[test][:objects] )

        # associate object files with executable
        @dependinator.enhance_test_executable_dependencies( test, testables[test][:objects] )
      end

      # Build All Test objects
      @streaminator.stdout_puts("\nBuilding Objects", Verbosity::NORMAL)
      @streaminator.stdout_puts("----------------", Verbosity::NORMAL)
      @test_invoker_helper.generate_objects_now(object_list, options)
      #@task_invoker.invoke_test_objects(object_list)

      # Create Final Tests And/Or Executable Links
      @streaminator.stdout_puts("\nBuilding Test Executables", Verbosity::NORMAL)
      @streaminator.stdout_puts("-------------------------", Verbosity::NORMAL)
      lib_args = convert_libraries_to_arguments()
      lib_paths = get_library_paths_to_arguments()
      @test_invoker_helper.generate_executables_now(collection[:tests], testables, lib_args, lib_paths, options)

      # Execute Final Tests
      unless options[:build_only]
        @streaminator.stdout_puts("\nExecuting", Verbosity::NORMAL)
        @streaminator.stdout_puts("---------", Verbosity::NORMAL)
        par_map(PROJECT_TEST_THREADS, collection[:tests]) do |test|
          begin
            @plugin_manager.pre_test( test )
            test_name ="#{File.basename(test)}".chomp('.c')
            @test_invoker_helper.run_fixture_now( testables[test][:results_pass], options )
          rescue => e
            @build_invoker_utils.process_exception( e, context )
          ensure

            @lock.synchronize do
              @sources.concat( testables[test][:sources] )
            end
            @plugin_manager.post_test( test )
          end
        end
      end

      # If not the final collection, invalidate files so they'll be rebuilt collection
      if collection != general_collection
        @test_invoker_helper.invalidate_objects(object_list)
      end

    # this collection has finished
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
      (@configurator.collection_all_tests + @configurator.collection_all_source).uniq )
  end

end
