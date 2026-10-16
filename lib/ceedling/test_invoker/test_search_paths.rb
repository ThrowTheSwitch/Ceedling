# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# A test's compiler search paths, in the order the compiler searches them. Generated
# directories come first, so a test's mocks and Partials shadow the real headers they
# stand in for, then TEST_INCLUDE_PATH() entries, then the project's configured paths.
class TestSearchPaths

  constructor :configurator, :include_pathinator, :test_context_extractor

  # `paths` is a Testable's paths Hash. `mock_search_paths` are its mocks' mirrored
  # directories, which sit right after the flat mock root.
  def compose(filepath, paths, mock_search_paths = [])
    return (generated_paths( filepath, paths, mock_search_paths ) + configured_paths( filepath )).uniq
  end

  # Sets a test's mock search paths and composes its search paths around them. `lock`
  # guards the write, since other threads read the Testable.
  def assign_mock_search_paths(testable, mock_search_paths, lock)
    paths = compose( testable.filepath, testable.paths, mock_search_paths )
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
    _paths << paths[:partials] if paths[:partials]
    return _paths + partial_search_paths( filepath, paths )
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
