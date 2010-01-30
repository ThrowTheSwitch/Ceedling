require File.dirname(__FILE__) + '/../system_test_helper'


class MockRuleTest < Test::Unit::TestCase

  def setup
    @header_file = "#{SYSTEM_TEST_ROOT}/a_project/include/a_file.h"
    @mock_file   = "#{SYSTEM_TEST_ROOT}/a_project/build/mocks/mock_a_file.c"

    ENV['CEEDLING_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'a_project.yml')

    rake_execute('directories', 'clobber')    
  end

  def teardown
  end


  should "generate a mock from a source header file and regenerate when its dependent source changes" do
    rake_exec_matcher = /^\*\* Execute.+mock_a_file\.c$/

    # verify clobber did its job
    assert_equal(false, File.exists?(@mock_file))
    
    # give rake a task to generate a mock file & verify its presence
    rake_execute(@mock_file)
    assert_equal(true, File.exists?(@mock_file), 'mock file not created')
    
    # verify executing rule again will not regenerate mock
    output = rake_dry_run(@mock_file)
    assert_no_match(rake_exec_matcher, output, 'mock file should not be slated for generation')
    
    # wait a spell to update file timestamp, ensuring time change is recognizable
    sleep(1)
    FileUtils.touch(@header_file)

    # verify executing rule again will regenerate mock
    output = rake_dry_run(@mock_file)
    assert_match(rake_exec_matcher, output, 'mock file should be slated for generation')    
  end

end
