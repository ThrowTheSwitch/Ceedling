# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Test-build configuration validators shared by more than one test pipeline stage
# class -- each raises CeedlingException on a real, user-facing mistake it's
# positioned to catch (a project using mocking or Partials without configuring for
# it, a header that doesn't actually resolve, or two tests sharing one name).
# Relies on whichever including class's own constructor DI already provides the
# collaborators a given validator needs, the same way TestPipelineHelpers is
# mixed in without any DI wiring of its own.
module TestBuildValidations

  # A name comes from its test's path, so two tests share one only when a path outside the
  # project maps onto a real one (`../x` and a project directory named `_up_/x`). Sharing
  # would silently drop one test, so a build with either in it stops. A build without them
  # is unaffected.
  def validate_unique_test_names!(tests:)
    by_name = @configurator.collection_all_tests.map( &:to_s ).uniq.group_by { |test| @file_path_utils.form_test_name( test ) }

    tests.each do |test|
      name  = @file_path_utils.form_test_name( test )
      files = by_name.fetch( name, [] )
      next if files.size < 2

      raise CeedlingException.new( "Test files #{files.join( ' and ' )} map to one build name `#{name}`. Rename or move one of them." )
    end
  end

  def validate_mocks_in_use(filename:, mocks:)
    if !@configurator.project_use_mocks and !mocks.empty?
      _mocks = mocks.map { |include| include.filename }

      if _mocks.length > 1
        _mocks = "[#{_mocks.join(', ')}]"
      else
        _mocks = _mocks[0]
      end

      msg = "Your project is not configured for mocking, but #{filename} #includes #{_mocks}"
      raise CeedlingException.new( msg )
    end
  end

  def validate_partials_in_use(filename:, partials_in_use:, includes:)
    partials_header_in_use = Includes.contains?( includes, CEEDLING_HEADER_FILENAME )

    if partials_in_use && !@configurator.project_use_partials
      msg = "Your project is not configured for Partials, but #{filename} is attempting to use Partial features"
      raise CeedlingException.new( msg )
    end

    if partials_in_use && !partials_header_in_use
      msg = "Your test file #{filename} is attempting to use Partial features without #including #{CEEDLING_HEADER_FILENAME}"
      raise CeedlingException.new( msg )
    end
  end

  # Every #include naming a real project header -- other than a mock (validated separately,
  # as part of resolving it via FileFinder#resolve_mock), a system header, Unity's or
  # Ceedling's own header, or a Partial (Ceedling's own generated content, not a project file
  # to validate) -- must resolve to exactly one file, existence-wise, among this test's own
  # search_paths (the same directory priority the compiler itself consults): ambiguity among
  # same-named candidates resolves quietly to the first by that order, exactly as the real
  # compile would find it; only a genuinely unresolvable name still halts the build here. A
  # bogus or merely-unmatched path is otherwise never actually checked against real project
  # headers -- only its potential corresponding source file is, tolerantly, elsewhere. Unity's
  # and Ceedling's own headers live in the build's vendor directories, outside every configured
  # :test/:source/:support/:include root a test's search_paths is built from, so neither could
  # ever resolve there.
  def validate_header_includes(test_filepath:, testable:)
    includes = @context_extractor.lookup_nonmock_header_includes_list( test_filepath )

    collection = @include_pathinator.ordered_header_files( testable.search_paths )

    includes.each do |include|
      next if include.is_a?( SystemInclude )
      next if include.filename == UNITY_H_FILE
      next if include.filename == CEEDLING_HEADER_FILENAME
      next if include.filename.start_with?( PARTIAL_FILENAME_PREFIX )

      @file_finder.find_header_file( include.filepath, :error, collection: collection )
    end
  end

end
