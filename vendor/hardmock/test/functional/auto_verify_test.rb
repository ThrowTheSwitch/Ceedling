require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
require 'fileutils'

class AutoVerifyTest < Test::Unit::TestCase

  def setup
    @expect_unmet_expectations = true
  end

  def teardown
    remove_temp_test_file
  end

  #
  # TESTS
  #

  it "auto-verifies all mocks in teardown" do
    write_and_execute_test 
  end

  it "auto-verifies even if user defines own teardown" do
    @teardown_code =<<-EOM 
      def teardown
        # just in the way
      end
    EOM
    write_and_execute_test 
  end

  should "not obscure normal failures when verification fails" do
    @test_code =<<-EOM
        def test_setup_doomed_expectation
          create_mock :automobile
          @automobile.expects.start
          flunk "natural failure"
        end
    EOM
    @expect_failures = 1
    write_and_execute_test
  end

  should "not skip user-defined teardown when verification fails" do
    @teardown_code =<<-EOM 
      def teardown
        puts "User teardown"
      end
    EOM
    write_and_execute_test 
    assert_output_contains(/User teardown/)
  end

  it "is quiet when verification is ok" do
    @test_code =<<-EOM
        def test_ok
          create_mock :automobile
          @automobile.expects.start
          @automobile.start
        end
    EOM
    @teardown_code =<<-EOM 
      def teardown
        puts "User teardown"
      end
    EOM
    @expect_unmet_expectations = false
    @expect_failures = 0
    @expect_errors = 0
    write_and_execute_test
    assert_output_contains(/User teardown/)
  end

  should "auto-verify even if user teardown explodes" do
    @teardown_code =<<-EOM 
      def teardown
        raise "self destruct"
      end
    EOM
    @expect_errors = 2
    write_and_execute_test
    assert_output_contains(/self destruct/)
  end

  it "plays nice with inherited teardown methods" do
    @full_code ||=<<-EOTEST
      require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
      require 'hardmock'
      class Test::Unit::TestCase 
        def teardown
          puts "Test helper teardown"
        end
      end
      class DummyTest < Test::Unit::TestCase
        def test_prepare_to_die
          create_mock :automobile
          @automobile.expects.start
        end
      end 
    EOTEST
    write_and_execute_test
    assert_output_contains(/Test helper teardown/)
  end

  #
  # HELPERS
  #

  def temp_test_file
    File.expand_path(File.dirname(__FILE__) + "/tear_down_verification_test.rb")
  end

  def run_test(tbody)
    File.open(temp_test_file,"w") { |f| f.print(tbody) }
    @test_output = `ruby #{temp_test_file} 2>&1`
  end

  def formatted_test_output
    if @test_output
      @test_output.split(/\n/).map { |line| "> #{line}" }.join("\n")
    else
      "(NO TEST OUTPUT!)"
    end
  end

  def remove_temp_test_file
    FileUtils::rm_f temp_test_file
  end

  def assert_results(h)
    if @test_output !~ /#{h[:tests]} tests, [0-9]+ assertions, #{h[:failures]} failures, #{h[:errors]} errors/
      flunk "Test results didn't match #{h.inspect}:\n#{formatted_test_output}"
    end
  end

  def assert_output_contains(*patterns)
    patterns.each do |pattern|
      if @test_output !~ pattern
        flunk "Test output didn't match #{pattern.inspect}:\n#{formatted_test_output}"
      end
    end
  end
  
  def assert_output_doesnt_contain(*patterns)
    patterns.each do |pattern|
      assert @test_output !~ pattern, "Output shouldn't match #{pattern.inspect} but it does."
    end
  end

  def write_and_execute_test
    @test_code ||=<<-EOM
        def test_setup_doomed_expectation
          create_mock :automobile
          @automobile.expects.start
        end
    EOM
    @full_code ||=<<-EOTEST
      require File.expand_path(File.dirname(__FILE__) + "/../test_helper")
      require 'hardmock'
      class DummyTest < Test::Unit::TestCase
        #{@teardown_code}
        #{@test_code}
      end 
    EOTEST
    run_test @full_code

    if @expect_unmet_expectations 
      assert_output_contains(/unmet expectations/i, /automobile/, /start/)
    else
      assert_output_doesnt_contain(/unmet expectations/i, /automobile/, /start/)
    end

    @expect_tests ||= 1
    @expect_failures ||= 0
    @expect_errors ||= 1
    assert_results :tests => @expect_tests, :failures => @expect_failures, :errors => @expect_errors
  end
  
end
