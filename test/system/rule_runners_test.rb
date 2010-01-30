require File.dirname(__FILE__) + '/../system_test_helper'


class RunnersRuleTest < Test::Unit::TestCase

  def setup
    @test_file   = "#{SYSTEM_TEST_ROOT}/simple/test/test_a_file.c"
    @runner_file = "#{SYSTEM_TEST_ROOT}/simple/build/tests/runners/test_a_file_runner.c"

    ENV['CEEDLING_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'simple.yml')

    rake_execute('directories', 'clobber')    
  end

  def teardown
  end


  should "generate a test runner from a test source header file and regenerate when its dependent source changes" do
    rake_exec_matcher = /^\*\* Execute.+test_a_file_runner\.c$/
    
    # verify clobber did its job
    assert_equal(false, File.exists?(@runner_file))
    
    # give rake a task to generate a test runner file & verify its presence
    rake_execute(@runner_file)
    assert_equal(true, File.exists?(@runner_file), 'test runner file not created')
    
    # verify executing rule again will not regenerate runner
    output = rake_dry_run(@runner_file)
    assert_no_match(rake_exec_matcher, output, 'test runner file should not be slated for generation')
    
    # wait a spell to update file timestamp, ensuring time change is recognizable
    sleep(1)
    FileUtils.touch(@test_file)

    # verify executing rule again will regenerate runner
    output = rake_dry_run(@runner_file)
    assert_match(rake_exec_matcher, output, 'test runner file should be slated for generation')    
  end

end
