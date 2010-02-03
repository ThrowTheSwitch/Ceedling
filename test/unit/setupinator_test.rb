require File.dirname(__FILE__) + '/../unit_test_helper'
require 'setupinator'


class SetupinatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:project_file_loader, :configurator, :test_includes_extractor, :extendinator)
    create_mocks(:config_hash, :system_objects)
    @setupinator = Setupinator.new(objects)
  end

  def teardown
  end
  
  
  should "perform all post-instantiation setup steps" do
    @project_file_loader.expects.find_project_files
    @project_file_loader.expects.load_project_file.returns(@config_hash)

    @configurator.expects.standardize_paths(@config_hash)
    @configurator.expects.populate_extenders_defaults(@config_hash)
    @configurator.expects.validate(@config_hash)
    @configurator.expects.build_cmock_defaults(@config_hash)
    @configurator.expects.find_and_merge_extenders(@config_hash)
    @configurator.expects.build(@config_hash)
    
    @configurator.expects.rake_extenders.returns(['extenders/ext1/ext1.rake', 'extenders/ext2/ext2.rake'])
    @configurator.expects.insert_rake_extenders(['extenders/ext1/ext1.rake', 'extenders/ext2/ext2.rake'])
    
    @configurator.expects.script_extenders.returns(['extenders/ext2/ext2.rb', 'extenders/ext3/ext3.rb'])
    @extendinator.expects.load_extender_scripts(['extenders/ext2/ext2.rb', 'extenders/ext3/ext3.rb'], @system_objects)
    
    @configurator.expects.cmock_mock_prefix.returns('Mock')
    @test_includes_extractor.expects.cmock_mock_prefix=('Mock')
    
    @configurator.expects.extension_header.returns('.h')
    @test_includes_extractor.expects.extension_header=('.h')

    @setupinator.do_setup(@system_objects)
  end
  
end
