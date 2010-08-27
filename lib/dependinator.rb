
class Dependinator

  constructor :configurator, :setupinator, :project_config_manager, :test_includes_extractor, :file_finder, :file_path_utils, :rake_wrapper


  def enhance_release_file_dependencies(files)
    @project_config_manager.input_config_changed_since_last_build( @configurator.project_release_build_cache_path, @setupinator.config_hash ) do |config_cache_filepath|
      files.each { |file| @rake_wrapper[file].enhance( [config_cache_filepath] ) }
    end
  end


  def setup_release_object_deep_dependencies(dependencies_list)
    dependencies_list.each { |dependencies_file| @rake_wrapper.load_dependencies( dependencies_file ) }
  end



  # pull together all depenendencies outside C source code (ceedling, cmock, input configuration changes) so we can trigger full rebuilds
  def assemble_test_environment_dependencies
    @test_environment_prerequisites = []

    @project_config_manager.input_config_changed_since_last_build( @configurator.project_test_build_cache_path, @setupinator.config_hash ) do |config_cache_filepath|
      @test_environment_prerequisites << config_cache_filepath
    end
  end


  def setup_test_object_dependencies(files_list)
    dependencies_list = @file_path_utils.form_test_dependencies_filelist(files_list)
    dependencies_list.each { |dependencies_file| @rake_wrapper.load_dependencies(dependencies_file) }
  end


  def enhance_test_vendor_objects_with_environment_dependencies
    # if test environment changes, make sure these guys get rebuilt
    @rake_wrapper[@file_path_utils.form_test_build_object_filepath('unity.c')].enhance(@configurator.collection_code_generation_ceedling_dependency)
    @rake_wrapper[@file_path_utils.form_test_build_object_filepath('cmock.c')].enhance(@configurator.collection_code_generation_ceedling_dependency)      if (@configurator.project_use_mocks)
    @rake_wrapper[@file_path_utils.form_test_build_object_filepath('CException.c')].enhance(@configurator.collection_code_generation_ceedling_dependency) if (@configurator.project_use_exceptions)
  end

  def enhance_test_build_object_with_environment_dependencies(sources)
    sources.each do |source|
      @rake_wrapper[@file_path_utils.form_test_build_object_filepath(source)].enhance( @test_environment_prerequisites )
    end
  end
  

  def setup_test_executable_dependencies(test)
    dependencies = []
    headers = @test_includes_extractor.lookup_includes_list(test)
    sources = @file_finder.find_source_files_from_headers(headers)
    
    dependencies = @file_path_utils.form_test_build_objects_filelist(sources + @configurator.test_fixture_link_objects) # compiled vendor dependencies
    dependencies.include( @file_path_utils.form_runner_object_filepath_from_test(test) )
    dependencies.include( @file_path_utils.form_test_build_object_filepath(test) )
    
    dependencies.uniq!

    @rake_wrapper.create_file_task(@file_path_utils.form_test_executable_filepath(test), dependencies)
  end

end
