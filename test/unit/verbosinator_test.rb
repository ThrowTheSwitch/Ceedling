require File.dirname(__FILE__) + '/../unit_test_helper'
require 'verbosinator'


class VerbosinatorTest < Test::Unit::TestCase

  def setup
    objects = create_mocks(:configurator)
    @verbosinator = Verbosinator.new(objects)
  end

  def teardown
  end
  
  
  should "allow output if verbosity level of ERRORS" do
    @configurator.expects.project_verbosity.returns(Verbosity::ERRORS)
    @configurator.expects.project_verbosity.returns(Verbosity::ERRORS)
    @configurator.expects.project_verbosity.returns(Verbosity::ERRORS)
    @configurator.expects.project_verbosity.returns(Verbosity::ERRORS)

    assert(@verbosinator.should_output?(Verbosity::ERRORS))
    assert_equal(false, @verbosinator.should_output?(Verbosity::COMPLAIN))
    assert_equal(false, @verbosinator.should_output?(Verbosity::NORMAL))
    assert_equal(false, @verbosinator.should_output?(Verbosity::OBNOXIOUS))
  end

  should "allow output if verbosity level of COMPLAIN" do
    @configurator.expects.project_verbosity.returns(Verbosity::COMPLAIN)
    @configurator.expects.project_verbosity.returns(Verbosity::COMPLAIN)
    @configurator.expects.project_verbosity.returns(Verbosity::COMPLAIN)
    @configurator.expects.project_verbosity.returns(Verbosity::COMPLAIN)

    assert(@verbosinator.should_output?(Verbosity::ERRORS))
    assert(@verbosinator.should_output?(Verbosity::COMPLAIN))
    assert_equal(false, @verbosinator.should_output?(Verbosity::NORMAL))
    assert_equal(false, @verbosinator.should_output?(Verbosity::OBNOXIOUS))
  end

  should "allow output if verbosity level of NORMAL" do
    @configurator.expects.project_verbosity.returns(Verbosity::NORMAL)
    @configurator.expects.project_verbosity.returns(Verbosity::NORMAL)
    @configurator.expects.project_verbosity.returns(Verbosity::NORMAL)
    @configurator.expects.project_verbosity.returns(Verbosity::NORMAL)

    assert(@verbosinator.should_output?(Verbosity::ERRORS))
    assert(@verbosinator.should_output?(Verbosity::COMPLAIN))
    assert(@verbosinator.should_output?(Verbosity::NORMAL))
    assert_equal(false, @verbosinator.should_output?(Verbosity::OBNOXIOUS))
  end

  should "allow output if verbosity level of OBNOXIOUS" do
    @configurator.expects.project_verbosity.returns(Verbosity::OBNOXIOUS)
    @configurator.expects.project_verbosity.returns(Verbosity::OBNOXIOUS)
    @configurator.expects.project_verbosity.returns(Verbosity::OBNOXIOUS)
    @configurator.expects.project_verbosity.returns(Verbosity::OBNOXIOUS)

    assert(@verbosinator.should_output?(Verbosity::ERRORS))
    assert(@verbosinator.should_output?(Verbosity::COMPLAIN))
    assert(@verbosinator.should_output?(Verbosity::NORMAL))
    assert(@verbosinator.should_output?(Verbosity::OBNOXIOUS))
  end

end

