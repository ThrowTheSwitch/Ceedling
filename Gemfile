# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

source "http://rubygems.org/"

gem "bundler", "~> 2.5"

# Testing tools
gem "rspec", "~> 3.8"
gem "rake", ">= 12", "< 14"
gem "rr"
gem "require_all"

# Ceedling dependencies
gem "diy", "~> 1.1"
gem "constructor", "~> 2"
gem "thor", "~> 1.3"
gem "deep_merge", "~> 1.2"

# `erb` & `benchmark` have been removed from the default gems in some Ruby versions Ceedling supports.
# These must be declared explicitly for plain `gem install` (non-Bundler) users to successfully span supported Ruby versions.
gem "erb", ">= 2.2"
gem "benchmark", ">= 0.3"

gem "unicode-display_width", "~> 3.1"
gem "parallel", "~> 1.26"
