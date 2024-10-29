# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/file_path_utils'


desc "Build release target."
task RELEASE_SYM => [:prepare] do
  header = "Release build '#{File.basename( PROJECT_RELEASE_BUILD_TARGET )}'"

  banner = @ceedling[:reportinator].generate_banner( header )

  @ceedling[:loginator].log( banner )
  
  begin
    @ceedling[:plugin_manager].pre_release

    core_objects  = []
    extra_objects = @ceedling[:file_path_utils].form_release_build_objects_filelist( COLLECTION_RELEASE_ARTIFACT_EXTRA_LINK_OBJECTS )

    core_objects.concat( @ceedling[:release_invoker].setup_and_invoke_objects( COLLECTION_RELEASE_BUILD_INPUT ) )
  
    # If we're using libraries, we need to add those to our collection as well
    library_objects = (defined? LIBRARIES_RELEASE && !LIBRARIES_RELEASE.empty?) ? LIBRARIES_RELEASE.flatten.compact : []
    file( PROJECT_RELEASE_BUILD_TARGET => (core_objects + extra_objects + library_objects) )
    Rake::Task[PROJECT_RELEASE_BUILD_TARGET].invoke()

  rescue StandardError => ex
    @ceedling[:application].register_build_failure

    @ceedling[:loginator].log( ex.message, Verbosity::ERRORS, LogLabels::EXCEPTION )

    # Debug backtrace (only if debug verbosity)
    @ceedling[:loginator].log_debug_backtrace( ex )
  ensure
    @ceedling[:plugin_manager].post_release  
  end
end
