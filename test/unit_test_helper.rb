require File.expand_path(File.dirname(__FILE__)) + "/../config/test_environment"
require 'test_helper'
require 'constructor'
require 'hardmock'


$config_options = {
  :project_build_root => 'project/build',
  :project_build_output_path => 'project/build/output',
  :project_test_results_path => 'project/build/results',
  :project_source_include_dirs => [],
  :project_test_file_prefix => 'test_',
  :project_preprocess_files_path => 'project/build/preprocess/files',
  :project_preprocess_includes_path => 'project/build/preprocess/includes',
  :test_runner_file_suffix => '_runner',
  :cmock_mock_prefix => 'mock_',
  :extension_source  => '.c',
  :extension_header  => '.h',
  :extension_object  => '.o',
  :extension_executable  => '.out',
  :extension_testpass  => '.pass',
  :collection_all_tests => [],
  :collection_all_include_paths => [],
  :defines_test => [],
  }    

PROJECT_BUILD_ROOT = $config_options[:project_build_root]
PROJECT_BUILD_OUTPUT_PATH = $config_options[:project_build_output_path]
PROJECT_TEST_RESULTS_PATH = $config_options[:project_test_results_path]
PROJECT_SOURCE_INCLUDE_PATHS = $config_options[:project_source_include_dirs]
PROJECT_TEST_FILE_PREFIX = $config_options[:project_test_file_prefix]
PROJECT_PREPROCESS_FILES_PATH = $config_options[:project_preprocess_files_path]
PROJECT_PREPROCESS_INCLUDES_PATH = $config_options[:project_preprocess_includes_path]
TEST_RUNNER_FILE_SUFFIX = $config_options[:test_runner_file_suffix]
CMOCK_MOCK_PREFIX = $config_options[:cmock_mock_prefix]  
EXTENSION_SOURCE  = $config_options[:extension_source]
EXTENSION_HEADER  = $config_options[:extension_header]
EXTENSION_OBJECT  = $config_options[:extension_object]
EXTENSION_EXECUTABLE  = $config_options[:extension_executable]
EXTENSION_TESTPASS  = $config_options[:extension_testpass]
COLLECTION_ALL_TESTS  = $config_options[:collection_all_tests]
COLLECTION_ALL_INCLUDE_PATHS = $config_options[:collection_all_include_paths]
DEFINES_TEST = $config_options[:defines_test]


class Test::Unit::TestCase
  extend Behaviors
  
  def redefine_global_constant(constant, value)
    $config_options[constant.downcase.to_sym].replace(value)
  end
  
end


