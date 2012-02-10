require File.dirname(__FILE__) + '/../unit_test_helper'
require 'configurator_validator'


class ConfiguratorValidatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:file_wrapper, :stream_wrapper, :system_wrapper)
    @validator = ConfiguratorValidator.new(objects)
  end

  def teardown
  end
  
  ######### exists? ##########
  
  should "verify valid paths into config hash" do
    # deeper than real config, but let's exercise it just for fun
    config = {
      :root => {
        :level2 => {
          :level3 => {
            :value => 'well, hello there'
      }}}}
    
    assert(@validator.exists?( config, :root ))
    assert(@validator.exists?( config, :root, :level2 ))
    assert(@validator.exists?( config, :root, :level2, :level3 ))
    assert(@validator.exists?( config, :root, :level2, :level3, :value ))
  end

  should "complain about non-existent paths into config hash" do
    # deeper than real config, but let's exercise it just for fun
    config = {
      :root => {
        :level2 => {
          :level3 => {
            :value => 'well, hello there'
      }}}}
    
    @stream_wrapper.expects.stderr_puts("ERROR: Required config file entry [:nope] does not exist.")
    @stream_wrapper.expects.stderr_puts("ERROR: Required config file entry [:root][:sorry] does not exist.")
    @stream_wrapper.expects.stderr_puts("ERROR: Required config file entry [:root][:level2][:no_can_do] does not exist.")
    @stream_wrapper.expects.stderr_puts("ERROR: Required config file entry [:root][:level2][:level3][:wrong] does not exist.")
    
    assert_equal(false, @validator.exists?( config, :nope ))
    assert_equal(false, @validator.exists?( config, :root, :sorry ))
    assert_equal(false, @validator.exists?( config, :root, :level2, :no_can_do ))
    assert_equal(false, @validator.exists?( config, :root, :level2, :level3, :wrong ))
  end


  ######### validate_path_list ##########
  
  should "fail for missing entries in config when validating path entries" do
    config = {:project => {}}
    
    assert_equal(false, @validator.validate_path_list(config, :project, :build_root))
  end
  
  should "complain about non-existent paths for given path entries in config" do
    config = {:project => {:build_root => 'project/build'}}
    
    @file_wrapper.expects.exist?('project/build').returns(false)
    
    @stream_wrapper.expects.stderr_puts("ERROR: Config path [:project][:build_root]['project/build'] does not exist on disk.")
    
    assert_equal(false, @validator.validate_path_list(config, :project, :build_root))
  end

  should "successfully validate paths for given path entries in config" do
    config = {
      :project => {
        :test_paths => ['main/test', 'modules/*/test']
      }}
  
    @file_wrapper.expects.exist?('main/test').returns(true)
    @file_wrapper.expects.exist?('modules').returns(true)
        
    assert(@validator.validate_path_list(config, :project, :test_paths))
  end
  
  ######### validate_filepath ##########
  
  should "fail for missing entry in config when validating filepath" do
    config = {
      :tools => {
        :thinger => {}
      }}
    
    assert_equal(false, @validator.validate_filepath(config, :tools, :thinger, :executable))
  end

  should "complain about non-existent explicit filepath" do
    config = {
      :tools => {
        :thinger => {
          # specific path, check it
          :executable => 'bin/app.exe'
      }}}
    
    @file_wrapper.expects.exist?('bin/app.exe').returns(false)
    
    @stream_wrapper.expects.stderr_puts("ERROR: Config filepath [:tools][:thinger][:executable]['bin/app.exe'] does not exist on disk.") 
    
    assert_equal(false, @validator.validate_filepath(config, :tools, :thinger, :executable))
  end

  should "complain about non-existent filepath in search paths" do
    config = {
      :tools => {
        :thinger => {
          # specific path, check it
          :executable => 'app'
      }}}
    
      @system_wrapper.expects.search_paths.returns(['bin', 'c:/program files/app', 'tools/thingamabob'])

      @file_wrapper.expects.exist?('bin/app').returns(false)
      @file_wrapper.expects.exist?('c:/program files/app/app').returns(false)
      @file_wrapper.expects.exist?('tools/thingamabob/app').returns(false)
    
    @stream_wrapper.expects.stderr_puts("ERROR: Config filepath [:tools][:thinger][:executable]['app'] does not exist in system search paths.") 
    
    assert_equal(false, @validator.validate_filepath(config, :tools, :thinger, :executable))
  end

  should "successfully validate filepath containing tool executor argument replacement" do
    config = {
      :tools => {
        :thinger => {
          # specific path, check it
          :executable => '${11}'
      }}}
    
    assert(@validator.validate_filepath(config, :tools, :thinger, :executable))
  end

  should "successfully validate explicit filepath" do
    config = {
      :tools => {
        :thinger => {
          # specific path, check it
          :executable => 'bin/app.exe'
      }}}
    
    @file_wrapper.expects.exist?('bin/app.exe').returns(true)
    
    assert(@validator.validate_filepath(config, :tools, :thinger, :executable))
  end

  should "successfully validate search path filepath" do
    config = {
      :tools => {
        :thinger => {
          # no path, go looking in search paths
          :executable => 'gcc'
      }}}
    
    @system_wrapper.expects.search_paths.returns(['/usr/bin', 'c:/program files/app', 'tools'])
    
    @file_wrapper.expects.exist?('/usr/bin/gcc').returns(false)
    @file_wrapper.expects.exist?('c:/program files/app/gcc').returns(false)
    @file_wrapper.expects.exist?('tools/gcc').returns(true)
    
    assert(@validator.validate_filepath(config, :tools, :thinger, :executable))
  end
  
end
