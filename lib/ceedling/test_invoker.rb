require 'ceedling/constants'


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
              :file_wrapper,
              :cmock_builder

  def setup
    @sources = []
    @tests   = []
    @mocks   = []
    @standard_test_paths = {}
    @standard_cmock = {}
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

  def backup_standard_test_paths
    @standard_test_paths[:project_test_build_output_path] = @configurator.project_test_build_output_path
    @standard_test_paths[:project_test_build_output_asm_path] = @configurator.project_test_build_output_asm_path
    @standard_test_paths[:project_test_build_output_c_path] = @configurator.project_test_build_output_c_path
    @standard_test_paths[:project_test_build_cache_path] = @configurator.project_test_build_cache_path
    @standard_test_paths[:project_test_dependencies_path] = @configurator.project_test_dependencies_path
    if @configurator.project_use_test_preprocessor
      @standard_test_paths[:project_test_preprocess_includes_path] = @configurator.project_test_preprocess_includes_path
      @standard_test_paths[:project_test_preprocess_files_path] = @configurator.project_test_preprocess_files_path
    end

    if @configurator.project_use_mocks
      @standard_test_paths[:cmock_mock_path] = @configurator.cmock_mock_path
      @standard_cmock[:cmock] = @cmock_builder.cmock
      @standard_cmock[:tool_search_paths] = Array.new(COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR)
    end
  end

  def set_standard_test_build_path
    @standard_test_paths.each do |config, path|
      @configurator.project_config_hash[config] = path
    end

    if @configurator.project_use_mocks
      @cmock_builder.cmock = @standard_cmock[:cmock]
      COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR.replace(@standard_cmock[:tool_search_paths])
    end
  end

  def set_custom_test_build_path(test_name)
    @standard_test_paths.each do |config, path|
      @configurator.project_config_hash[config] = File.join(path, test_name)
      @file_wrapper.mkdir(@configurator.project_config_hash[config])
    end 

    if @configurator.project_use_mocks
      cmock_config = @cmock_builder.cmock_config.clone
      cmock_config[:mock_path] = @configurator.project_config_hash[:cmock_mock_path]
      # fff replace @cmock_bulder.cmock from CMock during setup
      # we have to create new CMock of fff or other mock generator
      mock_generator = @cmock_builder.clone_mock_generator(cmock_config)
      @cmock_builder.cmock = mock_generator
      COLLECTION_PATHS_TEST_SUPPORT_SOURCE_INCLUDE_VENDOR.map! do |path|
        path == @standard_test_paths[:cmock_mock_path] ? @configurator.cmock_mock_path : path
      end
    end
  end

  def setup_and_invoke(tests, context=TEST_SYM, options={:force_run => true, :build_only => false})

    @tests = tests

    backup_standard_test_paths()
    @project_config_manager.process_test_config_change

    @tests.each do |test|
      # announce beginning of test run
      header = "Test '#{File.basename(test)}'"
      @streaminator.stdout_puts("\n\n#{header}\n#{'-' * header.length}")

      begin
        @plugin_manager.pre_test( test )
        test_name ="#{File.basename(test)}".chomp('.c')
        def_test_key="defines_#{test_name.downcase}"

        if @configurator.project_config_hash.has_key?(def_test_key.to_sym) || @configurator.defines_use_test_definition
          @streaminator.stdout_puts("Updating test definitions and build path for #{test_name}", Verbosity::NORMAL)
          defs_bkp = Array.new(COLLECTION_DEFINES_TEST_AND_VENDOR)
          tst_defs_cfg = Array.new(defs_bkp)
          if @configurator.project_config_hash.has_key?(def_test_key.to_sym)
            tst_defs_cfg.replace(@configurator.project_config_hash[def_test_key.to_sym])
            tst_defs_cfg .concat(COLLECTION_DEFINES_VENDOR) if COLLECTION_DEFINES_VENDOR
          end
          if @configurator.defines_use_test_definition
            tst_defs_cfg << File.basename(test, ".*").strip.upcase.sub(/@.*$/, "")
          end
          COLLECTION_DEFINES_TEST_AND_VENDOR.replace(tst_defs_cfg)
          set_custom_test_build_path(test_name)
        end

        # collect up test fixture pieces & parts
        runner       = @file_path_utils.form_runner_filepath_from_test( test )
        mock_list    = @preprocessinator.preprocess_test_and_invoke_test_mocks( test )
        sources      = @test_invoker_helper.extract_sources( test )
        extras       = @configurator.collection_test_fixture_extra_link_objects
        core         = [test] + mock_list + sources
        objects      = @file_path_utils.form_test_build_objects_filelist( [runner] + core + extras ).uniq
        results_pass = @file_path_utils.form_pass_results_filepath( test )
        results_fail = @file_path_utils.form_fail_results_filepath( test )

        # identify all the objects shall not be linked and then remove them from objects list.
        no_link_objects = @file_path_utils.form_test_build_objects_filelist(@preprocessinator.preprocess_shallow_source_includes( test ))
        objects = objects.uniq - no_link_objects

        @project_config_manager.process_test_defines_change(@project_config_manager.filter_internal_sources(sources))

        # clean results files so we have a missing file with which to kick off rake's dependency rules
        @test_invoker_helper.clean_results( {:pass => results_pass, :fail => results_fail}, options )

        # load up auxiliary dependencies so deep changes cause rebuilding appropriately
        @test_invoker_helper.process_deep_dependencies( core ) do |dependencies_list|
          @dependinator.load_test_object_deep_dependencies( dependencies_list )
        end

        # tell rake to create test runner if needed
        @task_invoker.invoke_test_runner( runner )

        # enhance object file dependencies to capture externalities influencing regeneration
        @dependinator.enhance_test_build_object_dependencies( objects )

        # associate object files with executable
        @dependinator.enhance_test_executable_dependencies( test, objects )

        # build test objects
        @task_invoker.invoke_test_objects( objects )

        # if the option build_only has been specified, build only the executable
        # but don't run the test
        if (options[:build_only])
          executable = @file_path_utils.form_test_executable_filepath( test )
          @task_invoker.invoke_test_executable( executable )
        else
          # 3, 2, 1... launch
          @task_invoker.invoke_test_results( results_pass )
        end
      rescue => e
        @build_invoker_utils.process_exception( e, context )
      ensure
        @plugin_manager.post_test( test )
        # restore the project test defines
        if @configurator.project_config_hash.has_key?(def_test_key.to_sym) || @configurator.defines_use_test_definition
          COLLECTION_DEFINES_TEST_AND_VENDOR.replace(defs_bkp)
          set_standard_test_build_path()
          @streaminator.stdout_puts("Restored defines and build path to standard", Verbosity::NORMAL)
        end
      end

      # store away what's been processed
      @mocks.concat( mock_list )
      @sources.concat( sources )

      @task_invoker.first_run = false
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
