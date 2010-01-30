require File.dirname(__FILE__) + '/../system_test_helper'


class TestTasksTest < Test::Unit::TestCase

  def setup
    @mocks = [
      "#{SYSTEM_TEST_ROOT}/mocks/build/mocks/mock_a_file.c",
      "#{SYSTEM_TEST_ROOT}/mocks/build/mocks/mock_another_file.c"]

    @runners = [
      "#{SYSTEM_TEST_ROOT}/mocks/build/runners/test_a_file_runner.c",
      "#{SYSTEM_TEST_ROOT}/mocks/build/runners/test_another_file_runner.c"]

    ENV['CEEDLING_PROJECT_FILE'] = File.join(SYSTEM_TEST_ROOT, 'tasks.yml')

    rake_execute('directories', 'clobber')    
  end

  def teardown
  end


  should "generate mocks and runners for all tests" do
    task = 'tests:all'
    
    # verify clobber did its job
    (@mocks + @runners).each do |file|
      assert_equal(false, File.exists?(file))
    end

    # tell rake to execute all tests
    rake_execute(task)
    
    # verify presence of mocks & runners
    (@mocks + @runners).each do |file|
      assert(File.exists?(file), "file '#{file}' not created")
    end
  end


  should "generate mock and runner for a single test" do
    task = 'tests:another_file.c'

    # verify clobber did its job
    assert_equal(false, File.exists?(@mocks[0]))
    assert_equal(false, File.exists?(@runners[1]))

    # tell rake to execute all tests
    rake_execute(task)
    
    # verify presence of generated files
    assert(File.exists?(@mocks[0]), "file '#{@mocks[0]}' not created")
    assert(File.exists?(@runners[1]), "file '#{@runners[1]}' not created")
  end

end
