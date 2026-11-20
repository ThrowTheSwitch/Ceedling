# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'pathname'
require 'ceedling/exceptions'
require 'ceedling/reportinator'
require 'ceedling/filesystem/file_path_utils'
require 'ceedling/filesystem/project_paths'
require 'ceedling/includes/header_search'
require 'ceedling/filesystem/path_matcher'

class IncludePathinator

  NO_HEADERS_MESSAGE = Reportinator.generate_guidance(
    lead:    'No header files found in project.',
    options: ['Add search paths to :paths ↳ :include in your project file and/or use TEST_INCLUDE_PATH() in your test files.',
              'Verify header files with `ceedling paths:include` and/or `ceedling files:include`.']
  ).freeze

  # What `header_listing` remembers for a directory under the build root
  LISTED_FRESH = :listed_fresh

  constructor :configurator, :test_context_extractor, :loginator, :file_wrapper

  def setup
    # TODO: When Ceedling's base project path handling is resolved, update this value to automatically 
    #       modify TEST_INCLUDE_PATH() locations relative to the working directory or project file location
    # @base_path = '.'

    # Alias for brevity
    @extractor = @test_context_extractor

    # Each search path's header listing for one test build (see `header_listing`), and the
    # test directories holding headers
    @listings           = {}
    @test_include_paths = nil
    @configured_headers = nil
    @listings_lock      = Mutex.new
  end

  def validate_test_build_directive_paths
    @extractor.inspect_include_paths do |test_filepath, include_paths|
      include_paths.each do |path|

        # TODO: When Ceedling's base project path handling is resolved, enable this path redefinition
        # path = File.join( @base_path, path )
        unless @file_wrapper.exist?(path)
          error = "'#{path}' specified by TEST_INCLUDE_PATH() within #{test_filepath} not found"
          raise CeedlingException.new( error )
        end
      end
    end
  end


  def validate_header_files_collection
    # Get existing, possibly minimal header file collection
    headers = @configurator.collection_all_headers

    # Get all paths specified by TEST_INCLUDE_PATH() directive in test files
    directive_paths = @extractor.lookup_all_include_paths

    # Add to collection of headers (Rake FileList) with directive paths and shallow wildcard
    # matching on header file extension -- a project may configure more than one header
    # extension, so each directive path contributes one glob pattern per configured extension
    headers += @file_wrapper.instantiate_file_list( directive_paths.flat_map { |path| EXTENSION_HEADER.glob_patterns(path) } )
    headers.resolve()

    headers.uniq!

    @loginator.log( NO_HEADERS_MESSAGE, Verbosity::COMPLAIN ) if headers.empty?

    return headers
  end

  # A test's headers found as its compiler finds them, through `search_paths` in order,
  # each directory listed as `header_listing` lists it. Distinct from collection_all_headers,
  # which is one project-wide list blind to any one test's TEST_INCLUDE_PATH() priority.
  # `refusals` explain a failed lookup (see HeaderSearch#refusal).
  def header_search(search_paths, refusals: {})
    return HeaderSearch.new( search_paths, method( :header_listing ), refusals: refusals, build_root: @configurator.project_build_root )
  end

  # Starts a test build with every search path listed afresh
  def forget_header_listings
    @listings_lock.synchronize do
      @listings.clear
      @test_include_paths = nil
    end
  end

  # The project's whole header collection, reordered so headers beneath this test's
  # own earlier search paths come first.
  #
  # Distinct from header_search above, which finds a header as the compiler's -I search
  # does. A Partial module named by path needs the whole collection instead, since its
  # trailing path matches a file at any depth below a search path, and it needs this
  # test's own priority so a TEST_INCLUDE_PATH() decides among same-named candidates.
  #
  # Ordering within one priority rank is the collection's own, so a reference that
  # distinguishes nothing resolves by collection order.
  def prioritized_header_files(search_paths)
    return prioritize( @configurator.collection_all_headers.to_a, search_paths )
  end

  # The configured collection's headers `query` could name, those beneath earlier search
  # paths first. Matches filter the collection before ranking, so a lookup costs one pass.
  # Stage 2 adds every test's TEST_INCLUDE_PATH() headers to the collection, which a later
  # build in the process would see, so lookups draw on the collection as configured.
  def collection_candidates(query, search_paths)
    headers = @listings_lock.synchronize { @configured_headers } || @configurator.collection_all_headers.to_a
    return prioritize( PathMatcher.candidates( query, headers ), search_paths )
  end

  # `headers` reordered so those beneath earlier search paths come first, keeping their
  # own order within one rank
  def prioritize(headers, search_paths)
    roots = search_paths.map { |path| FilePathUtils.no_decorators( path ) }.reject(&:empty?)
    ranks = root_ranks( roots )

    return headers.each_with_index.sort_by do |header, index|
      [header_rank( header, ranks, roots.length ), index]
    end.map(&:first)
  end

  # Remembers the configured collection the first time, since the collection then holds
  # every test's TEST_INCLUDE_PATH() headers for each later build in the process
  def augment_environment_header_files(headers)
    @listings_lock.synchronize { @configured_headers ||= @configurator.collection_all_headers.to_a.freeze }
    @configurator.redefine_element(:collection_all_headers, headers)
  end

  def lookup_test_directive_include_paths(filepath)
    # TODO: When Ceedling's base project path handling is resolved, enable this path redefinition
    # return @extractor.lookup_include_paths_list(filepath).map { |path| File.join( @base_path, path) }
    return @extractor.lookup_include_paths_list(filepath)
  end

  # Gather together [:paths][:test] that actually contain header files. Remembered for the
  # test build, since every composition of a test's search paths asks.
  def collect_test_include_paths
    remembered = @listings_lock.synchronize { @test_include_paths }
    return remembered unless remembered.nil?

    paths = @configurator.collection_paths_test.select do |path|
      !@file_wrapper.directory_listing( @configurator.extension_header.glob_patterns(path) ).empty?
    end

    return @listings_lock.synchronize { @test_include_paths ||= paths.freeze }
  end

  private

  # One search path's headers. A directory outside the build root keeps its listing for the
  # test build, since a build never writes there, and a test's search paths are listed
  # several times a test. One under the build root is listed every time, since a plugin or
  # the build itself can write headers there as it runs.
  def header_listing(path)
    key        = [ProjectPaths.working_dir, path]
    remembered = @listings_lock.synchronize { @listings[key] }
    return remembered if remembered.is_a?( Array )

    listing = @file_wrapper.directory_listing( @configurator.extension_header.glob_patterns( path ) ).freeze
    return listing if remembered == LISTED_FRESH

    kept = ProjectPaths.contains?( @configurator.project_build_root, path ) ? LISTED_FRESH : listing
    @listings_lock.synchronize { @listings[key] ||= kept }
    return listing
  end

  # Each root's place in the search order by its absolute path, the first one kept, so a
  # header's rank comes from walking up its own directories rather than trying every root
  def root_ranks(roots)
    return roots.each_with_index.with_object( {} ) { |(root, index), ranks| ranks[rank_key( ProjectPaths.absolute( root ) )] ||= index }
  end

  # The earliest-searched root a header lies below, or `none` for no root
  def header_rank(header, ranks, none)
    rank = none
    path = ProjectPaths.absolute( header )
    loop do
      parent = File.dirname( path )
      break if parent == path

      path = parent
      rank = [rank, ranks.fetch( rank_key( path ), none )].min
    end

    return rank
  end

  # Windows compares paths without regard to case
  def rank_key(path)
    return ProjectPaths::WINDOWS ? path.downcase : path
  end

end
