require File.dirname(__FILE__) + '/../unit_test_helper'
require 'project_file_loader'
require 'yaml'

class ProjectFileLoaderTest < Test::Unit::TestCase

  def setup
    @objects = create_mocks(:yaml_wrapper, :stream_wrapper, :file_wrapper)
    @loader = ProjectFileLoader.new(@objects)

    # preserve/clear out environment variable
    @env_main_project = ''
    if (not ENV['CEEDLING_MAIN_PROJECT_FILE'].nil?)
      @env_main_project = ENV['CEEDLING_MAIN_PROJECT_FILE']
      ENV.delete('CEEDLING_MAIN_PROJECT_FILE')
    end

    @env_user_project = ''
    if (not ENV['CEEDLING_USER_PROJECT_FILE'].nil?)
      @env_user_project = ENV['CEEDLING_USER_PROJECT_FILE']
      ENV.delete('CEEDLING_USER_PROJECT_FILE')
    end
  end

  def teardown
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = @env_main_project if not @env_main_project.empty?
    ENV['CEEDLING_USER_PROJECT_FILE'] = @env_user_project if not @env_user_project.empty?
  end
  

  ### find project file ###
  
  should "find both default project files if no environment variables are set and both exist on-disk" do
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(true)
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
    
    @loader.find_project_files
    
    assert_equal(DEFAULT_CEEDLING_MAIN_PROJECT_FILE, @loader.main_project_filepath)
    assert_equal(DEFAULT_CEEDLING_USER_PROJECT_FILE, @loader.user_project_filepath)
  end

  should "find only main default project files if no environment variables are set and it exist on-disk" do
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
    
    @loader.find_project_files
    
    assert_equal(DEFAULT_CEEDLING_MAIN_PROJECT_FILE, @loader.main_project_filepath)
    assert_equal('', @loader.user_project_filepath)
  end


  should "find main project file specified in environment variable if it exists on disk (no default user file found)" do
    test_config_file = 'tests/config.yml'
    
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = test_config_file
    
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(test_config_file).returns(true)
  
    @loader.find_project_files
    
    assert_equal(test_config_file, @loader.main_project_filepath)
    assert_equal('', @loader.user_project_filepath)
  end

  should "find both project files specified in environment variables if they exist on disk" do
    test_main_config_file = 'tests/project.yml'
    test_user_config_file = 'tests/user.yml'
    
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = test_main_config_file
    ENV['CEEDLING_USER_PROJECT_FILE'] = test_user_config_file
    
    @file_wrapper.expects.exists?(test_user_config_file).returns(true)
    @file_wrapper.expects.exists?(test_main_config_file).returns(true)
  
    @loader.find_project_files
    
    assert_equal(test_main_config_file, @loader.main_project_filepath)
    assert_equal(test_user_config_file, @loader.user_project_filepath)
  end


  should "raise if main project file cannot be found from environment variable or on disk" do
    test_config_file = 'files/config/tests.yml'
    
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = test_config_file
  
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(test_config_file).returns(false)
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(false)
    
    @stream_wrapper.expects.stderr_puts('Found no Ceedling project file (*.yml)')
    
    assert_raise(RuntimeError) { @loader.find_project_files }
  end
  
  should "raise if main test project file cannot be found on disk and no environment variable is set" do  
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(false)
    
    @stream_wrapper.expects.stderr_puts('Found no Ceedling project file (*.yml)')
    
    assert_raise(RuntimeError) { @loader.find_project_files }
  end

  ### load project file ###

  should "load yaml of main project file only" do
    yaml = {:config => []}
  
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(yaml)
    
    @loader.find_project_files
    
    assert_equal(yaml, @loader.load_project_file)
  end

  should "load yaml of main project file merged with user project file" do
    main_yaml   = {:config => [], :more => 'more'}
    user_yaml   = {:more => 'less', :smore => 'yum'}
    merged_yaml = {:config => [], :more => 'less', :smore => 'yum'}
  
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(true)
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(true)
  
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_MAIN_PROJECT_FILE).returns(main_yaml)
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_USER_PROJECT_FILE).returns(user_yaml)
    
    @loader.find_project_files
    
    assert_equal(merged_yaml, @loader.load_project_file)
  end

end

