# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

##
## version.rb is run as:
##  1. An executable script for a Ceedling tag used in the release build process
##     `ruby Ceedling/lib/version.rb`
##  2. As a code module of constants consumed by Ruby's gem building process
##
## The version reported here distinguishes a published gem from any other build.
## Only the release pipeline produces a bare version. Everything else carries a
## `.dev` suffix, so `ceedling version` says plainly which kind of install it is.
##

module Ceedling
  module Version
    # Target version for the current release cycle. Maintained by hand, one edit
    # per minor or major cycle. Never edited to match a release tag. The release
    # pipeline rewrites this line from the tag that triggered it.
    BASE = '1.2.0'

    # Marker for a build the release pipeline did not produce. That pipeline
    # empties this line, so a published gem reports a bare version while a local
    # build reports `.dev`. RubyGems reads a `.dev` version as a prerelease, which
    # also keeps a local gem from ever satisfying a plain `gem install ceedling`.
    DEV = '.dev'

    # Appended at most once. A BASE that already carries the marker cannot yield
    # `1.2.0.dev.dev`. An emptied DEV is a no-op here too, since every string ends
    # with the empty string.
    GEM = BASE.end_with?( DEV ) ? BASE : "#{BASE}#{DEV}"
    TAG = GEM

    # If run as a script print Ceedling's version to $stdout
    puts( TAG ) if (__FILE__ == $0)
  end
end
