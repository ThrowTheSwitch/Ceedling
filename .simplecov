# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Shared SimpleCov configuration. The unit-test suite picks this up through
# SimpleCov's own upward-directory-search autoload (its CWD is this repo). The
# system-test suite's own subprocess boot (spec/support/system/simplecov_boot.rb)
# loads this file explicitly by absolute path instead, since that subprocess's CWD
# is a throwaway deployed project directory, not this repo, when it starts -- the
# autoload search would walk straight past it and find nothing.
#
# track_files (rather than only reporting files a run actually happened to require)
# means a file no test ever touches still shows up at 0% instead of being silently
# absent from the total -- lib/ and bin/ are what the gem actually ships and what
# both test suites exercise; vendor/ is CMock/Unity/CException's own separately
# tested source, not this repo's.
SimpleCov.start do
  track_files 'lib/**/*.rb'
  track_files 'bin/**/*.rb'

  add_filter '/spec/'
  add_filter '/vendor/'
end
