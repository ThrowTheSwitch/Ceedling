# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/constants'
require 'valgrind_constants'

class Valgrind < Plugin

    def setup
      @plugin_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))
    end
end

# end blocks always executed following rake run
END {
    # cache our input configurations to use in comparison upon next execution
    @ceedling[:cacheinator].cache_test_config(@ceedling[:setupinator].config_hash) if @ceedling[:task_invoker].invoked?(/^#{VALGRIND_TASK_ROOT}/)
}
