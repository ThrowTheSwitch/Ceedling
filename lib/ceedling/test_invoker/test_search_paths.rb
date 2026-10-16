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
    _paths = []
    _paths << paths[:mocks]    if paths[:mocks]
    _paths += mock_search_paths
    _paths << paths[:partials] if paths[:partials]
    _paths += partial_search_paths( filepath, paths )
    _paths += @include_pathinator.lookup_test_directive_include_paths( filepath )
    _paths += @include_pathinator.collect_test_include_paths()
    _paths += @configurator.collection_paths_support
    _paths += @configurator.collection_paths_include
    _paths += @configurator.collection_paths_libraries
    _paths += @configurator.collection_paths_vendor
    _paths += @configurator.collection_paths_test_toolchain_include
    return _paths.uniq
  end

  private

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
