# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'
require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/filesystem/path_matcher'
require 'ceedling/filesystem/project_paths'
require 'ceedling/test_invoker/test_pipeline_helpers'

# The search paths a test's #includes imply for headers no search path lists.
#
# A header that only :files ↳ :include supplies sits in no search path's directory, so the
# compiler can't reach it through the #include as written. The directory that #include
# implies is the header's path with the #include's own path taken off its end. Joined with
# that directory, the #include names the header, so a test whose #include reaches nothing
# else gets the directory as a search path, after every configured path. Nothing
# configured is shadowed.
#
# A bare name gives the header's own directory. Outside the project that can be a system
# directory of forwarding headers, such as glibc's sys/, where one header includes another
# by a name the directory itself holds. No directory is added for a bare name there.
class TestDerivedSearchPaths

  include TestPipelineHelpers

  constructor :configurator, :include_pathinator, :test_search_paths, :test_context_extractor, :file_finder, :file_wrapper, :loginator

  def setup
    @refused      = Set.new
    @refused_lock = Mutex.new
  end

  # The directories `testable`'s #includes imply, in the order its #includes need them. One
  # search serves every #include until a directory joins it.
  def collect(testable)
    roots      = []
    configured = @test_search_paths.header_paths( testable )
    search     = @include_pathinator.header_search( configured )

    candidate_includes( testable ).each do |include|
      root = derived_root( testable, include, search )
      next if root.nil?

      roots << root
      search = @include_pathinator.header_search( configured + roots )
    end

    return roots
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

  # The directory `include` implies for its header, or nil when it needs none
  def derived_root(testable, include, search)
    query, text = query_and_text( include )
    return nil if reaches?( testable, include, text, search )

    header = unlisted_header( query, search )
    return nil if header.nil?
    return refuse( testable, include, header ) if bare_outside_project?( text, header )

    root = PathMatcher.strip_tail( header, text )
    log_root( testable, root, text, header ) unless root.nil?
    return root
  end

  # The header `query` names, when no search path lists its directory and Ceedling didn't
  # generate it
  def unlisted_header(query, search)
    header = search.header_candidates( query ).first || @include_pathinator.collection_candidates( query, search.paths ).first
    return nil if header.nil? or listed?( header, search ) or below_build_root?( header )

    return header
  end

  # A bare name's header outside the project may sit among forwarding headers
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

  # Whether the compiled #include already finds a header: through the search paths, or for
  # the test's own #include, through the test file's directory, as a quoted #include does
  def reaches?(testable, include, text, search)
    return true unless search.header_candidates( text ).empty?
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

  def log_root(testable, root, text, header)
    msg = "Added search path '#{root}' for #{testable.filepath} after every configured search path, so \"#{text}\" reaches #{header}."
    @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
  end

  # Logs once a header, however many tests name it, and gives no directory
  def refuse(testable, include, header)
    first = @refused_lock.synchronize { @refused.add?( header ) }
    return nil if first.nil?

    written   = include.filepath
    suggested = File.join( File.basename( File.dirname( header ) ), written )
    msg = "#include \"#{written}\" in #{testable.filepath} names #{header}, outside the project. " \
          "Ceedling adds no search path for a bare name there. " \
          "Include it by its path below an include directory, as in \"#{suggested}\"."
    @loginator.log( msg, Verbosity::COMPLAIN, LogLabels::NOTICE )
    return nil
  end

end
