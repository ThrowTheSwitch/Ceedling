require File.dirname(__FILE__) + '/../unit_test_helper'
require 'setupinator'


class SetupinatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:project_file_loader, :configurator, :test_includes_extractor)
    create_mocks(:config_hash)
    @setupinator = Setupinator.new(objects)
  end

  def teardown
  end
  
  
  should "perform all post-instantiation setup steps" do
    @project_file_loader.expects.find_project_file
    @project_file_loader.expects.load_project.returns(@config_hash)

    @configurator.expects.standardize_paths(@config_hash)
    @configurator.expects.validate(@config_hash)
    @configurator.expects.insert_cmock_defaults(@config_hash)
    @configurator.expects.build(@config_hash)
    
    @configurator.expects.cmock_mock_prefix.returns('Mock')
    @test_includes_extractor.expects.cmock_mock_prefix=('Mock')
    
    @configurator.expects.extension_header.returns('.h')
    @test_includes_extractor.expects.extension_header=('.h')

    @setupinator.setupinate
  end
  
end
