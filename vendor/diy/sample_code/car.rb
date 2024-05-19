# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


class Car
  attr_reader :engine, :chassis
  def initialize(arg_hash)
    @engine = arg_hash[:engine]
    @chassis = arg_hash[:chassis]
  end
end
