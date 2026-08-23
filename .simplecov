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
# `.simplecov` is configuration only -- SimpleCov.configure, not SimpleCov.start.
# Calling `.start` from this file is deprecated as of SimpleCov 1.x (tracking
# would still begin for backward compatibility, but with a nagging warning on
# every run). Each real entry point (spec/support/spec_helper.rb,
# spec/support/system/simplecov_boot.rb, plugins/fff/spec/spec_helper.rb) loads
# this config, then calls the bare `SimpleCov.start` that actually begins
# tracking, once for its own process.
#
# cover (rather than only reporting files a run actually happened to require)
# means a file no test ever touches still shows up at 0% instead of being silently
# absent from the total -- lib/, bin/, and plugins/ are what the gem actually ships
# and what both test suites exercise; vendor/ is CMock/Unity/CException's own
# separately tested source, not this repo's. The /spec/ and /vendor/ filters below
# also cover the handful of plugins with their own nested spec/vendor code (e.g.
# plugins/fff/spec/, plugins/fff/vendor/fff/), not just this repo's own top-level
# spec/ and vendor/.
#
# One cover call with a brace-glob covering all three trees.
#
# Grouped into the same three trees as a report's own tabs, so a report reads as
# "how well is each shipped piece covered" rather than one flat file list.
SimpleCov.configure do
  cover '{lib,bin,plugins}/**/*.rb'

  skip '/spec/'
  skip '/vendor/'

  # Root-of-lib/ files (lib/snapshot.rb, lib/ceedling.rb, lib/version.rb) are
  # tiny require/entry-point shims, not business logic -- anchored so it
  # doesn't also catch lib/ceedling/**, which is exactly what should still count.
  skip %r{\A/lib/[^/]+\.rb\z}

  # Thin adapters over Ruby stdlib/OS calls (file_wrapper.rb, system_wrapper.rb,
  # yaml_wrapper.rb, bin/actions_wrapper.rb, etc.) -- existing tests stub around
  # these rather than exercise them directly, so they read as permanently
  # low/zero coverage noise rather than a real gap.
  #
  # A String argument here is path-segment-aware as of SimpleCov 1.x (must
  # appear as a whole segment between "/" boundaries) -- deliberately a bare
  # Regexp instead, since "_wrapper" is a fragment of a segment
  # (file_wrapper.rb), not a whole one, and needs a true substring match.
  skip(/_wrapper/)

  # Anchored to the root of each tree -- a plain substring match (e.g. '/lib/')
  # would also catch lib/ceedling/plugins/plugin_manager.rb (a real lib/
  # subdirectory) into the plugins group, etc.
  group 'bin', %r{\A/bin/}
  group 'lib', %r{\A/lib/ceedling/}
  group 'plugins', %r{\A/plugins/}
end
