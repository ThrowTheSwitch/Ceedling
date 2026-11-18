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
# mock search paths, and the real mock must all agree on that directory, so every stage
# locates mocks here. A stand-in includes the real header as its mock does, except where the
# mock includes CMock's copy of it.
class MockLocator

  include TestPipelineHelpers

  # Where a mock is written (`directory`), the `folder` and `root` CMock writes it by (CMock
  # writes below its root at the folder), and the directory the #include as written reaches
  # the mock from (`reach`), which a search path must name
  MockPlacement = Struct.new( :folder, :directory, :root, :reach, keyword_init: true )

  # An :orig_header_include_fmt whose text is the whole operand, between quotes or brackets
  OPERAND_FORMAT = /\A\s*#\s*include\s*(?:"%s"|<%s>)\s*\z/

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

  # The #includes with one mock per real header. A test can name one header's mock two ways,
  # as `mock_task.h` and `drivers/mock_task.h` do for src/drivers/task.h under src/**. CMock
  # and the runner would make two mocks of it, which can't both link. The #include with the
  # most path stays, the first among equals, since a pathless one reaches that mock too. A
  # spelling that reaches no generated mock compiles through its stage 4 stand-in.
  # A climbing #include is looked up anchored to `from` and kept as written. Every other
  # #include, a Partial mock, and a mock whose header isn't found pass through. Two mocks of
  # one header share a filename, so only a repeated filename is looked up.
  def one_per_header(includes, collection:, from: nil)
    lookups = includes.map { |include| from ? include.anchored( from ) : include }
    headers = repeated_mock_headers( lookups, collection )
    kept    = header_keepers( lookups, headers )

    return includes.select.with_index { |_, index| headers[index].nil? or kept[headers[index]] == index }
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

  # The text the stand-in for the mock `include` names includes its real `header` by, inside
  # :orig_header_include_fmt. It's CMock's, the folder CMock is given and the header's
  # filename, unless the format takes a respelling (`header_respelling`). The mock includes the
  # same text, except under :treat_inlines :include, where CMock's reaches its copy of the
  # header. The copy doesn't exist yet when the stand-in is written.
  def header_include(include, header, search)
    respelled = header_respelling( include, header, search )
    return (respelled and respellable_format?) ? respelled : cmock_header_include( include.filepath, header )
  end

  # A respelling of the #include a mock opens with: the spelling `search` reaches its real
  # `header` by (see HeaderSearch on spellings), in place of CMock's, when CMock's reaches no
  # header, as through a search path listing the header's own directory. Nil when CMock's
  # reaches a header, or nothing reaches this one. It's the whole operand of the #include. An
  # FFF fake writes it as it is, and CMock and a stand-in only into a format that takes it.
  #
  # CMock's stays wherever the respelling can't be judged:
  # - CMock's reaches a same-named header. The compiler includes that one, whichever header
  #   the mock was located by.
  # - Its folder climbs. The compiler joins `..` as written, which a search can't follow.
  # - It's a Partial mock, whose header is Ceedling's own, in the mock root.
  def header_respelling(include, header, search)
    return nil if mock_partial?( include )

    written = cmock_header_include( include.filepath, header )
    return nil if ProjectPaths.segments( written ).include?( '..' ) or search.joins?( written )

    return search.spelling( header )
  end

  # Whether :orig_header_include_fmt takes a respelling: its text is the whole operand, between
  # quotes or angle brackets. A respelling is never weighed with more around it.
  def respellable_format?
    return header_include_format.match?( OPERAND_FORMAT )
  end

  # The line CMock opens a mock with: its :orig_header_include_fmt around `text`
  def header_include_line(text)
    return header_include_format.gsub( '%s' ) { text }
  end

  private

  # Each lookup's real header where its filename repeats, or nil
  def repeated_mock_headers(lookups, collection)
    repeated = lookups.map( &:filename ).tally
    return lookups.map { |lookup| repeated[lookup.filename] > 1 ? real_header( lookup, collection ) : nil }
  end

  # The index kept for each header: the most path, the first among equals
  def header_keepers(lookups, headers)
    length = ->(index) { ProjectPaths.segments( lookups[index].filepath ).length }
    kept   = {}
    headers.each_with_index do |header, index|
      next if header.nil? or (kept[header] and length.( index ) <= length.( kept[header] ))

      kept[header] = index
    end

    return kept
  end

  # A mock's real header, by its absolute path, or nil for anything but a found mock's
  def real_header(include, collection)
    return nil if include.is_a?( SystemInclude ) or !include.filename.start_with?( @configurator.cmock_mock_prefix )
    return nil if mock_partial?( include )

    source, _ = locate( include, collection: collection, complain: :silent )
    return source && ProjectPaths.absolute( source )
  end

  def header_include_format
    return @configurator.get_cmock_config[:orig_header_include_fmt] || '#include "%s"'
  end

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
