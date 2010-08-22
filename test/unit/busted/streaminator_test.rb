require File.dirname(__FILE__) + '/../unit_test_helper'
require 'streaminator'
require 'constants'


class StreaminatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:verbosinator, :stream_wrapper)
    @streaminator = Streaminator.new(objects)
  end

  def teardown
  end
  
  
  should "write to stdout & flush if sufficient verbosity level" do
    @verbosinator.expects.should_output?(Verbosity::OBNOXIOUS).returns(true)
    
    @stream_wrapper.expects.stdout_puts("Hey. You lookin at me??")
    @stream_wrapper.expects.stdout_flush

    @streaminator.stdout_puts("Hey. You lookin at me??", Verbosity::OBNOXIOUS)
  end

  should "not write to stdout or flush because insufficient verbosity level" do
    @verbosinator.expects.should_output?(Verbosity::NORMAL).returns(false)
    
    @streaminator.stdout_puts("Hey. You lookin at me??", Verbosity::NORMAL)
  end


  should "write to stderr & flush if sufficient verbosity level" do
    @verbosinator.expects.should_output?(Verbosity::ERRORS).returns(true)
    
    @stream_wrapper.expects.stderr_puts("Hey, yah. I'm lookin at you.")
    @stream_wrapper.expects.stderr_flush

    @streaminator.stderr_puts("Hey, yah. I'm lookin at you.", Verbosity::ERRORS)
  end

  should "not write to stderr or flush because insufficient verbosity level" do
    @verbosinator.expects.should_output?(Verbosity::NORMAL).returns(false)
    
    @streaminator.stderr_puts("Hey, yah. I'm lookin at you.", Verbosity::NORMAL)
  end

end

