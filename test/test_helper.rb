
#gem install test-unit -v 1.2.3
ruby_version = RUBY_VERSION.split('.')
if (ruby_version[1].to_i == 9) and (ruby_version[2].to_i > 1)
  require 'gems'
  gem 'test-unit'
end
require 'test/unit'
require 'behaviors'


TESTS_ROOT            = File.expand_path(File.dirname(__FILE__))
SYSTEM_TEST_ROOT      = TESTS_ROOT + '/system'
INTEGRATION_TEST_ROOT = TESTS_ROOT + '/integration'
LIB_ROOT              = File.expand_path(File.dirname(__FILE__) + '/../lib')
CEEDLING_ROOT         = 'test_ceedling_root/'
CEEDLING_LIB          = 'test_ceedling_lib/'
CEEDLING_VENDOR       = 'test_ceedling_vendor/'
CEEDLING_RELEASE      = 'test_ceedling_release/'

$config_options = {
  :project_build_root => 'project/build',
  :project_test_build_output_path => 'project/build/tests/output',
  :project_test_results_path => 'project/build/tests/results',
  :project_source_include_dirs => [],
  :project_test_file_prefix => 'test_',
  :project_test_preprocess_files_path => 'project/build/tests/preprocess/files',
  :project_test_preprocess_includes_path => 'project/build/tests/preprocess/includes',
  :project_test_dependencies_path => 'project/build/tests/dependencies',
  :test_runner_file_suffix => '_runner',
  :cmock_mock_prefix => 'mock_',
  :extension_source  => '.c',
  :extension_header  => '.h',
  :extension_object  => '.o',
  :extension_executable  => '.out',
  :extension_testpass  => '.pass',
  :extension_dependencies => '.d',
  :collection_all_tests => [],
  :collection_all_include_paths => [],
  :defines_test => [],
  }    

PROJECT_BUILD_ROOT = $config_options[:project_build_root]
PROJECT_TEST_BUILD_OUTPUT_PATH = $config_options[:project_test_build_output_path]
PROJECT_TEST_RESULTS_PATH = $config_options[:project_test_results_path]
PROJECT_SOURCE_INCLUDE_PATHS = $config_options[:project_source_include_dirs]
PROJECT_TEST_FILE_PREFIX = $config_options[:project_test_file_prefix]
PROJECT_TEST_PREPROCESS_FILES_PATH = $config_options[:project_test_preprocess_files_path]
PROJECT_TEST_PREPROCESS_INCLUDES_PATH = $config_options[:project_test_preprocess_includes_path]
PROJECT_TEST_DEPENDENCIES_PATH = $config_options[:project_test_dependencies_path]
TEST_RUNNER_FILE_SUFFIX = $config_options[:test_runner_file_suffix]
CMOCK_MOCK_PREFIX = $config_options[:cmock_mock_prefix]  
EXTENSION_SOURCE  = $config_options[:extension_source]
EXTENSION_HEADER  = $config_options[:extension_header]
EXTENSION_OBJECT  = $config_options[:extension_object]
EXTENSION_EXECUTABLE  = $config_options[:extension_executable]
EXTENSION_TESTPASS  = $config_options[:extension_testpass]
EXTENSION_DEPENDENCIES  = $config_options[:extension_dependencies]
COLLECTION_ALL_TESTS  = $config_options[:collection_all_tests]
COLLECTION_ALL_INCLUDE_PATHS = $config_options[:collection_all_include_paths]
DEFINES_TEST = $config_options[:defines_test]


class String
  def left_margin(margin=0)
    non_whitespace_column = 0
    new_lines = []
    
    # find first line with non-whitespace and count left columns of whitespace
    self.each_line do |line|
      if (line =~ /^\s*\S/)
        non_whitespace_column = $&.length - 1
        break
      end
    end
    
    # iterate through each line, chopping off leftmost whitespace columns and add back the desired whitespace margin
    self.each_line do |line|
      columns = []
      margin.times{columns << ' '}
      # handle special case of line being narrower than width to be lopped off
      if (non_whitespace_column < line.length)
        new_lines << "#{columns.join}#{line[non_whitespace_column..-1]}"
      else
        new_lines << "\n"
      end
    end
    
    return new_lines.join
  end
end


