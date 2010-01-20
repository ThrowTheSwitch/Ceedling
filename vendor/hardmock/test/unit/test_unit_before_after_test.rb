require File.expand_path(File.dirname(__FILE__) + "/../test_helper") 

class TestUnitBeforeAfter < Test::Unit::TestCase

  #
  # after_teardown
  #

  it "adds TestCase.after_teardown hook for appending post-teardown actions" do
    write_and_run_test :use_after_teardown => true

    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "THE TEARDOWN",
      "1st after_teardown",
      "2nd after_teardown",
      "Finished in"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 0
  end

  should "execute all after_teardowns, even if the main teardown flunks" do
    write_and_run_test :use_after_teardown => true, :flunk_in_teardown => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "F",
      "1st after_teardown",
      "2nd after_teardown",
      "Finished in",
      "1) Failure:",
      "test_something(MyExampleTest) [_test_file_temp.rb:20]:",
      "FLUNK IN TEARDOWN"
    see_results :tests => 1, :assertions => 1, :failures => 1, :errors => 0
  end

  should "execute all after_teardowns, even if the main teardown explodes" do
    write_and_run_test :use_after_teardown => true, :raise_in_teardown => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "E",
      "1st after_teardown",
      "2nd after_teardown",
      "Finished in",
      "RuntimeError: ERROR IN TEARDOWN"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 1
  end

  should "execute all after_teardowns, even if some of them flunk" do
    write_and_run_test :use_after_teardown => true, :flunk_in_after_teardown => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "THE TEARDOWN",
      "1st after_teardown",
      "F",
      "2nd after_teardown",
      "Finished in",
      "1) Failure:",
      "test_something(MyExampleTest) [_test_file_temp.rb:7]:",
      "Flunk in first after_teardown",
      "2) Failure:",
      "test_something(MyExampleTest) [_test_file_temp.rb:10]:",
      "Flunk in second after_teardown"
    see_results :tests => 1, :assertions => 2, :failures => 2, :errors => 0
  end

  should "execute all after_teardowns, even if some of them explode" do
    write_and_run_test :use_after_teardown => true, :raise_in_after_teardown => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "THE TEARDOWN",
      "1st after_teardown",
      "E",
      "2nd after_teardown",
      "Finished in",
      "RuntimeError: Error in first after_teardown",
      "RuntimeError: Error in second after_teardown"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 2
  end

  it "will run after_teardowns in the absence of a regular teardown" do
    write_and_run_test :omit_teardown => true, :use_after_teardown => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "1st after_teardown",
      "2nd after_teardown",
      "Finished in"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 0
  end

  should "not interfere with normal test writing" do
    write_and_run_test
    see_in_order "Loaded suite",
      "THE SETUP",
      "A TEST",
      "THE TEARDOWN",
      "Finished in"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 0
  end

  it "provides a cleaned-up backtrace" do
    write_and_run_test :with_failure => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A FAILING TEST",
      "F", "THE TEARDOWN",
      "Finished in",
      "1) Failure:",
      "test_something(MyExampleTest) [_test_file_temp.rb:17]:",
      "Instrumented failure.",
      "<false> is not true."
    see_results :tests => 1, :assertions => 1, :failures => 1, :errors => 0
  end

  it "provides a cleaned-up backtrace, but not TOO cleaned up" do
    write_and_run_test :with_failure => true, :use_helpers => true
    see_in_order "Loaded suite",
      "THE SETUP",
      "A FAILING TEST",
      "F", "THE TEARDOWN",
      "Finished in",
      "1) Failure:",
      "test_something(MyExampleTest)\n",
      "[_test_file_temp.rb:25:in `tripwire'",
      "_test_file_temp.rb:21:in `my_helper'",
      "_test_file_temp.rb:17:in `test_something']:",
      "Instrumented failure.",
      "<false> is not true."
    see_results :tests => 1, :assertions => 1, :failures => 1, :errors => 0
  end

  should "not interfere with passthrough exception types" do
    if is_modern_test_unit?
      write_and_run_test :raise_nasty_in_test => true
      see_in_no_particular_order "Loaded suite", 
        "THE TEARDOWN",
        "_test_file_temp.rb:16:in `test_something': NASTY ERROR (NoMemoryError)"
      see_no_results
    end
  end

  #
  # before_setup
  #

  it "adds TestCase.before_setup hook for prepending pre-setup actions" do
    write_and_run_test :use_before_setup => true
    see_in_order "Loaded suite",
      "3rd before_setup",
      "2nd before_setup",
      "1st before_setup",
      "THE SETUP",
      "A TEST",
      "THE TEARDOWN",
      "Finished in"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 0
  end

  should "stop executing the test on the first failure withing a before_setup action" do 
    write_and_run_test :use_before_setup => true, :flunk_in_before_setup => true
    see_in_order "Loaded suite",
      "3rd before_setup",
      "2nd before_setup",
      "FTHE TEARDOWN",
      "1) Failure:",
      "test_something(MyExampleTest) [_test_file_temp.rb:10]:",
      "Flunk in 2nd before_setup."
    see_results :tests => 1, :assertions => 1, :failures => 1, :errors => 0
  end

  should "stop executing the test on the first error within a before_setup action" do
    write_and_run_test :use_before_setup => true, :raise_in_before_setup => true
    see_in_order "Loaded suite",
      "3rd before_setup",
      "2nd before_setup",
      "ETHE TEARDOWN",
      "Finished in",
      "test_something(MyExampleTest):",
      "RuntimeError: Error in 2nd before_setup",
      "_test_file_temp.rb:10",
      "/hardmock/lib/test_unit_before_after.rb:", ":in `call'"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 1
  end

  it "will run before_setup actions in the absence of a regular setup" do
    write_and_run_test :omit_setup => true, :use_before_setup => true
    see_in_order "Loaded suite",
      "3rd before_setup",
      "2nd before_setup",
      "1st before_setup",
      "A TEST",
      "THE TEARDOWN",
      "Finished in"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 0
  end

  it "allows before_setup and after_teardown to be used at the same time" do
    write_and_run_test :use_before_setup => true, :use_after_teardown => true
    see_in_order "Loaded suite",
      "3rd before_setup",
      "2nd before_setup",
      "1st before_setup",
      "A TEST",
      "THE TEARDOWN",
      "1st after_teardown",
      "2nd after_teardown",
      "Finished in"
    see_results :tests => 1, :assertions => 0, :failures => 0, :errors => 0
  end

  #
  # HELPERS
  #

  def teardown
    remove_test
  end

  def test_filename
    "_test_file_temp.rb"
  end 

  def remove_test
    rm_f test_filename
  end

  def write_and_run_test(opts={})
    write(test_filename, generate_test_code(opts))
    run_test
  end

  def run_test
    @output = `ruby #{test_filename} 2>&1`
  end


  def write(fname, code)
    File.open(fname,"w") do |f|
      f.print code     
    end
  end

  def show_output
    puts "-- BEGIN TEST OUTPUT"
    puts @output
    puts "-- END TEST OUTPUT"
  end

  def see_in_order(*phrases)
    idx = 0
    phrases.each do |txt|
      idx = @output.index(txt, idx)
      if idx.nil?
        if @output.index(txt)
          flunk "Phrase '#{txt}' is out-of-order in test output:\n#{@output}"
        else
          flunk "Phrase '#{txt}' not found in test output:\n#{@output}"
        end
      end
    end
  end

  def see_in_no_particular_order(*phrases)
    phrases.each do |txt|
      assert_not_nil @output.index(txt), "Didn't see '#{txt}' in test output:\n#{@output}"
    end
  end

  def see_results(opts)
    if @output =~ /(\d+) tests, (\d+) assertions, (\d+) failures, (\d+) errors/
      tests, assertions, failures, errors = [ $1, $2, $3, $4 ]
      [:tests, :assertions, :failures, :errors].each do |key|
        eval %{assert_equal(opts[:#{key}].to_s, #{key}, "Wrong number of #{key} in report") if opts[:#{key}]}
      end
    else
      flunk "Didn't see the test results report line"
    end
  end

  def see_no_results
    if @output =~ /\d+ tests, \d+ assertions, \d+ failures, \d+ errors/
      flunk "Should not have had a results line:\n#{@output}"
    end
  end

  def lib_dir
    File.expand_path(File.dirname(__FILE__) + "/../../lib")
  end

  def generate_test_code(opts={})

    if opts[:with_failure] or opts[:raise_nasty_in_test]
      test_method_code = generate_failing_test("test_something", opts)
    else
      test_method_code = generate_passing_test("test_something")
    end


    requires_for_ext = ''
    if opts[:use_before_setup] or opts[:use_after_teardown]
      requires_for_ext =<<-RFE
        $: << "#{lib_dir}"
        require 'test_unit_before_after'
      RFE
    end

    before_setups = ''
    if opts[:use_before_setup]
      add_on_two = ""
      if opts[:flunk_in_before_setup]
        add_on_two = %{; test.flunk "Flunk in 2nd before_setup"}
      elsif opts[:raise_in_before_setup]
        add_on_two = %{; raise "Error in 2nd before_setup"}
      end
      before_setups =<<-BSTS
        Test::Unit::TestCase.before_setup do |test| 
          puts "1st before_setup"
        end
        Test::Unit::TestCase.before_setup do |test| 
          puts "2nd before_setup" #{add_on_two}
        end
        Test::Unit::TestCase.before_setup do |test| 
          puts "3rd before_setup"
        end

      BSTS
    end


    setup_code =<<-SC
      def setup
        puts "THE SETUP"
      end
    SC
    if opts[:omit_setup]
      setup_code = ""
    end

    after_teardowns = ''
    if opts[:use_after_teardown]
      add_on_one = ""
      add_on_two = ""
      if opts[:flunk_in_after_teardown]
        add_on_one = %{; test.flunk "Flunk in first after_teardown"}
        add_on_two = %{; test.flunk "Flunk in second after_teardown"}
      elsif opts[:raise_in_after_teardown]
        add_on_one = %{; raise "Error in first after_teardown"}
        add_on_two = %{; raise "Error in second after_teardown"}
      end
      after_teardowns =<<-ATDS
        Test::Unit::TestCase.after_teardown do |test| 
          puts "1st after_teardown" #{add_on_one}
        end
        Test::Unit::TestCase.after_teardown do |test| 
          puts "2nd after_teardown" #{add_on_two}
        end
      ATDS
    end

    teardown_code =<<-TDC
      def teardown
        puts "THE TEARDOWN"
      end
    TDC
    if opts[:flunk_in_teardown]
      teardown_code =<<-TDC
        def teardown
          flunk "FLUNK IN TEARDOWN"
        end
      TDC
    elsif opts[:raise_in_teardown]
      teardown_code =<<-TDC
        def teardown
          raise "ERROR IN TEARDOWN"
        end
      TDC
    end
    if opts[:omit_teardown]
      teardown_code = ""
    end

    str = <<-TCODE
    require 'test/unit'
    #{requires_for_ext}

    #{before_setups} #{after_teardowns}
    
    class MyExampleTest < Test::Unit::TestCase
      #{setup_code}
      #{teardown_code}
      #{test_method_code}
    end
    TCODE
  end

  def generate_passing_test(tname)
    str = <<-TMETH
      def #{tname}
        puts "A TEST"
      end
    TMETH
  end

  def generate_failing_test(tname, opts={})
    str = "NOT DEFINED?"
    if opts[:raise_nasty_in_test]
      str = <<-TMETH
        def #{tname}
          raise NoMemoryError, "NASTY ERROR"
        end
      TMETH

    elsif opts[:use_helpers]
      str = <<-TMETH
        def #{tname}
          puts "A FAILING TEST"
          my_helper
        end

        def my_helper
          tripwire
        end

        def tripwire
          assert false, "Instrumented failure"
        end
      TMETH
    else
      str = <<-TMETH
        def #{tname}
          puts "A FAILING TEST"
          assert false, "Instrumented failure"
        end
      TMETH
    end
    return str
  end

  def is_modern_test_unit?
    begin
      Test::Unit::TestCase::PASSTHROUGH_EXCEPTIONS
      return true
    rescue NameError
      return false
    end
  end

end
