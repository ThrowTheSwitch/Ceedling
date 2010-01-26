require File.dirname(__FILE__) + '/../unit_test_helper'
require 'configurator_helper'


class ConfiguratorHelperTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator_validator)
    @helper = ConfiguratorHelper.new(objects)
    
    @test_config = {}
  end

  def teardown
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
    
    @configurator_validator.expects.validate_paths(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths2).returns(false)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths3).returns(true)
    
    assert_equal(false, @helper.validate_paths(@test_config))

    @configurator_validator.expects.validate_paths(@test_config, :project, :build_root).returns(false)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths3).returns(true)
    
    assert_equal(false, @helper.validate_paths(@test_config))

    @configurator_validator.expects.validate_paths(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths1).returns(false)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths3).returns(false)
    
    assert_equal(false, @helper.validate_paths(@test_config))
  end

  should "successfully validate all paths in the configuration" do
    # note: source iterates through hash keys in string class's <=> order
    @test_config[:paths] = {:paths1 => [], :paths2 => [], :paths3 => []}
    
    @configurator_validator.expects.validate_paths(@test_config, :project, :build_root).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths1).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths2).returns(true)
    @configurator_validator.expects.validate_paths(@test_config, :paths, :paths3).returns(true)
    
    assert(@helper.validate_paths(@test_config))
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
