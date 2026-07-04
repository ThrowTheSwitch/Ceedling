# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/file_path_utils'


desc "Build release target"
task RELEASE_SYM => [:prepare] do  
  begin
    timestamp_s = SystemWrapper.time_stopwatch_s()
    @ceedling[:plugin_manager].pre_release_build( timestamp_s )

    objects = @ceedling[:release_invoker].collect_release_build_objects()

    @ceedling[:release_invoker].setup_and_invoke_objects( objects )

    file( PROJECT_RELEASE_BUILD_TARGET => (objects) )

    @ceedling[:release_invoker].setup_and_invoke_binary( PROJECT_RELEASE_BUILD_TARGET )

  rescue StandardError => ex
    @ceedling[:application].register_build_failure

    @ceedling[:loginator].log( ex.message, Verbosity::ERRORS, LogLabels::EXCEPTION )

    # Debug backtrace (only if debug verbosity)
    @ceedling[:loginator].log_debug_backtrace( ex )
  ensure
    @ceedling[:plugin_manager].post_release_build( SystemWrapper.time_stopwatch_s() )
  end
end
