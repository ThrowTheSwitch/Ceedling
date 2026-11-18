# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/filesystem/build_subpath'
require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/project_paths'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Where a test's mocks come from and where they go. A mock's real header resolves
# through the test's search paths as the compiler resolves it, and the mock is written to
# a directory below the test's mock root mirroring that header's location. Stand-ins,
# mock search paths, and the real mock must all agree on that directory, and a stand-in and
# its mock on the #include of the real header, so every stage locates mocks here.
class MockLocator

  include TestPipelineHelpers

  # Where a mock is written (`directory`), the `folder` and `root` CMock writes it by (CMock
  # writes below its root at the folder), and the directory the #include as written reaches
  # the mock from (`reach`), which a search path must name
  MockPlacement = Struct.new( :folder, :directory, :root, :reach, keyword_init: true )

  constructor :configurator, :include_pathinator, :test_search_paths, :file_finder, :file_path_utils

  # How a test's real headers are found: through its search paths in order, without the
  # directories its mocks and Partials are generated in, which hold no real headers. A
  # header that stage 2 refused a search path explains its failed lookup.
  def header_search(testable)
    return @include_pathinator.header_search( @test_search_paths.header_paths( testable ), refusals: testable.search_path_refusals )
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

  # A mock's directory, and the directory its #include as written reaches it from
  def search_directories(placement)
    return [placement.directory, placement.reach].uniq
  end

  # Where a mock of the header mirrored at `subdir` is written, for the #include that
  # names it as `include_path`.
  #
  # CMock names a mock's guard and lifecycle functions by the folder its #include names, and
  # the runner names its calls by the same #include, so the folder reaches CMock as written.
  # A folder that ends the mirrored subdirectory keeps that directory. One spelling more
  # path than the mirror holds places the mock at the written path below the mock root. One
  # that climbs stays below the mock root too: each `..` it begins with becomes an `_up_`
  # directory, and the #include reaches the mock from that many levels deeper still.
  # Without :mock_name_include_folder no folder is passed, and CMock names by filename
  # alone, writing into the mock's directory itself.
  def placement(mocks_root:, subdir:, include_path:)
    written = written_folder( include_path )
    spot    = written.nil? ? mirrored_spot( mocks_root, subdir ) : written_spot( mocks_root, subdir.to_s, written )
    folder  = cmock_folder( include_path )

    return MockPlacement.new( folder: folder, directory: spot[:directory], root: (folder ? spot[:reach] : spot[:directory]), reach: spot[:reach] )
  end

  # The text the mock `include` names includes its real `header` by, which its stand-in
  # includes too. CMock writes the folder it is given and the header's filename. Where the
  # test's `search` reaches the header only by another text, the mock takes that one.
  def header_include(include, header, search)
    return header_respelling( include, header, search ) || cmock_header_include( include.filepath, header )
  end

  # The text `search` reaches a mock's real `header` by, when the one CMock writes reaches
  # another header or none, as through a search path listing the header's own directory.
  # Nil when CMock's reaches it, or nothing does. The compiler joins a folder that climbs as
  # written, which a search can't judge, so CMock's stays. A Partial mock's header is
  # Ceedling's own, which CMock reaches in the mock root.
  def header_respelling(include, header, search)
    return nil if mock_partial?( include )

    written = cmock_header_include( include.filepath, header )
    return nil if ProjectPaths.segments( written ).include?( '..' )

    spelled = search.spelling( header, preferring: written )
    return spelled == written ? nil : spelled
  end

  # The line CMock opens a mock with: its :orig_header_include_fmt around `text`
  def header_include_line(text)
    format = @configurator.get_cmock_config[:orig_header_include_fmt] || '#include "%s"'
    return format.gsub( '%s' ) { text }
  end

  private

  # The folder CMock is given for a mock's #include, or nil without :mock_name_include_folder
  def cmock_folder(include_path)
    return @configurator.cmock_mock_name_include_folder ? written_folder( include_path ) : nil
  end

  # The text CMock includes a mock's real header by
  def cmock_header_include(include_path, header)
    folder = cmock_folder( include_path )
    return folder.nil? ? File.basename( header ) : File.join( folder, File.basename( header ) )
  end

  # The folder of a mock's #include as written, without a leading ./, or nil for none
  def written_folder(include_path)
    folder = File.dirname( include_path.to_s ).sub( %r{\A(?:\./)+}, '' )
    return (folder.empty? || folder == '.') ? nil : folder
  end

  def mirrored_spot(mocks_root, subdir)
    directory = @file_path_utils.form_mock_output_path( mocks_root, subdir )
    return { directory: directory, reach: directory }
  end

  # The mock's directory for a #include written with `written`, and the directory that
  # folder leads down or climbs from to it
  def written_spot(mocks_root, subdir, written)
    if subdir == written or subdir.end_with?( "/#{written}" )
      return { directory: File.join( mocks_root, subdir ), reach: File.join( mocks_root, subdir.delete_suffix( written ) ).chomp( '/' ) }
    end

    segments = PathMatcher.resolve_relative( written, anchor: '' ).split( '/' )
    climbs   = segments.take_while { |segment| segment == '..' }.length
    ups      = [BuildSubpath::PARENT_SEGMENT] * climbs

    return { directory: File.join( mocks_root, *ups, *segments.drop( climbs ) ), reach: File.join( mocks_root, *ups, *ups ) }
  end

end
