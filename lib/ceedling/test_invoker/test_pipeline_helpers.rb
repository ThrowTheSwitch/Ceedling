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
