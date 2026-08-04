# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/release_invoker/release_invoker_types'

# Thin entry point for a release build -- lifecycle, error handling, and
# dependency-cache open/flush live here; ReleaseBuildPlanner/ReleaseBuildExecutor
# do the actual work. There's no dedicated pipeline-manager class the way
# TestInvoker has TestPipelineManager: a release build has no stop-points or
# conditional stage-skipping to validate or gate, just a fixed handful of
# steps, so sequencing them directly here is proportionate.
class ReleaseInvoker

  include ReleaseInvokerTypes

  constructor(
    :application,
    :plugin_manager,
    :dependinator,
    :loginator,
    :batchinator,
    :release_build_planner,
    :release_build_executor
  )

  # files: nil for a full release build; an Array of one filepath to scope down
  # to a single object -- the ad hoc release:compile:<file>/release:assemble:<file>
  # tasks, which exist to let a project compile one file in isolation without
  # linking or touching artifacts, e.g. for quick syntax/compile-error checking
  # during development.
  def setup_and_invoke(files: nil)
    timestamp_s = SystemWrapper.time_stopwatch_s()
    @plugin_manager.pre_release_build( timestamp_s )

    @dependinator.open( identifier: :release )

    state = ReleaseState.new()

    begin
      @batchinator.build_step( "Determining Objects to be Built", heading: false ) do
        @release_build_planner.plan( state, files: files )
      end

      @batchinator.build_step( "Building Objects" ) do
        @release_build_executor.compile_objects( state )
      end

      if files.nil?
        @batchinator.build_step( "Building Release Artifact" ) do
          @release_build_executor.link( state )
        end

        @batchinator.build_step( "Collecting Artifacts", heading: false ) do
          @release_build_executor.artifactinate( state )
        end
      end

    rescue StandardError => ex
      @application.register_build_failure

      @loginator.log( ex.message, Verbosity::ERRORS, LogLabels::EXCEPTION )
      @loginator.log_debug_backtrace( ex )
    ensure
      # Only a run that touched every release target (the full `release` task,
      # not a single-file compile:/assemble: task) may safely prune cache
      # entries for targets it didn't see this time -- mirrors TestInvoker's
      # own :refresh_dependencies precedent for test:all vs. a partial build.
      @dependinator.flush( refresh_dependencies: files.nil? )
      @plugin_manager.post_release_build( SystemWrapper.time_stopwatch_s() )
    end
  end

end
