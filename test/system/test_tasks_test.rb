require File.dirname(__FILE__) + '/../system_test_helper'


class TestTasksTest < Test::Unit::TestCase

  def setup
    @mocks = [
      "#{SYSTEST_ROOT}/a_project/build/mocks/mock_a_file.c",
      "#{SYSTEST_ROOT}/a_project/build/mocks/mock_another_file.c"]

    @runners = [
      "#{SYSTEST_ROOT}/a_project/build/runners/test_a_file_runner.c",
      "#{SYSTEST_ROOT}/a_project/build/runners/test_another_file_runner.c"]

    ENV['CEEDLING_PROJECT_FILE'] = File.join(SYSTEST_ROOT, 'a_project.yml')

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
