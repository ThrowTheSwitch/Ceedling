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
# absent from the total -- lib/, bin/, and plugins/ are what the gem actually ships
# and what both test suites exercise; vendor/ is CMock/Unity/CException's own
# separately tested source, not this repo's. The /spec/ and /vendor/ filters below
# also cover the handful of plugins with their own nested spec/vendor code (e.g.
# plugins/fff/spec/, plugins/fff/vendor/fff/), not just this repo's own top-level
# spec/ and vendor/.
#
# One track_files call with a brace-glob covering all three trees, not three
# separate calls -- track_files stores a single glob rather than accumulating one,
# so each call replaces whatever the previous call set rather than adding to it.
#
# Grouped into the same three trees as a report's own tabs, so a report reads as
# "how well is each shipped piece covered" rather than one flat file list.
SimpleCov.start do
  track_files '{lib,bin,plugins}/**/*.rb'

  add_filter '/spec/'
  add_filter '/vendor/'

  # Anchored to the root of each tree -- a plain substring match (e.g. '/lib/')
  # would also catch lib/ceedling/plugins/plugin_manager.rb (a real lib/
  # subdirectory) into the plugins group, or plugins/gcov/lib/gcov.rb (a
  # plugin's own lib/ subdirectory) into the lib group.
  add_group 'bin', %r{\A/bin/}
  add_group 'lib', %r{\A/lib/}
  add_group 'plugins', %r{\A/plugins/}
end
