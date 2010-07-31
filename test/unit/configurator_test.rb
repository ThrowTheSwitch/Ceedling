require File.dirname(__FILE__) + '/../unit_test_helper'
require 'configurator'


class ConfiguratorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator_helper, :configurator_builder, :configurator_plugins, :yaml_wrapper)
    create_mocks(:test_hash)
    @configurator = Configurator.new(objects)
    
    @test_config = {}
  end

  def teardown
  end


  ############# verbosity ##############
  
  should "set project config and cmock config verbosity levels" do
    assert_nil(@configurator.project_config_hash[:project_verbosity])
    assert_nil(@configurator.cmock_config_hash[:verbosity])
    
    @configurator.set_verbosity(5)
    
    assert_equal(5, @configurator.project_config_hash[:project_verbosity])
    assert_equal(5, @configurator.cmock_config_hash[:verbosity])
  end
  
  ############# standardize paths #############
  
  should "standardize all paths" do
    in_hash = {
      :project => {:build_root => "files\\dir\\dir/"},
      :paths => {
        :yellow_brick => ["root\\subdir\\dir\\", "files/modules/tests", "source\\modules"],
        :destruction => ["stuff/"]
        },
      :tools => {
        :hammer => {:executable => "gcc"},
        :ratchet => {:executable => "\\bin\\cpp"}
        },
      :plugins => {:base_path => "project\\plugins"}
      }
  
    @configurator.standardize_paths(in_hash)
  
    assert_equal('files/dir/dir', in_hash[:project][:build_root])
    
    assert_equal(["root/subdir/dir", "files/modules/tests", "source/modules"], in_hash[:paths][:yellow_brick])
    assert_equal(["stuff"], in_hash[:paths][:destruction])
    
    assert_equal('gcc', in_hash[:tools][:hammer][:executable])
    assert_equal('/bin/cpp', in_hash[:tools][:ratchet][:executable])
    
    assert_equal('project/plugins', in_hash[:plugins][:base_path])
  end
  
  ############# validate ##############

  should "successfully validate configuration" do
    @configurator_helper.expects.validate_required_sections(@test_config).returns(true)
    @configurator_helper.expects.validate_required_section_values(@test_config).returns(true)
    @configurator_helper.expects.validate_paths(@test_config).returns(true)
    @configurator_helper.expects.validate_tools(@test_config).returns(true)
    
    @configurator.validate(@test_config)
  end
  
  should "immediately raise if top-level configuration entries are missing" do
    @configurator_helper.expects.validate_required_sections(@test_config).returns(false)
    assert_raise(RuntimeError) { @configurator.validate(@test_config) }
  end

  should "validate everything and complain about section values" do
    @configurator_helper.expects.validate_required_sections(@test_config).returns(true)
    @configurator_helper.expects.validate_required_section_values(@test_config).returns(false)
    @configurator_helper.expects.validate_paths(@test_config).returns(true)
    @configurator_helper.expects.validate_tools(@test_config).returns(true)
    
    assert_raise(RuntimeError) { @configurator.validate(@test_config) }
  end

  should "validate everything and complain about paths" do
    @configurator_helper.expects.validate_required_sections(@test_config).returns(true)
    @configurator_helper.expects.validate_required_section_values(@test_config).returns(true)
    @configurator_helper.expects.validate_paths(@test_config).returns(false)
    @configurator_helper.expects.validate_tools(@test_config).returns(true)
    
    assert_raise(RuntimeError) { @configurator.validate(@test_config) }
  end

  should "validate everything and complain about tools" do
    @configurator_helper.expects.validate_required_sections(@test_config).returns(true)
    @configurator_helper.expects.validate_required_section_values(@test_config).returns(true)
    @configurator_helper.expects.validate_paths(@test_config).returns(true)
    @configurator_helper.expects.validate_tools(@test_config).returns(false)
    
    assert_raise(RuntimeError) { @configurator.validate(@test_config) }
  end

  ############# insert cmock defaults ##############

  should "insert into provided config hash necessary default cmock settings" do
    config = { # no :cmock parent
      :project => {
        :build_root => 'project/build',
        :verbosity => 10
        }
      } 
    
    expected = {
      :project => {
        :build_root => 'project/build',
        :verbosity => 10
        },
      :cmock => {
        :mock_prefix => 'Mock',
        :mock_path => 'project/build/tests/mocks',
        :enforce_strict_ordering => true,
        :verbosity => 10,
        }
      }
    
    @configurator.populate_cmock_defaults(config)
    
    assert_equal(expected, config)
  end

  should "not override cmock settings already in configuration hash" do
    config = {
      :project => {
        :verbosity => 0
        },
      :cmock => {
        :mock_prefix => 'mock_',
        :mock_path => 'foo/bar/mocks',
        :enforce_strict_ordering => false,
        :verbosity => 3,
        }
      } 
    
    expected = config.clone
    
    @configurator.populate_cmock_defaults(config)
    
    assert_equal(expected, config)
  end


  ############# build configuration ##############
      
  should "build up configuration and constantize and create accessor methods from it" do
    # prep before hashification
    @configurator_builder.expects.populate_tool_names(@test_config)
    
    # set environment variables
    @configurator_helper.expects.set_environment_variables(@test_config)
    
    # flattenify the config object
    @configurator_builder.expects.flattenify(@test_config).returns(@test_hash)

    # insert info into configuration
    @configurator_builder.expects.populate_defaults(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)
    
    # do some housekeeping
    @configurator_builder.expects.clean(@test_hash)

    # build up configuration
    @configurator_builder.expects.set_build_paths(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # build up configuration
    @configurator_builder.expects.set_rakefile_components(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # build up configuration
    @configurator_builder.expects.collect_test_and_source_include_paths(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # build up configuration
    @configurator_builder.expects.collect_test_and_source_paths(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)
    
    # build up configuration
    @configurator_builder.expects.collect_tests(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # build up configuration
    @configurator_builder.expects.collect_source(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # build up configuration
    @configurator_builder.expects.collect_headers(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # build up configuration
    @configurator_builder.expects.collect_all_compilation_input(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)
    
    # build up configuration
    @configurator_builder.expects.collect_test_defines(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)
    
    # build up configuration
    @configurator_builder.expects.collect_code_generation_dependencies.returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)
    
    # expand paths
    @configurator_builder.expects.expand_all_path_globs(@test_hash).returns(@test_hash)
    @test_hash.expects.merge!(@test_hash).returns(@test_hash)

    # provide mock hash with some keys and values to constantize & add accessor methods to configurator
    @test_hash.expects.each_pair.yields([:test_key_1, 'test_val1'], [:test_key_2, ['foo', 'bar']])
    @test_hash.expects(:[], :test_key_1).returns('test_val1')
    @test_hash.expects(:[], :test_key_2).returns(['foo', 'bar'])
    
    assert_nil(defined?(TEST_KEY_1))
    assert_nil(defined?(TEST_KEY_2))

    @configurator.build(@test_config)
    
    assert_equal('test_val1', TEST_KEY_1)
    assert_equal('test_val1', @configurator.test_key_1)
    
    assert_equal(['foo', 'bar'], TEST_KEY_2)
    assert_equal(['foo', 'bar'], @configurator.test_key_2)
  end

end
