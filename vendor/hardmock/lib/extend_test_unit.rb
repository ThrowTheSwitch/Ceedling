
require 'test/unit/testcase'
class Test::Unit::TestCase 
  include Hardmock
end

require 'test_unit_before_after'
Test::Unit::TestCase.before_setup do |test|
  test.prepare_hardmock_control
end

Test::Unit::TestCase.after_teardown do |test|
  test.verify_mocks
end
