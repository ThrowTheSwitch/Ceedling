# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/defaults'
require 'ceedling/release_invoker/release_invoker_types'

# Determines what a release build needs: the object list and the compile/
# assemble/link inputs every one of those objects shares alike. No tool
# invocation and no dependency-tracker registration happens here -- that's
# ReleaseBuildExecutor's concern; this class only figures out the plan.
class ReleaseBuildPlanner

  include ReleaseInvokerTypes

  constructor(
    :configurator,
    :loginator,
    :reportinator,
    :flaginator,
    :defineinator,
    :file_path_utils,
    :file_wrapper
  )

  # files: nil for a full release build (every configured release source, plus
  # extra link-only objects); an Array of one filepath to scope down to a
  # single object, as the ad hoc release:compile:<file>/release:assemble:<file>
  # tasks do.
  def plan(state, files: nil)
    tailor_release_tools()

    sources =
      if files.nil?
        @configurator.collection_release_build_input +
          @configurator.collection_release_artifact_extra_link_objects
      else
        files.dup
      end

    state.objects        = @file_path_utils.form_release_build_objects_filelist( sources )
    state.compile_flags   = @flaginator.flag_down( context: RELEASE_SYM, operation: OPERATION_COMPILE_SYM )
    state.assemble_flags  = @flaginator.flag_down( context: RELEASE_SYM, operation: OPERATION_ASSEMBLE_SYM )
    state.link_flags      = @flaginator.flag_down( context: RELEASE_SYM, operation: OPERATION_LINK_SYM )
    state.defines         = @defineinator.defines( subkey: RELEASE_SYM )
    state.search_paths    = @configurator.collection_paths_include
  end

  private

  # Shared libraries and static archives need compiler/linker argument tags
  # (-fPIC, -shared, or swapping the linker for `ar` outright) that a plain
  # executable target doesn't -- derived once per build from the release
  # target's own file extension, mutating the resolved tool config in place
  # exactly as gcc's own default release tools expect to be used. Skipped
  # entirely for a project that's already configured its own compiler tool
  # (a custom :tools ↳ :release_compiler means these Ceedling-authored
  # defaults-only tags would be presumptuous to apply).
  def tailor_release_tools()
    compiler = @configurator.tools_release_compiler
    linker   = @configurator.tools_release_linker

    return unless compiler[:executable] == DEFAULT_RELEASE_COMPILER_TOOL[:executable]

    case File.extname( @configurator.project_release_build_target )
    when '.so'
      compiler[:arguments] << '-fPIC' unless compiler[:arguments].include?('-fPIC')
      linker[:arguments] << '-shared' unless linker[:arguments].include?('-shared')
    when '.a'
      compiler[:arguments] << '-fPIC' unless compiler[:arguments].include?('-fPIC')
      linker[:executable] = 'ar'
      linker[:arguments]  = ['rcs', '${2}', '${1}']
    end
  end

end
