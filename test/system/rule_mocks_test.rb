require File.dirname(__FILE__) + '/../system_test_helper'


class MocksRuleTest < Test::Unit::TestCase

  def setup
    @header_file     = "a_file.h"
    @mock_file       = "mock_a_file.c"
    @header_filepath = "#{SYSTEM_TEST_ROOT}/mocks/include/#{@header_file}"
    @mock_filepath   = "#{SYSTEM_TEST_ROOT}/mocks/build/tests/mocks/#{@mock_file}"

    ENV['CEEDLING_MAIN_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'project_mocks.yml')

    ceedling_execute('directories', 'clobber')    
  end

  def teardown
  end


  should "generate a mock from a source header file and regenerate when its dependent source changes" do
    rake_exec_matcher = /^\*\* Execute.+#{Regexp.escape(@mock_file)}$/

    # verify clobber did its job
    assert_equal(false, File.exists?(@mock_filepath))
    
    # give rake a task to generate a mock file & verify its presence
    ceedling_execute(@mock_filepath)
    assert_equal(true, File.exists?(@mock_filepath), 'mock file not created')
    
    # verify executing rule again will not regenerate mock
    output = ceedling_execute_dry_run(@mock_filepath)
    assert_no_match(rake_exec_matcher, output, 'mock file should not be slated for generation')
    
    # wait a spell to update file timestamp, ensuring time change is recognizable
    sleep(1)
    FileUtils.touch(@header_filepath)

    # verify executing rule again will regenerate mock
    output = ceedling_execute_dry_run(@mock_filepath)
    assert_match(rake_exec_matcher, output, 'mock file should be slated for generation')    
  end

end
