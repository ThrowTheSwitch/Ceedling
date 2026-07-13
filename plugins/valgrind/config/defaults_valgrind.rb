# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


DEFAULT_VALGRIND_TOOL = {
    :executable => FilePathUtils.os_executable_ext('valgrind').freeze,
    :name => 'default_valgrind'.freeze,
    :optional => false.freeze,
    :arguments => [].freeze  # Arguments built dynamically by the plugin from :valgrind: :arguments: config
    }

def get_default_config
    return :tools => {
        :valgrind => DEFAULT_VALGRIND_TOOL
    }
end