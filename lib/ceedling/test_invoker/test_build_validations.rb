# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/filesystem/destination_collision'

# Test-build configuration validators shared by more than one test pipeline stage
# class -- each raises CeedlingException on a real, user-facing mistake it's
# positioned to catch (a project using mocking or Partials without configuring for
# it, a header that doesn't actually resolve, or two tests sharing one name).
# Relies on whichever including class's own constructor DI already provides the
# collaborators a given validator needs, the same way TestPipelineHelpers is
# mixed in without any DI wiring of its own.
module TestBuildValidations

  # A name is its test's path without its extension, so two tests share one only when they
  # differ in extension alone (`test_a.c` and `test_a.cpp`). Sharing would silently drop one
  # test, so a build with them in it stops. A build without them is unaffected.
  def validate_unique_test_names!(tests:)
    shared = DestinationCollision.find( @configurator.collection_all_tests.map( &:to_s ) ) { |test| @file_path_utils.form_test_name( test ) }

    tests.each do |test|
      name = @file_path_utils.form_test_name( test )
      DestinationCollision.raise_for( name, shared[name], 'share the build name' ) if shared.key?( name )
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

  # Every #include of a project header must resolve through this test's search paths, as
  # the compiler resolves it. Same-named candidates resolve to the first in search order,
  # and only an unresolvable name halts the build here. Mocks are checked as they resolve
  # (FileFinder#resolve_mock). System headers, Unity's and Ceedling's own headers, and
  # Partials are Ceedling's or the toolchain's, so none is checked.
  #
  # `search` is the test's HeaderSearch when the caller already holds one.
  def validate_header_includes(test_filepath:, testable:, search: nil)
    includes = @context_extractor.lookup_nonmock_header_includes_list( test_filepath )

    collection = search || @mock_locator.header_search( testable )

    header_includes_to_check( includes ).each do |include|
      @file_finder.find_header_file( include.filepath, :error, collection: collection )
    end
  end

  private

  # The #includes naming a project header: no system header, Unity's or Ceedling's own
  # header, or a Partial
  def header_includes_to_check(includes)
    return includes.reject do |include|
      include.is_a?( SystemInclude ) or
        include.filename == UNITY_H_FILE or
        include.filename == CEEDLING_HEADER_FILENAME or
        include.filename.start_with?( PARTIAL_FILENAME_PREFIX )
    end
  end

end
