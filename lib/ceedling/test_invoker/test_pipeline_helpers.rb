# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/path_mirror'

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

  # Logs a step of a test's build, naming the test and its file
  def log_module_progress(operation, testable, verbosity = Verbosity::NORMAL, label = LogLabels::AUTO)
    msg = @reportinator.generate_module_progress(
      operation:   operation,
      module_name: testable.name,
      filename:    File.basename( testable.filepath )
    )
    @loginator.log( msg, verbosity, label )
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
  #
  # `tools:` carries the config for whichever :tools entry (or entries) actually
  # ran to produce this target -- a repointed :executable, an added argument, a
  # changed :name or :optional/:stderr_redirect setting should all invalidate the
  # target the same as a changed flag would, even though none of those live in
  # `flags`. Defaults to an empty list for a caller with no shell tool of its own.
  #
  # `preprocess_force_fallback:` defaults to this run's actual
  # :test_build ↳ :preprocess_force_fallback setting, so every ordinary caller
  # picks it up without having to ask for it explicitly -- toggling that setting
  # between runs, with nothing else changed, should still invalidate whatever a
  # preprocessing pass produced.
  #
  # `partials:` and `isolated:` are left out of the returned hash entirely when not given,
  # so a caller with nothing to do with Partials or header isolation never carries a
  # meaningless `nil`.
  def dependency_meta(flags:, defines:, search_paths:, tools: [], preprocess_force_fallback: @configurator.test_build_preprocess_force_fallback, partials: nil, isolated: nil)
    meta = { flags: flags, defines: defines, search_paths: search_paths, tools: tools, preprocess_force_fallback: preprocess_force_fallback }
    meta[:partials] = partials unless partials.nil?
    meta[:isolated] = isolated unless isolated.nil?
    meta
  end

  # Registers the project files a preprocessor's output entered as `target`'s
  # dependencies, as a compile registers its .d file. Files below the build root, such as
  # stand-ins and generated mocks, derive from those project files and would only ever
  # look changed. Relies on `@preprocessinator` and `@dependinator`.
  def register_preprocessed_dependencies(target, output)
    build_root = File.join( @configurator.project_build_root, '' )
    files      = @preprocessinator.preprocessed_dependencies( preprocessed_filepath: output )

    @dependinator.register( target, files: files.reject { |file| file.start_with?( build_root ) } )
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

  # Whether a source is a Partialized module's own original.
  #
  # A Partial's own module name doubles as its generated source file's basename, so a list
  # built from #include-derived sources can carry an original that a Partial has already
  # taken over. The Partial's separately generated source is the only one of the two that
  # links. The original's object is made only for a build that asks for originals, as a
  # coverage build does, since a coverage report reads it.
  #
  # A module is matched by the end of the source's path. Matching on basename alone would
  # also take a same-named module from another directory. Only a source's path is asked,
  # never an object's, since a shortened source root keeps an object's path from mirroring
  # its source's.
  def partials_source_object?(path, configs)
    segments = PathMirror.path_segments( path.ext( '' ) )

    return configs.keys.any? do |_module|
      query = PathMirror.path_segments( _module )
      segments.last( query.length ) == query
    end
  end

end
