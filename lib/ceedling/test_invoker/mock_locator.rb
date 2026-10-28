# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/build_subpath'
require 'ceedling/path_matcher'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Where a test's mocks come from and where they go. A mock's real header resolves
# against the test's search paths, and the mock is written to a directory below the
# test's mock root mirroring that header's location. Stand-ins, mock search paths, and
# the real mock must all agree on that directory, so every stage locates mocks here.
class MockLocator

  include TestPipelineHelpers

  # Where a mock is written (`directory`), and the `folder` and `root` CMock writes it by.
  # CMock writes below its root at the folder, so the folder as written ends the directory.
  MockPlacement = Struct.new( :folder, :directory, :root, keyword_init: true ) do
    # The folder climbs, so only its root is a search path that reaches the mock as written
    def climbs?
      return !folder.nil? && !directory.end_with?( File.join( '', folder ) )
    end
  end

  constructor :configurator, :include_pathinator, :file_finder, :file_path_utils

  # The headers a test's mocks resolve against: those on its search paths, in search
  # order, without its own mock directories, which hold mocks rather than real headers
  def header_collection(search_paths, mock_search_paths = [])
    return @include_pathinator.ordered_header_files( search_paths - mock_search_paths )
  end

  # A mock's real header and the subdirectory mirroring its location. `complain` sets
  # what a missing header does: :error raises, and :ignore gives [nil, nil].
  def locate(include, collection:, complain: :error)
    return @file_finder.resolve_mock( include.filepath, collection: collection, complain: complain )
  end

  # Each mock's mirrored directory below `mocks_root`, once each. A Partial mock has no
  # real header and lives in the root itself, and a mock whose missing header the caller
  # tolerates has no directory.
  def directories(includes, mocks_root:, collection:, complain: :error)
    dirs = includes.filter_map do |include|
      next if mock_partial?( include )

      source, subdir = locate( include, collection: collection, complain: complain )
      next if source.nil?

      search_directories( placement( mocks_root: mocks_root, subdir: subdir, include_path: include.filepath ) )
    end

    return dirs.flatten.uniq
  end

  # A mock's directory, and the root CMock climbs from when its folder climbs
  def search_directories(placement)
    return placement.climbs? ? [placement.directory, placement.root] : [placement.directory]
  end

  # Where a mock of the header mirrored at `subdir` is written, for the #include that
  # names it as `include_path`.
  #
  # CMock names a mock's guard and lifecycle functions by the folder its #include names, and
  # the runner names its calls by the same #include, so the folder reaches CMock as written.
  # A folder that ends the mirrored directory keeps that directory. One spelling more path
  # than the mirror holds places the mock at the written path below the mock root. One that
  # climbs stays below the mock root too: each `..` it begins with becomes an `_up_`
  # directory, and CMock's root sits that many levels deeper still, so the folder climbs
  # from the root back down to the mock. Without :mock_name_include_folder no folder is
  # passed, and CMock names by filename alone.
  def placement(mocks_root:, subdir:, include_path:)
    mirrored = @file_path_utils.form_mock_output_path( mocks_root, subdir )
    folder   = include_folder( include_path )

    return MockPlacement.new( folder: nil, directory: mirrored, root: mirrored ) if folder.nil?

    ending = File.join( '', folder )
    return MockPlacement.new( folder: folder, directory: mirrored, root: mirrored.delete_suffix( ending ) ) if mirrored.end_with?( ending )

    return written_placement( mocks_root, folder )
  end

  private

  # The folder of a mock's #include, without a leading ./, or nil for none
  def include_folder(include_path)
    return nil unless @configurator.cmock_mock_name_include_folder

    folder = File.dirname( include_path.to_s ).sub( %r{\A(?:\./)+}, '' )
    return (folder.empty? || folder == '.') ? nil : folder
  end

  # The mock at the folder's own path below the mock root, a climb kept below it
  def written_placement(mocks_root, folder)
    segments = PathMatcher.resolve_relative( folder, anchor: '' ).split( '/' )
    climbs   = segments.take_while { |segment| segment == '..' }.length
    ups      = [BuildSubpath::PARENT_SEGMENT] * climbs

    return MockPlacement.new(
      folder:    folder,
      directory: File.join( mocks_root, *ups, *segments.drop( climbs ) ),
      root:      File.join( mocks_root, *ups, *ups )
    )
  end

end
