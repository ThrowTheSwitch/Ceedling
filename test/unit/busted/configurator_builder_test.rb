require File.dirname(__FILE__) + '/../unit_test_helper'
require 'configurator_builder'
require 'yaml'
require 'constants' # for Verbosity constants class


class ConfiguratorBuilderTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:project_config_manager, :file_system_utils, :file_wrapper)
    create_mocks(:file_list)
    @builder = ConfiguratorBuilder.new(objects)
  end

  def teardown
  end

  ############# insert tool names #############

  should "insert tool names into tools config from their config hash key names" do
    in_hash = {
      :tools => { 
        :thinger => {:executable => '/bin/thinger', :arguments => ['-E']},
        :zinger => {:executable => 'zinger', :arguments => ['-option', '-flag']}
    }}
    
    @builder.populate_tool_names(in_hash)
    
    assert_equal('thinger', in_hash[:tools][:thinger][:name])
    assert_equal('/bin/thinger', in_hash[:tools][:thinger][:executable])
    assert_equal(['-E'], in_hash[:tools][:thinger][:arguments])

    assert_equal('zinger', in_hash[:tools][:zinger][:name])
    assert_equal('zinger', in_hash[:tools][:zinger][:executable])
    assert_equal(['-option', '-flag'], in_hash[:tools][:zinger][:arguments])
    
  end

  ############# flattenify #############
    
  should "flattenify keys and values contained in yaml and not blow up on empty top-level entries" do
    
    config = %Q{
      ---
      :project:
        :name: App
        :dirs:
          - .
          - gui
          - ../common/modules/

      :extension:
        :obj: .o
        :bin: .out
        :dep: .d

      :cmock:
        :mock_path: build/tests/mocks/
        :plugins:
          - cexception
          - ignore

      :empty:

      ...
      }.left_margin
    hash = @builder.flattenify( YAML.load(config) )
    
    assert_equal(hash[:project_name], 'App')
    assert_equal(hash[:project_dirs], ['.', 'gui', '../common/modules/'])
    
    assert_equal(hash[:extension_obj], '.o')
    assert_equal(hash[:extension_bin], '.out')
    assert_equal(hash[:extension_dep], '.d')
    
    assert_equal(hash[:cmock_mock_path], 'build/tests/mocks/')
    assert_equal(hash[:cmock_plugins], ['cexception', 'ignore'])    
  end

  ############# defaults #############

  should "populate all defaults for unspecified entries in config hash" do
    # pass in blank configuration and ensure all defaults populated
    assert_equal(DEFAULT_CEEDLING_CONFIG, @builder.populate_defaults({}))    
  end

  should "not default any entry in input config hash that's already been set to something" do
    in_hash = {
      # all set to something other than defaults in source
      :project_use_exceptions => false,
      :project_use_mocks => false,
      :project_use_preprocessor => true,
      :project_use_auxiliary_dependencies => true,
      :project_test_file_prefix => 'yeehaw_',
      :project_verbosity => Verbosity::OBNOXIOUS,

      :paths_support => ['path/support'],
      :paths_include => ['path/include'],
                     
      :defines_test => ['TEST_DEFINE'],
      :defines_source => ['SOURCE_DEFINE'],

      :extension_header => '.H',
      :extension_source => '.C',
      :extension_object => '.O',
      :extension_executable => '.exe',
      :extension_testpass => '.p',
      :extension_testfail => '.f',
      :extension_dependencies => '.dep',
  
      :unity_int_width => 16,
      :unity_exclude_float => true,
      :unity_float_type => 'double',    
      :unity_float_precision => '0.0000001f',
                                          
      :test_runner_includes => ['Common.h'],
      :test_runner_file_suffix => '_walker',
      
      :tools_includes_preprocessor  => {:name => 'doohicky', :executable => 'exe', :arguments => []},
      :tools_file_preprocessor      => {:name => 'doohicky', :executable => 'exe', :arguments => []},
      :tools_dependencies_generator => {:name => 'doohicky', :executable => 'exe', :arguments => []},
    }
    
    assert_equal(in_hash, @builder.populate_defaults(in_hash))
  end

  should "merge complex/nested values within default values" do
    in_hash = { 
      :tools_file_preprocessor => {:executable => '/bin/app'},
      :tools_dependencies_generator => {:arguments => ['-option', '-flag']}
    }
    
    out_hash = @builder.populate_defaults(in_hash)
    
    # default executable has been overwritten but default arguments remain
    assert_equal('/bin/app', out_hash[:tools_file_preprocessor][:executable])
    assert_equal(DEFAULT_FILE_PREPROCESSOR_TOOL[:arguments], out_hash[:tools_file_preprocessor][:arguments])
    
    # default arguments have been overwritten but default executable remains
    assert_equal(DEFAULT_DEPENDENCIES_GENERATOR_TOOL[:executable], out_hash[:tools_dependencies_generator][:executable])
    assert_equal(['-option', '-flag'], out_hash[:tools_dependencies_generator][:arguments])    
  end

  should "preserve in defaulted configuration anything in input that's not a handled default" do
    in_hash = { 
      :yo => 'mama',
      :be => 'all you can be'
    }
    
    assert_equal(DEFAULT_CEEDLING_CONFIG.merge(in_hash), @builder.populate_defaults(in_hash))
  end

  ############# clean #############

  should "tidy up configuration values" do
  	in_hash = {
  	  :test_runner_includes => ['common', 'types.h', 'thing.H'],
  	  :extension_header => '.h',
  	  }

  	@builder.clean(in_hash)

  	assert_equal(['common.h', 'types.h', 'thing.h'], in_hash[:test_runner_includes])
  end

  ############# build paths #############

  should "construct and collect simple build paths" do
    in_hash = {
      :project_build_root => 'files/build'}
    expected_build_paths = [
      'files/build/tests/runners',
      'files/build/tests/results',
      'files/build/tests/out',
      'files/build/tests/artifacts',
      'files/build/release/out',
      'files/build/release/artifacts',]

    out_hash = @builder.set_build_paths(in_hash)

    assert_equal(expected_build_paths.sort, out_hash[:project_build_paths].sort)
    
    assert_equal(expected_build_paths[0], out_hash[:project_test_runners_path])
    assert_equal(expected_build_paths[1], out_hash[:project_test_results_path])
    assert_equal(expected_build_paths[2], out_hash[:project_test_build_output_path])
    assert_equal(expected_build_paths[3], out_hash[:project_test_artifacts_path])
    assert_equal(expected_build_paths[4], out_hash[:project_release_build_output_path])
    assert_equal(expected_build_paths[5], out_hash[:project_release_artifacts_path])
  end

  should "construct and collect build paths including mocks path" do
    in_hash = {
      :project_build_root => 'files/build',
      :project_use_mocks => true,
      :cmock_mock_path => 'files/build/tests/mocks'}
      expected_build_paths = [
        'files/build/tests/runners',
        'files/build/tests/results',
        'files/build/tests/out',
        'files/build/tests/mocks',
        'files/build/tests/artifacts',
        'files/build/release/out',
        'files/build/release/artifacts',]
  
    out_hash = @builder.set_build_paths(in_hash)
  
    assert_equal(expected_build_paths.sort, out_hash[:project_build_paths].sort)

    assert_equal(expected_build_paths[0], out_hash[:project_test_runners_path])
    assert_equal(expected_build_paths[1], out_hash[:project_test_results_path])
    assert_equal(expected_build_paths[2], out_hash[:project_test_build_output_path])
    assert_equal(expected_build_paths[4], out_hash[:project_test_artifacts_path])
    assert_equal(expected_build_paths[5], out_hash[:project_release_build_output_path])
    assert_equal(expected_build_paths[6], out_hash[:project_release_artifacts_path])
  end

  should "construct and collect build paths including preprocessing paths" do
    in_hash = {
      :project_build_root => 'files/build',
      :project_use_preprocessor => true}
      expected_build_paths = [
        'files/build/tests/runners',
        'files/build/tests/results',
        'files/build/tests/out',
        'files/build/tests/preprocess/includes',
        'files/build/tests/preprocess/files',
        'files/build/temp',
        'files/build/tests/artifacts',
        'files/build/release/out',
        'files/build/release/artifacts',]
  
    out_hash = @builder.set_build_paths(in_hash)
  
    assert_equal(expected_build_paths.sort, out_hash[:project_build_paths].sort)

    assert_equal(expected_build_paths[0], out_hash[:project_test_runners_path])
    assert_equal(expected_build_paths[1], out_hash[:project_test_results_path])
    assert_equal(expected_build_paths[2], out_hash[:project_test_build_output_path])
    assert_equal(expected_build_paths[3], out_hash[:project_test_preprocess_includes_path])
    assert_equal(expected_build_paths[4], out_hash[:project_test_preprocess_files_path])
    assert_equal(expected_build_paths[5], out_hash[:project_temp_path])
    assert_equal(expected_build_paths[6], out_hash[:project_test_artifacts_path])
    assert_equal(expected_build_paths[7], out_hash[:project_release_build_output_path])
    assert_equal(expected_build_paths[8], out_hash[:project_release_artifacts_path])
  end

  should "construct and collect build paths including dependencies paths" do
    in_hash = {
      :project_build_root => 'files/build',
      :project_use_auxiliary_dependencies => true}
      expected_build_paths = [
        'files/build/tests/runners',
        'files/build/tests/results',
        'files/build/tests/out',
        'files/build/tests/dependencies',
        'files/build/tests/artifacts',
        'files/build/release/out',
        'files/build/release/artifacts',]
  
    out_hash = @builder.set_build_paths(in_hash)
  
    assert_equal(expected_build_paths.sort, out_hash[:project_build_paths].sort)

    assert_equal(expected_build_paths[0], out_hash[:project_test_runners_path])
    assert_equal(expected_build_paths[1], out_hash[:project_test_results_path])
    assert_equal(expected_build_paths[2], out_hash[:project_test_build_output_path])
    assert_equal(expected_build_paths[3], out_hash[:project_test_dependencies_path])
    assert_equal(expected_build_paths[4], out_hash[:project_test_artifacts_path])
    assert_equal(expected_build_paths[5], out_hash[:project_release_build_output_path])
    assert_equal(expected_build_paths[6], out_hash[:project_release_artifacts_path])
  end

  ############# rakefile components #############

  should "set rakefile components needed to load the project" do
    in_hash = {}
    out_hash = @builder.set_rakefile_components(in_hash)
    assert_equal(
      ["#{CEEDLING_LIB}rules.rake",
       "#{CEEDLING_LIB}tasks.rake",
       "#{CEEDLING_LIB}tasks_filesystem.rake"].sort,
      out_hash[:project_rakefile_component_files].sort)
    
    in_hash = {:project_use_mocks => true}
    out_hash = @builder.set_rakefile_components(in_hash)
    assert_equal(
      ["#{CEEDLING_LIB}rules.rake",
       "#{CEEDLING_LIB}tasks.rake",
       "#{CEEDLING_LIB}rules_cmock.rake",
       "#{CEEDLING_LIB}tasks_filesystem.rake"].sort,
      out_hash[:project_rakefile_component_files].sort)

    in_hash = {:project_use_preprocessor => true}
    out_hash = @builder.set_rakefile_components(in_hash)
    assert_equal(
      ["#{CEEDLING_LIB}rules.rake",
       "#{CEEDLING_LIB}tasks.rake",
       "#{CEEDLING_LIB}rules_preprocess.rake",
       "#{CEEDLING_LIB}tasks_filesystem.rake"].sort,
      out_hash[:project_rakefile_component_files].sort)
    
    in_hash = {:project_use_auxiliary_dependencies => true}
    out_hash = @builder.set_rakefile_components(in_hash)
    assert_equal(
      ["#{CEEDLING_LIB}rules.rake",
       "#{CEEDLING_LIB}tasks.rake",
       "#{CEEDLING_LIB}rules_aux_dependencies.rake",
       "#{CEEDLING_LIB}tasks_filesystem.rake"].sort,
      out_hash[:project_rakefile_component_files].sort)

    in_hash = {:project_use_mocks => true, :project_use_preprocessor => true, :project_use_auxiliary_dependencies => true}
    out_hash = @builder.set_rakefile_components(in_hash)
    assert_equal(
      ["#{CEEDLING_LIB}rules.rake",
       "#{CEEDLING_LIB}tasks.rake",
       "#{CEEDLING_LIB}rules_cmock.rake",
       "#{CEEDLING_LIB}rules_preprocess.rake",
       "#{CEEDLING_LIB}rules_aux_dependencies.rake",
       "#{CEEDLING_LIB}tasks_filesystem.rake"].sort,
      out_hash[:project_rakefile_component_files].sort)
  end

  ############# source and test include paths #############

  should "collect all source and test include paths without optional mocks and exception paths" do
    in_hash = {
        :project_use_exceptions => false,
        :project_use_mocks => false,        
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :paths_include => ['files/source/include'],
        }
        
    expected_include_paths = ['files/source', 'files/source/include', 'files/tests', 'files/tests/support', "#{CEEDLING_VENDOR}unity/src"]

    out_hash = @builder.collect_test_and_source_include_paths(in_hash)

    assert_equal(expected_include_paths.sort, out_hash[:paths_test_and_source_include].sort)
  end

  should "collect all source and test include paths without optional mocks paths but with exception path" do
    in_hash = {
        :project_use_exceptions => true,
        :project_use_mocks => false,        
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :paths_include => ['files/source/include'],
        }
        
    expected_include_paths = ['files/source', 'files/source/include', 'files/tests', 'files/tests/support', "#{CEEDLING_VENDOR}unity/src", "#{CEEDLING_VENDOR}c_exception/lib"]

    out_hash = @builder.collect_test_and_source_include_paths(in_hash)

    assert_equal(expected_include_paths.sort, out_hash[:paths_test_and_source_include].sort)
  end

  should "collect all source and test include paths with optional mocks paths but without exception path" do
    in_hash = {
        :project_use_exceptions => false,
        :project_use_mocks => true,
        :cmock_mock_path => 'files/build/mocks',
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :paths_include => ['files/source/include'],
        }
        
    expected_include_paths = ['files/source', 'files/source/include', 'files/tests', 'files/tests/support', "#{CEEDLING_VENDOR}unity/src", 'files/build/mocks']

    out_hash = @builder.collect_test_and_source_include_paths(in_hash)

    assert_equal(expected_include_paths.sort, out_hash[:paths_test_and_source_include].sort)
  end

  should "collect all source and test include paths with both optional mocks paths and exception path" do
    in_hash = {
        :project_use_exceptions => true,
        :project_use_mocks => true,
        :cmock_mock_path => 'files/build/mocks',
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :paths_include => ['files/source/include'],
        }
        
    expected_include_paths = ['files/source', 'files/source/include', 'files/tests', 'files/tests/support', "#{CEEDLING_VENDOR}unity/src", "#{CEEDLING_VENDOR}c_exception/lib", 'files/build/mocks']

    out_hash = @builder.collect_test_and_source_include_paths(in_hash)

    assert_equal(expected_include_paths.sort, out_hash[:paths_test_and_source_include].sort)
  end

  ############# source and test paths #############

  should "collect all source and test paths without optional mocks and exception paths" do
    in_hash = {
        :project_use_exceptions => false,
        :project_use_mocks => false,        
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :project_test_runners_path => 'files/build/runners',
        }
        
    expected_paths = ['files/tests', 'files/tests/support', 'files/source', 'files/build/runners', "#{CEEDLING_VENDOR}unity/src"]

    out_hash = @builder.collect_test_and_source_paths(in_hash)

    assert_equal(expected_paths.sort, out_hash[:paths_test_and_source].sort)
  end

  should "collect all source and test paths with optional mocks path but without exception path" do
    in_hash = {
        :project_use_exceptions => false,
        :project_use_mocks => true,        
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :project_test_runners_path => 'files/build/runners',
        :cmock_mock_path => 'files/build/mocks',
        }
        
    expected_paths = ['files/tests', 'files/tests/support', 'files/source', 'files/build/runners', 'files/build/mocks', "#{CEEDLING_VENDOR}unity/src"]

    out_hash = @builder.collect_test_and_source_paths(in_hash)

    assert_equal(expected_paths.sort, out_hash[:paths_test_and_source].sort)
  end

  should "collect all source and test paths without optional mocks path but with exception path" do
    in_hash = {
        :project_use_exceptions => true,
        :project_use_mocks => false,
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :project_test_runners_path => 'files/build/runners',
        }
        
    expected_paths = ['files/tests', 'files/tests/support', 'files/source', 'files/build/runners', "#{CEEDLING_VENDOR}c_exception/lib", "#{CEEDLING_VENDOR}unity/src"]

    out_hash = @builder.collect_test_and_source_paths(in_hash)

    assert_equal(expected_paths.sort, out_hash[:paths_test_and_source].sort)
  end

  should "collect all source and test paths with both optional mocks path and exception path" do
    in_hash = {
        :project_use_exceptions => true,
        :project_use_mocks => true,
        :paths_test => ['files/tests'],
        :paths_support => ['files/tests/support'],
        :paths_source => ['files/source'],
        :project_test_runners_path => 'files/build/runners',
        :cmock_mock_path => 'files/build/mocks',
        }
        
    expected_paths = ['files/tests', 'files/tests/support', 'files/source', 'files/build/runners', 'files/build/mocks', "#{CEEDLING_VENDOR}c_exception/lib", "#{CEEDLING_VENDOR}unity/src"]

    out_hash = @builder.collect_test_and_source_paths(in_hash)

    assert_equal(expected_paths.sort, out_hash[:paths_test_and_source].sort)
  end
  
  ############# all tests #############
  
  should "collect all tests" do
    in_hash = {
      :paths_test => ['tests/main', 'tests/other/**'],
      :project_test_file_prefix => 'Test',
      :extension_source => '.c'}
    
    @file_wrapper.expects.instantiate_file_list.returns(@file_list)
    
    @file_list.expects.include('tests/main/Test*.c')
    @file_list.expects.include('tests/other/**/Test*.c')
    
    assert_equal({:collection_all_tests => @file_list}, @builder.collect_tests(in_hash))
  end

  ############# all source #############

  should "collect all source" do
    in_hash = {
      :paths_source => ['files/source', 'files/modules/**'],
      :extension_source => '.c'}
    
    @file_wrapper.expects.instantiate_file_list.returns(@file_list)
    
    @file_list.expects.include('files/source/*.c')
    @file_list.expects.include('files/modules/**/*.c')
    
    assert_equal({:collection_all_source => @file_list}, @builder.collect_source(in_hash))
  end

  ############# all headers #############

  should "collect all headers" do
    in_hash = {
      :paths_support => ['files/test/support/**'],
      :paths_include => ['files/source/include'],
      :paths_source => ['files/source', 'files/modules/**'],
      :extension_header => '.h'}
    
    @file_wrapper.expects.instantiate_file_list.returns(@file_list)
    
    @file_list.expects.include('files/test/support/**/*.h')
    @file_list.expects.include('files/source/*.h')
    @file_list.expects.include('files/modules/**/*.h')
    @file_list.expects.include('files/source/include/*.h')
    
    assert_equal({:collection_all_headers => @file_list}, @builder.collect_headers(in_hash))
  end

  ############# collect environment files #############

  should "collect environment source files plus project file but no user project file" do
    @project_config_manager.expects.main_project_filepath.returns('/home/project/config/project.yaml')
    @project_config_manager.expects.user_project_filepath.returns('')
    
    out_hash = @builder.collect_code_generation_dependencies
    
    assert_equal(
      ["#{CEEDLING_RELEASE}build.info",
       "#{CEEDLING_VENDOR}cmock/release/build.info",
       '/home/project/config/project.yaml'].sort,
      out_hash[:collection_code_generation_dependencies].sort)
  end

  should "collect environment source files plus project file and user project file" do    
    @project_config_manager.expects.main_project_filepath.returns('/home/project/config/project.yaml')
    @project_config_manager.expects.user_project_filepath.returns('/home/project/config/user.yaml')
    
    out_hash = @builder.collect_code_generation_dependencies
    
    assert_equal(
      ["#{CEEDLING_RELEASE}build.info",
       "#{CEEDLING_VENDOR}cmock/release/build.info",
       '/home/project/config/project.yaml',
       '/home/project/config/user.yaml'].sort,
      out_hash[:collection_code_generation_dependencies].sort)
  end

  ############# expand path globs #############

  should "inspect each element of paths in config hash and expand any and all globs into a collection" do
    
    create_mocks(:paths_collection1, :paths_collection2, :paths_collection3)
    in_hash = {
      :path_dummy => [],
      :paths_custom => ['oh', 'yeah'],
      :paths_source => ['files/source', 'files/modules/**'],
      :paths_to_destruction => ['paths/sin', 'paths/avarice'],
      :whatever => 'blah blah blah',
      }
    
    @file_system_utils.expects.collect_paths(['oh', 'yeah']).returns(@paths_collection1)
    @file_system_utils.expects.collect_paths(['files/source', 'files/modules/**']).returns(@paths_collection2)
    @file_system_utils.expects.collect_paths(['paths/sin', 'paths/avarice']).returns(@paths_collection3)
    
    out_hash = @builder.expand_all_path_globs(in_hash)

    assert_equal(@paths_collection1, out_hash[:collection_paths_custom])
    assert_equal(@paths_collection2, out_hash[:collection_paths_source])
    assert_equal(@paths_collection3, out_hash[:collection_paths_to_destruction])    
  end
  
end

