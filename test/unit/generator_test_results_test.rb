require File.dirname(__FILE__) + '/../unit_test_helper'
require 'generator_test_results'


class GeneratorTestResultsTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator, :yaml_wrapper, :streaminator)
    @utils = GeneratorTestResults.new(objects)
  end

  def teardown
  end

  
  should "complain if output from test fixture includes messed up statistics" do

    # no ignore count
    raw_unity_output1 = %Q[
      13 Tests 0 Failures
      ].left_margin(0)

    @configurator.expects.extension_executable.returns('.exe')
    @streaminator.expects.stderr_puts("ERROR: Results from test fixture 'TestIng.exe' are missing or are malformed.", Verbosity::ERRORS)

    assert_raise(RuntimeError){ @utils.process_and_write_results(raw_unity_output1, 'project/build/results/TestIng.pass', 'files/tests/TestIng.c') }

    # 'Test' not pluralized
    raw_unity_output2 = %Q[
      13 Test 0 Failures 3 Ignored
      ].left_margin(0)

    @configurator.expects.extension_executable.returns('.out')
    @streaminator.expects.stderr_puts("ERROR: Results from test fixture 'TestIcular.out' are missing or are malformed.", Verbosity::ERRORS)

    assert_raise(RuntimeError){ @utils.process_and_write_results(raw_unity_output2, 'project/build/results/TestIcular.pass', 'files/tests/TestIcular.c') }
  end


  should "write a mixture of test results to a .fail file" do
    
    # test fixture output with blank lines and junk past the statistics line
    raw_unity_output = %Q[
           
      test_a_file.c:13:test_a_single_thing:IGNORE:pay no attention to the test behind the curtain
      test_a_file.c:18:test_another_thing:IGNORE:pay no attention to the:stray colon
      test_a_file.c:35:test_your_knowledge:FAIL:Expected TRUE was FALSE
      test_a_file.c:42:test_a_success_case:PASS
      
      test_a_file.c:47:test_another_thing:FAIL
      test_a_file.c:53:test_some_non_void_param_stuff:IGNORE:pay no attention to the test behind the curtain
      test_a_file.c:60:test_some_multiline_test_case_action:IGNORE:pay no attention to the test behind the curtain
      
      test_a_file.c:65:test_another_success_case:PASS
      test_a_file.c:78:test_yet_another_success_case:PASS
      test_a_file.c:92:test_a_final_thing:FAIL:BOOM!
      10 Tests 3 Failures 4 Ignored
      FAIL
      // a random comment to be ignored
      ].left_margin(0)
    
    expected_hash = {
      :counts => {:total => 10, :failed => 3, :ignored => 4, :passed => 3},
      :source => {:path => 'files/tests', :file => 'test_a_file.c'},
      :failures => [
        {:test => 'test_your_knowledge', :line => 35, :message => 'Expected TRUE was FALSE'},
        {:test => 'test_another_thing', :line => 47, :message => ''},
        {:test => 'test_a_final_thing', :line => 92, :message => 'BOOM!'},
        ],
      :ignores => [
        {:test => 'test_a_single_thing', :line => 13, :message => 'pay no attention to the test behind the curtain'},
        {:test => 'test_another_thing', :line => 18, :message => 'pay no attention to the:stray colon'},
        {:test => 'test_some_non_void_param_stuff', :line => 53, :message => 'pay no attention to the test behind the curtain'},
        {:test => 'test_some_multiline_test_case_action', :line => 60, :message => 'pay no attention to the test behind the curtain'},
        ],
      :successes => [
        {:test => 'test_a_success_case', :line => 42, :message => ''},
        {:test => 'test_another_success_case', :line => 65, :message => ''},
        {:test => 'test_yet_another_success_case', :line => 78, :message => ''},
        ]
      }
    
    @configurator.expects.extension_testfail.returns('.fail')
    
    @yaml_wrapper.expects.dump('project/build/results/test_a_file.fail', expected_hash)
    
    @utils.process_and_write_results(raw_unity_output, 'project/build/results/test_a_file.pass', 'files/tests/test_a_file.c')
    
  end


  should "write a mixture of test results to a .pass file" do
    
    # clean test fixture output
    raw_unity_output = %Q[
      test_eez.c:13:test_a_single_thing:IGNORE:pay no attention to the test behind the curtain
      test_eez.c:18:test_another_thing:IGNORE:pay no attention to the test behind the curtain
      test_eez.c:30:test_a_success_case:PASS
      test_eez.c:60:test_some_multiline_test_case_action:IGNORE:pay no attention to the stray:colon
      test_eez.c:73:test_another_success_case:PASS
      test_eez.c:83:test_yet_another_success_case:PASS
      6 Tests 0 Failures 3 Ignored
      OK
      ].left_margin(0)
    
    expected_hash = {
      :counts => {:total => 6, :failed => 0, :ignored => 3, :passed => 3},
      :source => {:path => 'files/tests', :file => 'test_eez.c'},
      :failures => [],
      :ignores => [
        {:test => 'test_a_single_thing', :line => 13, :message => 'pay no attention to the test behind the curtain'},
        {:test => 'test_another_thing', :line => 18, :message => 'pay no attention to the test behind the curtain'},
        {:test => 'test_some_multiline_test_case_action', :line => 60, :message => 'pay no attention to the stray:colon'},
        ],
      :successes => [
        {:test => 'test_a_success_case', :line => 30, :message => ''},
        {:test => 'test_another_success_case', :line => 73, :message => ''},
        {:test => 'test_yet_another_success_case', :line => 83, :message => ''},
        ]
      }
    
    @yaml_wrapper.expects.dump('project/build/results/test_eez.pass', expected_hash)
    
    @utils.process_and_write_results(raw_unity_output, 'project/build/results/test_eez.pass', 'files/tests/test_eez.c')
    
  end

end

