# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Runs a test executable with each sanitizer's runtime options set for it alone
DEFAULT_SANITIZE_FIXTURE_TOOL = {
    :executable => 'env'.freeze,
    :name => 'default_sanitize_fixture'.freeze,
    :optional => true.freeze,
    :arguments => [].freeze  # Option settings and the test executable come from the plugin
    }

def get_default_config
    return :tools => {
        :sanitize_fixture => DEFAULT_SANITIZE_FIXTURE_TOOL
    }
end
