# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# A test's compiler search paths, in the order the compiler searches them. Generated
# directories come first, so a test's mocks and Partials shadow the real headers they
# stand in for, then TEST_INCLUDE_PATH() entries, then the project's configured paths,
# then the directories the test's #includes imply for headers no search path lists.
class TestSearchPaths

  constructor :configurator, :include_pathinator, :test_context_extractor

  # `mock_search_paths` are the test's mocks' mirrored directories, which sit right after
  # the flat mock root. They default to the Testable's own.
  def compose(testable, mock_search_paths = testable.mock_search_paths)
    filepath = testable.filepath
    return (generated_paths( filepath, testable.paths, mock_search_paths ) + configured_paths( filepath ) + testable.derived_search_paths).uniq
  end

  # The paths a test's real headers are found through: its search paths without the
  # directories its mocks and Partials are generated in
  def header_paths(testable)
    return (configured_paths( testable.filepath ) + testable.derived_search_paths).uniq
  end

  # The paths mock preprocessing reads a mocked header through: the header paths with the test's
  # Partial directories ahead of them, as `compose` orders them. Partials are generated before mocks
  # are preprocessed, so they are current then. The mock directories hold CMock's copies of headers,
  # which mock generation brings up to date only afterward, so they are left out.
  def mock_preprocess_paths(testable)
    return (partial_paths( testable.filepath, testable.paths ) + header_paths( testable )).uniq
  end

  # Sets a test's mock search paths and composes its search paths around them. `lock`
  # guards the write, since other threads read the Testable.
  def assign_mock_search_paths(testable, mock_search_paths, lock)
    paths = compose( testable, mock_search_paths )
    lock.synchronize do
      testable.mock_search_paths = mock_search_paths
      testable.search_paths      = paths
    end
  end

  private

  # Where this test's mocks and Partials are generated
  def generated_paths(filepath, paths, mock_search_paths)
    _paths = []
    _paths << paths[:mocks] if paths[:mocks]
    _paths += mock_search_paths
    return _paths + partial_paths( filepath, paths )
  end

  # The Partials root, then each Partialized module's own directory below it
  def partial_paths(filepath, paths)
    return [] unless paths[:partials]

    return [paths[:partials]] + partial_search_paths( filepath, paths )
  end

  # TEST_INCLUDE_PATH() entries, then the project's configured paths
  def configured_paths(filepath)
    return @include_pathinator.lookup_test_directive_include_paths( filepath ) +
           @include_pathinator.collect_test_include_paths() +
           @configurator.collection_paths_support +
           @configurator.collection_paths_include +
           @configurator.collection_paths_libraries +
           @configurator.collection_paths_vendor +
           @configurator.collection_paths_test_toolchain_include
  end

  # Every Partialized module's own directory below this test's Partials root.
  #
  # A generated Partial is only findable by the compiler via a search path pointing
  # directly at where it sits, since C's own #include resolution has no notion of a
  # recursive search path. Each mock's mirrored directory is on the search path for the
  # same reason, and this also covers the generated test runner, which includes a
  # Partial header by basename alone.
  #
  # The module keys carry the directory, so nothing has to exist on disk yet.
  def partial_search_paths(filepath, paths)
    return [] unless paths[:partials]

    dirs = @test_context_extractor.lookup_partials_config( filepath ).keys.map do |_module|
      dir = File.dirname( _module )
      dir == '.' ? nil : File.join( paths[:partials], dir )
    end

    return dirs.compact.uniq
  end

end
