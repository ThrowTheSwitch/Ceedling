# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Setup our load path:
[ 
  'lib',
  'test',
].each do |dir|
  $LOAD_PATH.unshift( File.join( File.expand_path(File.dirname(__FILE__) + "/../"), dir) )
end
