require File.dirname(__FILE__) + '/../system_test_helper'


class RunnersRuleTest < Test::Unit::TestCase

  def setup
    @test_file       = 'test_stuff.c'
    @runner_file     = 'test_stuff_runner.c'
    @test_filepath   = "#{SYSTEM_TEST_ROOT}/simple/test/#{@test_file}"
    @runner_filepath = "#{SYSTEM_TEST_ROOT}/simple/build/tests/runners/#{@runner_file}"

    ENV['CEEDLING_MAIN_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'project_simple.yml')

    ceedling_execute('directories', 'clobber')    
  end

  def teardown
  end


  should "generate a test runner from a test source header file and regenerate when its dependent source changes" do
    rake_exec_matcher = /^\*\* Execute.+#{Regexp.escape(@runner_file)}$/
    
    # verify clobber did its job
    assert_equal(false, File.exists?(@runner_filepath))
    
    # give rake a task to generate a test runner file & verify its presence
    ceedling_execute(@runner_filepath)
    assert_equal(true, File.exists?(@runner_filepath), 'test runner file not created')
    
    # verify executing rule again will not regenerate runner
    output = ceedling_execute_dry_run(@runner_filepath)
    assert_no_match(rake_exec_matcher, output, 'test runner file should not be slated for generation')
    
    # wait a spell to update file timestamp, ensuring time change is recognizable
    sleep(1)
    FileUtils.touch(@test_filepath)

    # verify executing rule again will regenerate runner
    output = ceedling_execute_dry_run(@runner_filepath)
    assert_match(rake_exec_matcher, output, 'test runner file should be slated for generation')    
  end

end
