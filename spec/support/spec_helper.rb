# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'require_all'
require 'constructor'

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end

here = File.dirname(__FILE__)

$: << File.join(here, '../../bin')
$: << File.join(here, '../../lib')
$: << File.join(here, '../../vendor/cmock/lib')
$: << File.join(here, '../../vendor/unity/auto')
