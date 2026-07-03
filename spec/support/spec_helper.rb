# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'require_all'
require 'constructor'
require 'simplecov'

SimpleCov.start do
  track_files "{bin,lib,plugins}/**/*.rb"
  add_filter "/spec/"
  add_filter "/config/"
  add_filter "/vendor/"
end

RSpec.configure do |config|
  config.raise_errors_for_deprecations!
end

here = File.dirname(__FILE__)

$: << File.join(here, '../../bin')
$: << File.join(here, '../../lib')
$: << File.join(here, '../../vendor/cmock/lib')
$: << File.join(here, '../../vendor/unity/auto')
