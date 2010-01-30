require File.dirname(__FILE__) + '/../system_test_helper'


class PathsTest < Test::Unit::TestCase

  def setup
    ENV['CEEDLING_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'file_system.yml')
  end

  def teardown
  end

  
  should "blow away all build directories and demonstrate that we can create them via rake & config file" do
    build_root  = "#{SYSTEM_TEST_ROOT}/file_system/build"
    build_paths = ["#{build_root}/mocks", "#{build_root}/runners", "#{build_root}/results", "#{build_root}/out"]
    
    FileUtils.rm_rf(build_paths)
  
    # verify paths are gone
    build_paths.each {|path| assert_equal(false, File.exists?(path))}
    
    # tell rake to create build paths
    rake_execute('directories')
  
    # verify paths are created
    build_paths.each {|path| assert(File.exists?(path))}
  end

end
