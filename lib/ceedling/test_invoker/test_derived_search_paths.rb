# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/project_paths'
require 'ceedling/test_invoker/test_pipeline_helpers'
require 'ceedling/test_invoker/derived_search_path_notices'

# The search paths a test's #includes imply for headers whose own directories no search
# path lists.
#
# A header that only :files ↳ :include supplies usually sits in no search path's
# directory, so the compiler can't reach it through the #include as written. The directory that #include
# implies is the header's path with the #include's own path taken off its end. Joined with
# that directory, the #include names the header, so a test whose #include reaches nothing
# else gets the directory as a search path, after every configured path. Nothing
# configured is shadowed.
#
# A bare name gives the header's own directory. Outside the working directory that can be
# a system directory of forwarding headers, such as glibc's sys/, where one header includes
# another by a name the directory itself holds. No directory is added for a bare name
# there. The refusal explains the error the header's failed lookup raises.
class TestDerivedSearchPaths

  include TestPipelineHelpers

  # The option that names a mock's header by its folder
  FOLDER_OPTION = ':cmock ↳ :mock_name_include_folder'

  constructor :configurator, :include_pathinator, :test_search_paths, :test_context_extractor, :file_finder, :file_wrapper, :loginator

  def setup
    @notices = DerivedSearchPathNotices.new( loginator: @loginator )
  end

  # Starts a test build, whose NOTICEs name each directory once
  def forget_notices
    @notices.forget
  end

  # The directories `testable`'s #includes imply, in the order its #includes need them, and
  # the refusals for headers outside the working directory, by the query each #include asks
  # for. One search serves every #include until a directory joins it.
  def collect(testable)
    configured = @test_search_paths.header_paths( testable )
    search     = @include_pathinator.header_search( configured )

    return candidate_includes( testable ).each_with_object( [[], {}] ) do |include, (roots, refusals)|
      root = derived_root( testable, include, search, refusals )
      next if root.nil?

      roots << root
      search = @include_pathinator.header_search( configured + roots )
    end
  end

  private

  # The test's quoted #includes of project headers it could name by a path below a search
  # path
  def candidate_includes(testable)
    return @test_context_extractor.lookup_all_header_includes_list( testable.filepath ).reject do |include|
      include.is_a?( SystemInclude ) or generated?( include ) or placed?( include )
    end
  end

  # Unity's, Ceedling's or a Partial's header, or a Partial mock
  def generated?(include)
    return true if [UNITY_H_FILE, CEEDLING_HEADER_FILENAME].include?( include.filename )

    return (include.filename.start_with?( PARTIAL_FILENAME_PREFIX ) or mock_partial?( include ))
  end

  # A path the compiler resolves without a search path: one that climbs or is absolute
  def placed?(include)
    return true if include.directory_relative? or PathMatcher.absolute?( include.filepath )

    return ProjectPaths.segments( include.filepath ).include?( '..' )
  end

  # The directory `include` implies for its header, or nil when it needs none or is refused
  # one. A refusal joins `refusals`.
  def derived_root(testable, include, search, refusals)
    query, text = query_and_text( include )
    return nil if reaches?( testable, include, text, search )

    header = unlisted_header( query, search )
    return nil if header.nil?
    return refuse( refusals, query, refusal( testable, include, text, header ) ) if bare_outside_project?( text, header )

    root = PathMatcher.strip_tail( header, text )
    @notices.added( testable, root, text, header ) unless root.nil?
    return root
  end

  # Records why the header `query` names gets no directory, which adds none
  def refuse(refusals, query, why)
    refusals[query] = why
    return nil
  end

  # Why a bare name's header outside the working directory gets no search path, and the
  # #include that reaches it instead. Without :mock_name_include_folder a mock includes its
  # header by `text` alone, whatever folder its own #include writes.
  def refusal(testable, include, text, header)
    written   = include.filepath
    suggested = "`#include \"#{File.join( File.basename( File.dirname( header ) ), File.basename( written ) )}\"`"
    needs     = "`#include \"#{written}\"` in #{testable.filepath} needs search path '#{ProjectPaths.absolute( File.dirname( header ) )}'"
    reason    = 'Because this search path is outside the working directory and could cause shadowing of other headers, ' \
                "Ceedling won't add the full search path."

    unless include.is_a?( MockInclude ) and !@configurator.cmock_mock_name_include_folder
      return "#{needs}. #{reason} Instead, reference the parent folder, as in #{suggested}."
    end

    return "#{needs}, since its mock writes `#include \"#{text}\"` with #{FOLDER_OPTION} disabled. #{reason} " \
           "Instead, enable #{FOLDER_OPTION} and reference the parent folder, as in #{suggested}."
  end

  # The header `query` names, when no search path lists its directory and Ceedling didn't
  # generate it
  def unlisted_header(query, search)
    header = search.header_candidates( query ).first || @include_pathinator.collection_candidates( query, search.paths ).first
    return nil if header.nil? or listed?( header, search ) or below_build_root?( header )

    return header
  end

  # A bare name's header outside the working directory may sit among forwarding headers
  def bare_outside_project?(text, header)
    return (File.dirname( text ) == '.' and !ProjectPaths.contains?( ProjectPaths.working_dir, header ))
  end

  # The header a mock's #include asks for, and the text the compiled #include names. A
  # mock names its header by the folder its #include writes, or by filename alone without
  # :mock_name_include_folder.
  def query_and_text(include)
    return [include.filepath, include.filepath] unless include.is_a?( MockInclude )

    query = @file_finder.mock_header_query( include.filepath )
    text  = @configurator.cmock_mock_name_include_folder ? query : File.basename( query )
    return [query, text]
  end

  # Whether the compiled #include already finds a header: joined with a search path as the
  # compiler joins it, or for the test's own #include, through the test file's directory,
  # as a quoted #include does
  def reaches?(testable, include, text, search)
    return true if search.joins?( text )
    return false if include.is_a?( MockInclude )

    return @file_wrapper.exist?( File.join( File.dirname( testable.filepath ), text ) )
  end

  # Whether a search path lists the header's own directory, so the #include as written is
  # one the compiler rejects, and no directory is added for it
  def listed?(header, search)
    dir = File.dirname( header )
    return search.paths.any? { |path| ProjectPaths.subdir_below( path, dir ) == '' }
  end

  # Ceedling's own vendor and generated headers
  def below_build_root?(header)
    return ProjectPaths.contains?( @configurator.project_build_root, header )
  end

end
