# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

BUILTIN_MIXINS = {
  # Mixin name as symbol => mixin config hash
  # :mixin => {}
}

_vendor = defined?(CEEDLING_APPCFG) ? CEEDLING_APPCFG[:ceedling_vendor_path] : File.expand_path( File.join( File.dirname(__FILE__), '..', 'vendor' ) )
BUILTIN_MIXIN_LOAD_PATHS = [ File.join( _vendor, UNITY_ROOT_PATH, 'test', 'targets' ) ].freeze
