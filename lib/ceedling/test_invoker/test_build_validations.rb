# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Test-build configuration validators shared by more than one test pipeline stage
# class -- each raises CeedlingException on a real, user-facing mistake it's
# positioned to catch (a project using mocking, Partials, or a build-directive
# source without configuring for it, or a header that doesn't actually resolve).
# Relies on whichever including class's own constructor DI already provides the
# collaborators a given validator needs, the same way TestPipelineHelpers is
# mixed in without any DI wiring of its own.
module TestBuildValidations

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

  # A TEST_SOURCE_FILE() entry must name a real, recognized file whether it
  # adds or removes -- a typo or a nonexistent path is worth failing loudly
  # on either side of the +:/-: convention, the same way a missing file has
  # always been treated for a plain, additive entry.
  def validate!(test:, filepath:)
    sources = @test_context_extractor.lookup_build_directive_sources_list( filepath )

    ext_message = @configurator.extension_source.to_s
    ext_message += " or #{@configurator.extension_assembly}" if @configurator.test_build_use_assembly

    sources.each do |raw_source|
      source = FilePathUtils.no_aggregation_decorators( raw_source )
      valid_extension =
        if @configurator.test_build_use_assembly
          @configurator.extension_assembly.match?( source ) || @configurator.extension_source.match?( source )
        else
          @configurator.extension_source.match?( source )
        end

      unless valid_extension
        raise CeedlingException.new( "File '#{source}' specified with TEST_SOURCE_FILE() in #{test} is not a #{ext_message} source file" )
      end

      if @file_finder.find_build_input_file( filepath: source, complain: :ignore, context: TEST_SYM ).nil?
        raise CeedlingException.new( "File '#{source}' specified with TEST_SOURCE_FILE() in #{test} cannot be found in the source file collection" )
      end
    end
  end

end
