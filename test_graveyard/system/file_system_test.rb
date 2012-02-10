require File.dirname(__FILE__) + '/../system_test_helper'


class PathsTest < Test::Unit::TestCase

  def setup
    @build_root         = "#{SYSTEM_TEST_ROOT}/file_system/build"
    @build_release_root = "#{@build_root}/release"
    @build_tests_root   = "#{@build_root}/tests"
    @all_build_paths = [
      "#{@build_release_root}/out",
      "#{@build_release_root}/artifacts",
      "#{@build_tests_root}/artifacts",
      "#{@build_tests_root}/runners",
      "#{@build_tests_root}/results",
      "#{@build_tests_root}/out",
      "#{@build_tests_root}/mocks",
      "#{@build_root}/temp",
      "#{@build_tests_root}/preprocess",
      "#{@build_tests_root}/preprocess/includes",
      "#{@build_tests_root}/preprocess/files",
      "#{@build_tests_root}/dependencies",
      ]
      
    FileUtils.rm_rf(@all_build_paths)
  end

  def teardown
  end

  def run_helper(config_file, all_build_paths_indexes)
    ENV['CEEDLING_MAIN_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, config_file)

    build_paths = []
    all_build_paths_indexes.each {|i| build_paths << @all_build_paths[i]}
  
    # verify paths are gone
    build_paths.each {|path| assert_equal(false, File.exists?(path))}
    
    # tell rake to create build paths
    ceedling_execute('directories')
  
    # verify paths are created
    build_paths.each {|path| assert(File.exists?(path), "'#{path}' not found.")}    
  end

  
  should "blow away all build directories and demonstrate that we can create simple set via rake & config file" do
    all_build_paths_indexes = [0, 1, 2, 3, 4]

    run_helper('file_system_simple.yml', all_build_paths_indexes)
  end

  should "blow away all build directories and demonstrate that we can create set including test mocks via rake & config file" do
    all_build_paths_indexes = [0, 1, 2, 3, 4, 5]

    run_helper('file_system_mocks.yml', all_build_paths_indexes)
  end

  should "blow away all build directories and demonstrate that we can create set including test preprocessing via rake & config file" do
    all_build_paths_indexes = [0, 1, 2, 3, 4, 5, 7, 8, 9, 10]

    run_helper('file_system_preprocess.yml', all_build_paths_indexes)
  end

  should "blow away all build directories and demonstrate that we can create set including auxiliary dependencies via rake & config file" do
    all_build_paths_indexes = [0, 1, 2, 3, 4, 5, 11]

    run_helper('file_system_dependencies.yml', all_build_paths_indexes)
  end

  should "blow away all build directories and demonstrate that we can create set of paths for all options via rake & config file" do
    all_build_paths_indexes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]

    run_helper('file_system_kitchen_sink.yml', all_build_paths_indexes)
  end

end
