# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

##
## version.rb is run as:
##  1. An executable script for a Ceedling tag used in the release build process
##     `ruby Ceedling/lib/version.rb`
##  2. As a code module of constants consumed by Ruby's gem building process
##

module Ceedling
  module Version
    # Convenience constants for gem building, etc.
    GEM = '1.0.0'
    TAG = GEM

    # If run as a script print Ceedling's version to $stdout
    puts( TAG ) if (__FILE__ == $0)
  end
end
