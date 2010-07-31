
class Dependinator

  constructor :configurator, :project_config_manager, :test_includes_extractor, :file_finder, :file_path_utils, :rake_wrapper

  attr_reader :environment_prerequisites

  def assemble_environment_dependencies
    @environment_prerequisites = @configurator.collection_environment_dependencies.clone
    @environment_prerequisites << @project_config_manager.input_config_cache_filepath if @project_config_manager.input_configuration_changed_from_last_run?
  end


  def setup_object_dependencies(*files_lists)
    files_lists.each do |files_list|
      dependencies_list = @file_path_utils.form_test_dependencies_filelist(files_list)
      dependencies_list.each do |dependencies_file|
        @rake_wrapper.load_dependencies(dependencies_file)
      end
    end
  end


  def enhance_vendor_objects_with_environment_dependencies
    @rake_wrapper[@file_path_utils.form_test_build_object_filepath('unity.c')].enhance(@configurator.collection_environment_dependencies)
    @rake_wrapper[@file_path_utils.form_test_build_object_filepath('cmock.c')].enhance(@configurator.collection_environment_dependencies)      if (@configurator.project_use_mocks)
    @rake_wrapper[@file_path_utils.form_test_build_object_filepath('cexception.c')].enhance(@configurator.collection_environment_dependencies) if (@configurator.project_use_exceptions)
  end

  def enhance_object_with_environment_dependencies(sources)
    sources.each do |source|
      @rake_wrapper[@file_path_utils.form_test_build_object_filepath(source)].enhance( @environment_prerequisites )
    end
  end
  

  def setup_executable_dependencies(test)
    dependencies = []
    headers = @test_includes_extractor.lookup_includes_list(test)
    sources = @file_finder.find_source_files_from_headers(headers)
    
    dependencies = @file_path_utils.form_test_build_objects_filelist(sources + @configurator.test_fixture_link_objects)
    dependencies.include( @file_path_utils.form_runner_object_filepath_from_test(test) )
    dependencies.include( @file_path_utils.form_test_build_object_filepath(test) )
    
    dependencies.uniq!

    @rake_wrapper.create_file_task(@file_path_utils.form_test_executable_filepath(test), dependencies)
  end

end
