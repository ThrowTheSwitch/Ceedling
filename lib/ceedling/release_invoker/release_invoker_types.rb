# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module ReleaseInvokerTypes

  # Carries all state for a single release build invocation. Unlike TestInvokerTypes'
  # PipelineState/Testable pair, there's exactly one artifact here, not N independent
  # ones, so this one struct holds both the flat build plan and the shared,
  # once-resolved compile/link inputs every object uses alike.
  ReleaseState = Struct.new(
    :objects,           # Array<String> — object filepaths to compile/link; each
                         # object's real source is resolved at compile time via
                         # FileFinder, mirroring TestBuildExecutor#stage_build_objects
    :compile_flags, :assemble_flags, :link_flags,
    :defines,
    :search_paths,
    :executable_rebuilt, # Boolean — set by ReleaseBuildExecutor#link, read by
                          # #artifactinate to decide whether to copy the artifact.
                          # Carried here rather than re-querying the dependency
                          # tracker: by then the executable has already been marked
                          # fresh (if it was rebuilt), so a fresh staleness query
                          # would always answer false regardless of what happened.
    keyword_init: true
  ) do
    def initialize(**kwargs)
      kwargs[:objects] ||= []
      super(**kwargs)
    end
  end

end
