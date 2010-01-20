require File.dirname(__FILE__) + '/../unit_test_helper'
require 'project_file_loader'
require 'yaml'

class ProjectFileLoaderTest < Test::Unit::TestCase

  def setup
    @objects = create_mocks(:yaml_wrapper, :stream_wrapper, :file_wrapper)
    @loader = ProjectFileLoader.new(@objects)

    # preserve/clear out environment variable
    @environment_variable = ''
    if (not ENV['CEEDLING_PROJECT_FILE'].nil?)
      @environment_variable = ENV['CEEDLING_PROJECT_FILE']
      ENV.delete('CEEDLING_PROJECT_FILE')
    end
  end

  def teardown
    ENV['CEEDLING_PROJECT_FILE'] = @environment_variable if not @environment_variable.empty?
  end
  

  ### find project file ###
  
  should "return DEFAULT_CEEDLING_PROJECT_FILE if it exists" do
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_PROJECT_FILE).returns(true)
    
     @loader.find_project_file
    
    assert_equal(DEFAULT_CEEDLING_PROJECT_FILE, @loader.project_file)
  end

  should "return project file specified in environment variable CEEDLING_PROJECT_FILE if it exists" do
    test_config_file = 'tests/config.yml'
    
    ENV['CEEDLING_PROJECT_FILE'] = test_config_file
    
    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(test_config_file).returns(true)

    @loader.find_project_file
    
    assert_equal(test_config_file, @loader.project_file)
  end

  should "raise if a test project file cannot be found on disk" do
    test_config_file = 'files/config/tests.yml'
    
    ENV['CEEDLING_PROJECT_FILE'] = test_config_file

    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_PROJECT_FILE).returns(false)
    @file_wrapper.expects.exists?(test_config_file).returns(false)
    
    @stream_wrapper.expects.stderr_puts('Found no test project file (*.yml)')
    
    assert_raise(RuntimeError) { @loader.find_project_file }
  end

  should "raise if default test project file cannot be found on disk and no environment variable is set" do

    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_PROJECT_FILE).returns(false)
    
    @stream_wrapper.expects.stderr_puts('Found no test project file (*.yml)')
    
    assert_raise(RuntimeError) { @loader.find_project_file }
  end

  ### load project file ###

  should "load yaml file" do
    yaml = {:config => []}

    @file_wrapper.expects.exists?(DEFAULT_CEEDLING_PROJECT_FILE).returns(true)
    @yaml_wrapper.expects.load(DEFAULT_CEEDLING_PROJECT_FILE).returns(yaml)
    
    @loader.find_project_file
    @loader.load_project
  end

end

