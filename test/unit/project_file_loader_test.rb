require File.dirname(__FILE__) + '/../unit_test_helper'
require 'project_config_manager'
require 'yaml'

class ProjectFileLoaderTest < Test::Unit::TestCase

  def setup
    @objects = create_mocks(:yaml_wrapper, :stream_wrapper, :system_wrapper, :file_wrapper)
    @loader = ProjectFileLoader.new(@objects)
  end

  def teardown
  end
  

  ### find project file ###
  
  should "find both default project files if no environment variables are set and both exist on-disk" do
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(true)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
    
    @loader.find_project_files
    
    assert_equal(DEFAULT_CEEDLING_MAIN_PROJECT_FILE, @loader.main_project_filepath)
    assert_equal(DEFAULT_CEEDLING_USER_PROJECT_FILE, @loader.user_project_filepath)
  end

  should "find only main default project files if no environment variables are set and it exist on-disk" do
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
    
    @loader.find_project_files
    
    assert_equal(DEFAULT_CEEDLING_MAIN_PROJECT_FILE, @loader.main_project_filepath)
    assert_equal('', @loader.user_project_filepath)
  end


  should "find main project file specified in environment variable if it exists on disk (no default user file found)" do
    test_config_file = 'tests/config.yml'
    
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(test_config_file)
    @file_wrapper.expects.exist?(test_config_file).returns(true)
  
    @loader.find_project_files
    
    assert_equal(test_config_file, @loader.main_project_filepath)
    assert_equal('', @loader.user_project_filepath)
  end

  should "find both project files specified in environment variables if they exist on disk" do
    test_main_config_file = 'tests/project.yml'
    test_user_config_file = 'tests/user.yml'
    
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(test_user_config_file)
    @file_wrapper.expects.exist?(test_user_config_file).returns(true)
    
    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(test_main_config_file)
    @file_wrapper.expects.exist?(test_main_config_file).returns(true)
  
    @loader.find_project_files
    
    assert_equal(test_main_config_file, @loader.main_project_filepath)
    assert_equal(test_user_config_file, @loader.user_project_filepath)
  end


  should "raise if main project file cannot be found from environment variable or on disk" do
    test_config_file = 'files/config/tests.yml'
    
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(test_config_file)
    @file_wrapper.expects.exist?(test_config_file).returns(false)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(false)
    
    @stream_wrapper.expects.stderr_puts('Found no Ceedling project file (*.yml)')
    
    assert_raise(RuntimeError) { @loader.find_project_files }
  end
  
  should "raise if main test project file cannot be found on disk and no environment variable is set" do  

    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(false)
    
    @stream_wrapper.expects.stderr_puts('Found no Ceedling project file (*.yml)')
    
    assert_raise(RuntimeError) { @loader.find_project_files }
  end

  ### load project file ###

  should "load yaml of main project file only" do
    yaml = {:config => []}
  
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(yaml)
    
    @loader.find_project_files
    
    assert_equal(yaml, @loader.load_project_config)
  end

  should "load yaml of main project file merged with user project file" do
    main_yaml   = {:config => [], :more => 'more'}
    user_yaml   = {:more => 'less', :smore => 'yum'}
    merged_yaml = {:config => [], :more => 'less', :smore => 'yum'}
  
    @system_wrapper.expects.env_get('CEEDLING_USER_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(true)

    @system_wrapper.expects.env_get('CEEDLING_MAIN_PROJECT_FILE').returns(nil)
    @file_wrapper.expects.exist?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
  
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(main_yaml)
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(user_yaml)
    
    @loader.find_project_files
    
    assert_equal(merged_yaml, @loader.load_project_config)
  end

end

