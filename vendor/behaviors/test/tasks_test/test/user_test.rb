# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


require 'test/unit'
require 'behaviors'

require 'user'

class UserTest < Test::Unit::TestCase
  extend Behaviors

  def setup
  end

  should "be able set user name and age during construction"
  should "be able to get user name and age"
  should "be able to ask if a user is an adult"
  def test_DELETEME
  end
end
