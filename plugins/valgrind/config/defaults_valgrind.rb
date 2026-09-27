# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================


# `:optional => true` keeps Ceedling's project-wide tool validation from failing a
# build merely because this plugin is enabled. Valgrind is an external tool that runs
# on Linux and other Unix-like systems only, so an enabled plugin is not evidence the
# executable exists. The plugin validates it for real at `valgrind:` task time instead.
# See Valgrind#validate_environment!.
DEFAULT_VALGRIND_TOOL = {
    :executable => FilePathUtils.os_executable_ext('valgrind').freeze,
    :name => 'default_valgrind'.freeze,
    :optional => true.freeze,
    :arguments => [].freeze  # Arguments built dynamically by the plugin from :valgrind: :arguments: config
    }

def get_default_config
    return :tools => {
        :valgrind => DEFAULT_VALGRIND_TOOL
    }
end