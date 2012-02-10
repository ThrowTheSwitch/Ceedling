require File.dirname(__FILE__) + '/../unit_test_helper'
require 'configurator_helper'


class ConfiguratorHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator_validator, :system_wrapper)
    @helper = ConfiguratorHelper.new(objects)
    
    @test_config = {}
  end

  def teardown
  end


  should "do nothing if no 'environment' entry in the yaml config" do
    @helper.set_environment_variables(@test_config)
  end

  should "set environment variables from yaml config" do
    @test_config[:environment] = {
      :cov_file => 'project/artifacts/test.cov',
      :TEST_NUMBER => 101,
      :environment_var => -2
      }

    @system_wrapper.expects.env_set('TEST_NUMBER', '101')
    @system_wrapper.expects.env_set('COV_FILE', 'project/artifacts/test.cov')
    @system_wrapper.expects.env_set('ENVIRONMENT_VAR', '-2')

    @helper.set_environment_variables(@test_config)
  end


  should "return true when all top-level configuration entries are present" do
    @configurator_validator.expects.exists?(@test_config, :project).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools).returns(true)

    assert(@helper.validate_required_sections(@test_config))
  end

  should "fail if any top-level configuration entries are missing" do
    
    @configurator_validator.expects.exists?(@test_config, :project).returns(false)
    @configurator_validator.expects.exists?(@test_config, :paths).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools).returns(true)

    assert_equal(false, @helper.validate_required_sections(@test_config))
    
    @configurator_validator.expects.exists?(@test_config, :project).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths).returns(false)
    @configurator_validator.expects.exists?(@test_config, :tools).returns(true)

    assert_equal(false, @helper.validate_required_sections(@test_config))
    
    @configurator_validator.expects.exists?(@test_config, :project).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools).returns(false)

    assert_equal(false, @helper.validate_required_sections(@test_config))

    @configurator_validator.expects.exists?(@test_config, :project).returns(false)
    @configurator_validator.expects.exists?(@test_config, :paths).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools).returns(false)

    assert_equal(false, @helper.validate_required_sections(@test_config))
  end


  should "return true when all required section values are present" do
    @configurator_validator.expects.exists?(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths, :test).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths, :source).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_compiler).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_linker).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_fixture).returns(true)
    
    assert(@helper.validate_required_section_values(@test_config))
  end

  should "fail when any required section value is missing" do
    @configurator_validator.expects.exists?(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths, :test).returns(false)
    @configurator_validator.expects.exists?(@test_config, :paths, :source).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_compiler).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_linker).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_fixture).returns(true)
    
    assert_equal(false, @helper.validate_required_section_values(@test_config))

    @configurator_validator.expects.exists?(@test_config, :project, :build_root).returns(false)
    @configurator_validator.expects.exists?(@test_config, :paths, :test).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths, :source).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_compiler).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_linker).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_fixture).returns(true)
    
    assert_equal(false, @helper.validate_required_section_values(@test_config))

    @configurator_validator.expects.exists?(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths, :test).returns(true)
    @configurator_validator.expects.exists?(@test_config, :paths, :source).returns(false)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_compiler).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_linker).returns(false)
    @configurator_validator.expects.exists?(@test_config, :tools, :test_fixture).returns(false)
    
    assert_equal(false, @helper.validate_required_section_values(@test_config))
  end


  should "fail if any paths in the configuration fail validation" do
    # note: source iterates through hash keys in string class's <=> order
    @test_config[:paths] = {:paths1 => [], :paths2 => [], :paths3 => []}
    @test_config[:plugins] = {:base_path => 'plugins', :enabled => ['boo', 'berry']}
    
    @configurator_validator.expects.validate_path_list(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths2).returns(false)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths3).returns(true)
    @configurator_validator.expects.validate_path('plugins', :plugins, :base_path).returns(true)
    @configurator_validator.expects.validate_path('plugins/berry', :plugins, :enabled, :berry).returns(true)
    @configurator_validator.expects.validate_path('plugins/boo', :plugins, :enabled, :boo).returns(true)
    
    assert_equal(false, @helper.validate_path_list(@test_config))

    @configurator_validator.expects.validate_path_list(@test_config, :project, :build_root).returns(false)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths3).returns(true)
    @configurator_validator.expects.validate_path('plugins', :plugins, :base_path).returns(true)
    @configurator_validator.expects.validate_path('plugins/berry', :plugins, :enabled, :berry).returns(true)
    @configurator_validator.expects.validate_path('plugins/boo', :plugins, :enabled, :boo).returns(true)
    
    assert_equal(false, @helper.validate_path_list(@test_config))

    @configurator_validator.expects.validate_path_list(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths1).returns(false)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths3).returns(false)
    @configurator_validator.expects.validate_path('plugins', :plugins, :base_path).returns(true)
    @configurator_validator.expects.validate_path('plugins/berry', :plugins, :enabled, :berry).returns(true)
    @configurator_validator.expects.validate_path('plugins/boo', :plugins, :enabled, :boo).returns(true)
    
    assert_equal(false, @helper.validate_path_list(@test_config))

    @configurator_validator.expects.validate_path_list(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths3).returns(true)
    @configurator_validator.expects.validate_path('plugins', :plugins, :base_path).returns(false)
    @configurator_validator.expects.validate_path('plugins/berry', :plugins, :enabled, :berry).returns(true)
    @configurator_validator.expects.validate_path('plugins/boo', :plugins, :enabled, :boo).returns(true)
    
    assert_equal(false, @helper.validate_path_list(@test_config))

    @configurator_validator.expects.validate_path_list(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths3).returns(true)
    @configurator_validator.expects.validate_path('plugins', :plugins, :base_path).returns(true)
    @configurator_validator.expects.validate_path('plugins/berry', :plugins, :enabled, :berry).returns(true)
    @configurator_validator.expects.validate_path('plugins/boo', :plugins, :enabled, :boo).returns(false)
    
    assert_equal(false, @helper.validate_path_list(@test_config))
  end

  should "successfully validate all paths in the configuration" do
    # note: source iterates through hash keys in string class's <=> order
    @test_config[:paths] = {:paths1 => [], :paths2 => [], :paths3 => []}
    @test_config[:plugins] = {:base_path => 'plugins', :enabled => ['boo', 'berry']}
    
    @configurator_validator.expects.validate_path_list(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_path_list(@test_config, :paths, :paths3).returns(true)

    @configurator_validator.expects.validate_path('plugins', :plugins, :base_path).returns(true)
    @configurator_validator.expects.validate_path('plugins/berry', :plugins, :enabled, :berry).returns(true)
    @configurator_validator.expects.validate_path('plugins/boo', :plugins, :enabled, :boo).returns(true)
    
    assert(@helper.validate_path_list(@test_config))
  end


  should "fail if any tools in the configuration fail validation" do
    # note: source iterates through hash keys in string class's <=> order
    @test_config[:tools] = {:circular_saw => {}, :compiler => {}, :report_generator => {}}
    
    @configurator_validator.expects.exists?(@test_config, :tools, :circular_saw, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :circular_saw, :executable).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :compiler, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :compiler, :executable).returns(false)
    @configurator_validator.expects.exists?(@test_config, :tools, :report_generator, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :report_generator, :executable).returns(true)
    
    assert_equal(false, @helper.validate_tools(@test_config))

    @configurator_validator.expects.exists?(@test_config, :tools, :circular_saw, :executable).returns(false)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :circular_saw, :executable).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :compiler, :executable).returns(false)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :compiler, :executable).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :report_generator, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :report_generator, :executable).returns(true)
    
    assert_equal(false, @helper.validate_tools(@test_config))

    @configurator_validator.expects.exists?(@test_config, :tools, :circular_saw, :executable).returns(false)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :circular_saw, :executable).returns(false)
    @configurator_validator.expects.exists?(@test_config, :tools, :compiler, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :compiler, :executable).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :report_generator, :executable).returns(false)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :report_generator, :executable).returns(false)
    
    assert_equal(false, @helper.validate_tools(@test_config))
  end

  should "successfully validate tools in the configuration=" do
    # note: source iterates through hash keys in string class's <=> order
    @test_config[:tools] = {:circular_saw => {}, :compiler => {}, :report_generator => {}}
    
    @configurator_validator.expects.exists?(@test_config, :tools, :circular_saw, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :circular_saw, :executable).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :compiler, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :compiler, :executable).returns(true)
    @configurator_validator.expects.exists?(@test_config, :tools, :report_generator, :executable).returns(true)
    @configurator_validator.expects.validate_filepath(@test_config, :tools, :report_generator, :executable).returns(true)
    
    assert(@helper.validate_tools(@test_config))
  end

end
