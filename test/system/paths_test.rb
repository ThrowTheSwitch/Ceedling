require File.dirname(__FILE__) + '/../system_test_helper'
require 'rubygems'
require 'rake' # for FileList
require 'constructor'
require 'file_system_utils'
require 'file_wrapper'


PATHS_ROOT = SYSTEST_ROOT + '/paths'

class PathsTest < Test::Unit::TestCase

  def setup
    ENV['CEEDLING_PROJECT_FILE'] = File.join(SYSTEST_ROOT, 'a_project.yml')
    
    @file_system_utils = FileSystemUtils.new({:file_wrapper => FileWrapper.new})
  end

  def teardown
  end

  
  should "blow away all build directories and demonstrate that we can create them via rake & config file" do
    build_root  = "#{SYSTEST_ROOT}/a_project/build"
    build_paths = ["#{build_root}/mocks", "#{build_root}/runners", "#{build_root}/results", "#{build_root}/out"]
    
    FileUtils.rm_rf(build_paths)
  
    # verify paths are gone
    build_paths.each {|path| assert_equal(false, File.exists?(path))}
    
    # tell rake to create build paths
    rake_execute('directories')
  
    # verify paths are created
    build_paths.each {|path| assert(File.exists?(path))}
  end
  

  should "collect paths from file system and exercise globs and our special glob handling" do
    # pass in two strings to find all test(s) dirs in main/ and modules/
    expected = [
      "#{PATHS_ROOT}/main/test",
      "#{PATHS_ROOT}/modules/comm/ethernet/test",
      "#{PATHS_ROOT}/modules/comm/serial/test",
      "#{PATHS_ROOT}/modules/eeprom/test",
      "#{PATHS_ROOT}/modules/display/tests",
      "#{PATHS_ROOT}/modules/power/tests"]
    list = @file_system_utils.collect_paths("#{PATHS_ROOT}/main/test", "#{PATHS_ROOT}/modules/**/tes{t,ts}")
    assert_equal(expected.sort, list.to_a.sort)
    
    # pass in a FileList to find all src/ dirs in all of PATHS_ROOT space
    expected = [
      "#{PATHS_ROOT}/main/src",
      "#{PATHS_ROOT}/modules/comm/ethernet/src",
      "#{PATHS_ROOT}/modules/comm/serial/src",
      "#{PATHS_ROOT}/modules/display/src",
      "#{PATHS_ROOT}/modules/eeprom/src",
      "#{PATHS_ROOT}/modules/power/src"]   
    list = @file_system_utils.collect_paths(FileList.new("#{PATHS_ROOT}/**/sr?"))
    assert_equal(expected.sort, list.to_a.sort)

    # pass in a string to recursively find all subdirectories below source/
    expected = [
      "#{PATHS_ROOT}/source/comm",
      "#{PATHS_ROOT}/source/comm/ethernet",
      "#{PATHS_ROOT}/source/comm/serial",
      "#{PATHS_ROOT}/source/display",
      "#{PATHS_ROOT}/source/eeprom",
      "#{PATHS_ROOT}/source/power"]
    list = @file_system_utils.collect_paths("#{PATHS_ROOT}/source/**")
    assert_equal(expected.sort, list.to_a.sort)

    # pass in a string to find all subdirectories one level below source/
    expected = [
      "#{PATHS_ROOT}/source/comm",
      "#{PATHS_ROOT}/source/display",
      "#{PATHS_ROOT}/source/eeprom",
      "#{PATHS_ROOT}/source/power"]
    list = @file_system_utils.collect_paths("#{PATHS_ROOT}/source/*")
    assert_equal(expected.sort, list.to_a.sort)


    # pass in an array of strings to collect tests/ and all subdirectories below tests/
    expected = [
      "#{PATHS_ROOT}/tests",
      "#{PATHS_ROOT}/tests/comm",
      "#{PATHS_ROOT}/tests/comm/ethernet",
      "#{PATHS_ROOT}/tests/comm/serial",
      "#{PATHS_ROOT}/tests/display",
      "#{PATHS_ROOT}/tests/eeprom",
      "#{PATHS_ROOT}/tests/power"]
    list = @file_system_utils.collect_paths(["#{PATHS_ROOT}/tests", "#{PATHS_ROOT}/tests/**"])
    assert_equal(expected.sort, list.to_a.sort)
  end

end
