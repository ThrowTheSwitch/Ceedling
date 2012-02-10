require File.dirname(__FILE__) + '/../unit_test_helper'
require 'rubygems'
require 'rake'


class RakeRulesCmockTest < Test::Unit::TestCase

  def setup
    rake_setup('rakefile_rules_cmock.rb', :file_finder, :generator)
  end

  def teardown
    Rake.application = nil
  end
  
  
  should "recognize missing mock files, find their source, and execute rake tasks from the rule for mock generation" do
    # default values as set in test_helper
    redefine_global_constant('CMOCK_MOCK_PREFIX', 'mock_')
    redefine_global_constant('EXTENSION_SOURCE', '.c')

    # reload rakefile with new global constants
    setup()

    mock_src1 = 'files/source/thing.h'
    mock_src2 = 'stuff.h'
    mock_src3 = 'files/source/WooDoggie.h'
    mock1     = 'files/mocks/mock_thing.c'
    mock2     = 'mock_stuff.c'
    mock3     = 'files/mocks/mock_WooDoggie.c'

    # fake out rake so it won't look for the header files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, mock_src1)
    @rake.define_task(Rake::FileTask, mock_src2)
    @rake.define_task(Rake::FileTask, mock_src3)

    # set up expectations
    @file_finder.expects.find_mockable_header(mock1).returns(mock_src1)
    @generator.expects.generate_mock(mock_src1)
    @file_finder.expects.find_mockable_header(mock2).returns(mock_src2)
    @generator.expects.generate_mock(mock_src2)
    @file_finder.expects.find_mockable_header(mock3).returns(mock_src3)
    @generator.expects.generate_mock(mock_src3)

    # invoke the mock creation rule under test
    @rake[mock1].invoke
    @rake[mock2].invoke
    @rake[mock3].invoke
  end

  should "handle alternate mock prefixes and source extensions for mock generation rule" do
    redefine_global_constant('CMOCK_MOCK_PREFIX', 'Mock')
    redefine_global_constant('EXTENSION_SOURCE', '.x')

    # reload rakefile with new global constants
    setup()

    mock_src1 = 'files/source/IngBird.h'
    mock1     = 'files/mocks/MockIngBird.x'

    # fake out rake so it won't look for the header files on disk and find they don't exist.
    # by creating file tasks we're telling rake there's a means to create these files that don't exist (but we never use the mechanism).
    @rake.define_task(Rake::FileTask, mock_src1)

    # set up expectations
    @file_finder.expects.find_mockable_header(mock1).returns(mock_src1)
    @generator.expects.generate_mock(mock_src1)

    # invoke the mock creation rule under test
    @rake[mock1].invoke
  end

end
