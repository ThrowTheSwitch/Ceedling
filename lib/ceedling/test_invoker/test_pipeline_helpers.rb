# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Small helpers shared by more than one test pipeline stage class. Relies on
# `@reportinator`/`@loginator` already being present via whichever including
# class's own constructor DI provides them, the same way TestInvokerTypes is
# mixed in without any DI wiring of its own.
module TestPipelineHelpers

  # States, in one line, how many targets a build step left untouched because nothing
  # about their antecedents changed -- silence would otherwise read as the step doing
  # nothing at all, indistinguishable from a misconfigured or broken stage.
  def log_skip_summary(task:, count:, noun:, reason: "nothing changed")
    msg = @reportinator.generate_skip_summary( task: task, count: count, noun: noun, reason: reason )
    @loginator.log( msg ) unless msg.nil?
  end

  # Ceedling's own vendor headers/sources (Unity, CMock, CException, the generated
  # ceedling.h) live outside every configured :test/:source/:support/:include root, so
  # any preprocessor invocation resolving a test's own #includes needs this path handed
  # to it directly alongside those configured roots, or it would never find them.
  def vendor_search_paths()
    [@configurator.project_build_vendor_ceedling_path]
  end

  # A dependency-tracker target's staleness is only as accurate as the meta it's
  # registered with -- flags, defines, and search paths all affect a preprocess or
  # compile target's actual output, so all three ride along as meta everywhere a
  # target derived from any of them is registered.
  def dependency_meta(flags:, defines:, search_paths:)
    { flags: flags, defines: defines, search_paths: search_paths }
  end

  # A preprocessing pass falls back to plain, non-directives-only handling either when
  # directives-only support isn't available at all for this toolchain, or when this
  # particular target's own directives-only output failed to generate (see
  # generate_directives_only_output) despite support existing project-wide.
  def directives_only_fallback?(directives_only, directives_only_filepath)
    !directives_only or directives_only_filepath.nil?
  end

  # A Partial mock is Ceedling's own generated content, identifiable by its own naming
  # convention rather than by any real header it corresponds to (it has none).
  def mock_partial?(include)
    include.filename.start_with?( @configurator.cmock_mock_prefix + PARTIAL_FILENAME_PREFIX )
  end

  # A Partial's own module name doubles as its generated source file's basename, so an
  # object list built from #include-derived sources can end up carrying an object for a
  # module that a Partial has already taken over -- this removes those, leaving the
  # Partial's own separately-generated source as the module's only linked object.
  #
  # The original module's own source is still compiled like every other source in the
  # test's compile list (stage 15) -- only its membership among the objects handed to the
  # linker (TestBuildExecutor#stage_build_executables, stage 16) is trimmed, right before
  # linking. Compiling it unconditionally keeps that source's own dependency tracking (and,
  # under coverage profiling -- gcov, Bullseye -- its #line-directive mapping of a Partial's
  # generated code back to the original module's own lines) working the same way it does for
  # every other source, rather than carving out a special case for whether the result of
  # compiling it is ever actually linked.
  def remove_partials_source_objects(objects, configs)
    modules = configs.keys
    objects.delete_if do |filepath|
      modules.include?( File.basename( filepath ).ext() )
    end
  end

end
