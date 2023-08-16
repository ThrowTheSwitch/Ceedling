require 'ceedling/constants'
require 'ceedling/par_map'
require 'fileutils'

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
              :generator,
              :test_context_extractor,
              :flaginator,
              :defineinator,
              :file_path_utils,
              :file_wrapper

  def setup
    @testables = {}
    @mocks     = []
    @runners   = []

    @lock = Mutex.new

    # Alias for brevity in code that follows
    @helper = @test_invoker_helper
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

  def setup_and_invoke(tests:, context: TEST_SYM, options: {:force_run => true, :build_only => false})
    @project_config_manager.process_test_config_change

    # Begin fleshing out the testables data structure
    @helper.execute_build_step("Extracting Build Context for Test Files", banner: false) do
      par_map(PROJECT_TEST_THREADS, tests) do |filepath|
        filepath = filepath.to_s
        test = test_filepath_symbolize(filepath)

        @lock.synchronize do
          @testables[test] = {
            :filepath => filepath,
            :compile_flags => @flaginator.flag_down( context:context, operation:OPERATION_COMPILE_SYM, filepath:filepath ),
            :link_flags => @flaginator.flag_down( context:context, operation:OPERATION_LINK_SYM, filepath:filepath ),
            :defines => @defineinator.defines( context:context, filepath:filepath )
          }
        end
      end
    end

    # TODO: Revert collections (whole test executable builds with the same :define: sets)
    # Group definition sets into collections
    # collections = []
    # general_collection = { :tests   => tests.clone,
    #                        :build   => @configurator.project_test_build_output_path,
    #                        :defines => COLLECTION_DEFINES_TEST_AND_VENDOR.clone }  
    # test_specific_defines = @configurator.project_config_hash.keys.select {|k| k.to_s.match /defines_\w+/}

    # @helper.execute_build_step("Collecting Definitions", banner: false) {
    #   par_map(PROJECT_TEST_THREADS, @tests) do |test|
    #     test_name ="#{File.basename(test)}".chomp('.c')
    #     def_test_key="defines_#{test_name.downcase}".to_sym
    #     has_specific_defines = test_specific_defines.include?(def_test_key)

    #     if has_specific_defines || @configurator.defines_use_test_definition
    #       @streaminator.stdout_puts("Updating test definitions for #{test_name}", Verbosity::NORMAL)
    #       defs_bkp = Array.new(COLLECTION_DEFINES_TEST_AND_VENDOR)
    #       tst_defs_cfg = Array.new(defs_bkp)
    #       if has_specific_defines
    #         tst_defs_cfg.replace(@configurator.project_config_hash[def_test_key])
    #         tst_defs_cfg.concat(COLLECTION_DEFINES_VENDOR) if COLLECTION_DEFINES_VENDOR
    #       end
    #       if @configurator.defines_use_test_definition
    #         tst_defs_cfg << File.basename(test, ".*").strip.upcase.sub(/@.*$/, "")
    #       end

    #       # add this to our collection of things to build
    #       collections << { :tests => [ test ],
    #                        :build => has_specific_defines ? File.join(@configurator.project_test_build_output_path, test_name) : @configurator.project_test_build_output_path,
    #                        :defines => tst_defs_cfg }

    #       # remove this test from the general collection
    #       general_collection[:tests].delete(test)
    #     end
    #   end
    # } if test_specific_defines.size > 0

    # # add a general collection if there are any files remaining for it
    # collections << general_collection unless general_collection[:tests].empty?

    # Run Each Collection
    # TODO: eventually, if we pass ALL arguments to the build system, this can be done in parallel
    # collections.each do |collection|

      # # Switch to the things that make this collection unique
      # COLLECTION_DEFINES_TEST_AND_VENDOR.replace( collection[:defines] )

      # @configurator.project_config_hash[:project_test_build_output_path] = collection[:build]

    # Determine include statements, mocks, build directives, etc. from test files
    @helper.execute_build_step("Extracting Testing Context from Test Files", banner: false) do
      par_map(PROJECT_TEST_THREADS, @testables) do |_, details|
        @preprocessinator.preprocess_test_file( details[:filepath] )
      end
    end

    # Determine Runners & Mocks For All Tests
    @helper.execute_build_step("Determining Files to be Generated", banner: false) do
      par_map(PROJECT_TEST_THREADS, @testables) do |test, details|
        runner = @file_path_utils.form_runner_filepath_from_test( details[:filepath] )
        mock_list = @preprocessinator.fetch_mock_list_for_test_file( details[:filepath] )

        @lock.synchronize do
          details[:runner] = runner
          @runners << runner

          details[:mock_list] = mock_list
          @mocks += mock_list
        end
      end

      @mocks.uniq!
    end

    # Preprocess Header Files
    @helper.execute_build_step("Preprocessing Header Files", banner: false) {
      mockable_headers = @file_path_utils.form_preprocessed_mockable_headers_filelist(@mocks) 
      par_map(PROJECT_TEST_THREADS, mockable_headers) do |header|
        @preprocessinator.preprocess_mockable_header( header )
      end
    } if @configurator.project_use_test_preprocessor

    # Generate mocks for all tests
    @helper.execute_build_step("Generating Mocks") do
      @test_invoker_helper.generate_mocks_now(@mocks)
      #@task_invoker.invoke_test_mocks( mock_list )
    end

    # Preprocess Test Files
    @helper.execute_build_step("Preprocess Test Files", banner: false) do
      par_map(PROJECT_TEST_THREADS, @testables) do |_, details|
        @preprocessinator.preprocess_remainder(details[:filepath])     
      end
    end

    # Build Runners For All Tests
    @helper.execute_build_step("Generating Test Runners") do
      @test_invoker_helper.generate_runners_now(@runners)
      #par_map(PROJECT_TEST_THREADS, tests) do |test|
      #  @task_invoker.invoke_test_runner( testables[test][:runner] )
      #end
    end

    # Determine Objects Required For Each Test
    @helper.execute_build_step("Determining Objects to Be Built", banner: false) do
      par_map(PROJECT_TEST_THREADS, @testables) do |test, details|
        # collect up test fixture pieces & parts
        test_build_path    = File.join(@configurator.project_build_root, context.to_s, 'out')
        test_sources       = @test_invoker_helper.extract_sources( details[:filepath] )
        test_extras        = @configurator.collection_test_fixture_extra_link_objects
        test_core          = [details[:filepath]] + details[:mock_list] + test_sources
        test_objects       = @file_path_utils.form_test_build_objects_filelist( test_build_path, [details[:runner]] + test_core + test_extras ).uniq
        test_executable    = @file_path_utils.form_test_executable_filepath( test_build_path, details[:filepath] )
        test_pass          = @file_path_utils.form_pass_results_filepath( test_build_path, details[:filepath] )
        test_fail          = @file_path_utils.form_fail_results_filepath( test_build_path, details[:filepath] )

        # identify all the objects shall not be linked and then remove them from objects list.
        test_no_link_objects = @file_path_utils.form_test_build_objects_filelist(test_build_path, @preprocessinator.fetch_shallow_source_includes( details[:filepath] ))
        test_objects = test_objects.uniq - test_no_link_objects

        @lock.synchronize do
          details[:build_path]      = test_build_path
          details[:sources]         = test_sources
          details[:extras]          = test_extras
          details[:core]            = test_core
          details[:objects]         = test_objects
          details[:executable]      = test_executable
          details[:no_link_objects] = test_no_link_objects
          details[:results_pass]    = test_pass
          details[:results_fail]    = test_fail
        end

        # remove results files for the tests we plan to run
        @test_invoker_helper.clean_results( {:pass => test_pass, :fail => test_fail}, options )
      end
    end

    # Create build path structure
    @helper.execute_build_step("Creating Test Executable Build Paths", banner: false) do
      par_map(PROJECT_TEST_THREADS, @testables) do |_, details|
        @file_wrapper.mkdir(details[:build_path])
      end
    end

    # TODO: Replace with smart rebuild feature
    # @helper.execute_build_step("Generating Dependencies", banner: false) {
    #   par_map(PROJECT_TEST_THREADS, core_testables) do |dependency|
    #     @test_invoker_helper.process_deep_dependencies( dependency ) do |dep|
    #       @dependinator.load_test_object_deep_dependencies( dep)
    #     end
    #   end
    # } if @configurator.project_use_deep_dependencies

    # TODO: Replace with smart rebuild
    # # Update All Dependencies
    # @helper.execute_build_step("Preparing to Build", banner: false) do
    #   par_map(PROJECT_TEST_THREADS, tests) do |test|
    #     # enhance object file dependencies to capture externalities influencing regeneration
    #     @dependinator.enhance_test_build_object_dependencies( testables[test][:objects] )

    #     # associate object files with executable
    #     @dependinator.enhance_test_executable_dependencies( test, testables[test][:objects] )
    #   end
    # end

    # Build All Test objects
    @helper.execute_build_step("Building Objects") do
      # FYI: Temporarily removed direct object generation to allow rake invoke() to execute custom compilations (plugins, special cases)
      # @test_invoker_helper.generate_objects_now(object_list, options)
      @testables.each do |test, details|
        @task_invoker.invoke_test_objects(testname: test.to_s, objects:details[:objects])
      end
    end

    # Create Final Tests And/Or Executable Links
    @helper.execute_build_step("Building Test Executables") do
      lib_args = convert_libraries_to_arguments()
      lib_paths = get_library_paths_to_arguments()
      par_map(PROJECT_TEST_THREADS, @testables) do |_, details|
        @test_invoker_helper.generate_executable_now(
          details[:build_path],
          details[:executable],
          details[:objects],
          details[:link_flags],
          lib_args,
          lib_paths,
          options)
      end
    end

    # Execute Final Tests
    @helper.execute_build_step("Executing") {
      par_map(PROJECT_TEST_THREADS, @testables) do |test, details|
        begin
          @plugin_manager.pre_test( details[:filepath] )
          @test_invoker_helper.run_fixture_now( details[:executable], details[:results_pass], options )
        rescue => e
          @build_invoker_utils.process_exception( e, context )
        ensure
          @plugin_manager.post_test( details[:filepath] )
        end
      end
    } unless options[:build_only]
  end

  def compile_test_component(test:, source:, object:)
    testable = @testables[test]
    filepath = testable[:filepath]
    compile_flags = testable[:compile_flags]
    defines = testable[:defines]

    @generator.generate_object_file_c(
      source: source,
      object: object,
      search_paths: @test_context_extractor.lookup_include_paths_list( filepath ),
      flags: compile_flags,
      defines: defines,
      list: @file_path_utils.form_test_build_list_filepath( object ),
      dependencies: @file_path_utils.form_test_dependencies_filepath( object ))
  end

  def refresh_deep_dependencies
    @file_wrapper.rm_f(
      @file_wrapper.directory_listing(
        File.join( @configurator.project_test_dependencies_path, '*' + @configurator.extension_dependencies ) ) )

    @test_invoker_helper.process_deep_dependencies(
      (@configurator.collection_all_tests + @configurator.collection_all_source).uniq )
  end

  private

  def test_filepath_symbolize(filepath)
    return (File.basename( filepath ).ext('')).to_sym
  end

end
