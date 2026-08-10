# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for adding ext() method to string
require 'ceedling/exceptions'
require 'ceedling/path_matcher'
require 'ceedling/path_mirror'

class FileFinder

  constructor :configurator, :file_finder_helper, :file_path_utils, :file_wrapper, :yaml_wrapper


  def find_header_input_for_mock(mock)
    # Mock name => <mock prefix><header filename (.h)>
    # Examples: 'Mockfoo.h' or 'mock_Bar.h'
    # Note: In some rare cases, a mock name may include a dot (ex. Sensor.44) because of versioning file naming convention
    #       Be careful about assuming the end of the name has any sort of file extension

    header = mock.delete_prefix(@configurator.cmock_mock_prefix)

    found_path = @file_finder_helper.find_file_in_collection(
      header,
      @configurator.collection_all_headers,
      :error
    )

    return found_path
  end


  # Find test filepath from only the base name of a test file (e.g. 'test_foo')
  def find_test_file_from_name(name)
    return find_first_candidate(name, @configurator.extension_source, @configurator.collection_all_tests, :error)
  end


  def find_build_input_file(filepath:, complain: :error, context:, test: nil)
    release = (context == RELEASE_SYM)

    found_file = nil

    # Extract filename without file extension
    source_file = File.basename(filepath).ext('')

    # Recovered once and reused by every branch below that needs it, rather than each
    # independently re-deriving the same test identity from the same filepath.
    test_context = test_context_of(filepath)

    # We only collect files that already exist when we start up.
    # FileLists can produce undesired results for dynamically generated files depending on when they're accessed.
    # So collect mocks and runners separately and right now.
    # Assume that project configuration options will have already filtered out any files that should not be searched for.

    # Note: We carefully add file extensions below with string addition instead of using .ext()
    #       Some legacy files can include naming conventions like <name>.##.<ext> for versioning.
    #       If we use .ext() below we'll clobber the dotted portion of the filename

    # Generated test runners -- a flat test's own runner is searched for in the shared flat
    # runners directory; only a nested test's own mirrored subdirectory scopes the search
    # further, so two same-named tests' runners are never mistaken for each other
    if (!release) and
       (source_file =~ /^#{Regexp.escape(@configurator.project_test_file_prefix)}.+#{Regexp.escape(@configurator.test_runner_file_suffix)}$/)
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing( File.join(runner_scope_dir(test_context), '*') ),
          complain)

    # Generated mocks -- scoped to this test's own mock subtree so another test's
    # identically named mock (expected, routine repetition) is never mistaken for ambiguity
    elsif (!release) and
          (source_file.start_with?( @configurator.cmock_mock_prefix ))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing(
            File.join(@configurator.cmock_mock_path, test_context, ('**/*' + EXTENSION_CORE_SOURCE))
          ),
          complain)

    # Generated partials -- same per-test scoping rationale as mocks, above
    elsif (!release) and
          (source_file.start_with?( PARTIAL_FILENAME_PREFIX ))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing(
            File.join(@configurator.project_test_partials_path, test_context, ('**/*' + EXTENSION_CORE_SOURCE))
          ),
          complain)

    # Vendor framework sources (unity.c, cmock.c, cexception.c, etc.)
    # Note: Taking a small chance by mixing test and release frameworks without smart checks on test/release build
    elsif (@configurator.collection_vendor_framework_sources.include?(source_file.ext(EXTENSION_CORE_SOURCE)))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_existing_test_build_input,
          complain)

    # The test file's own object, resolving back to its own source -- go directly by this
    # object's own test identity rather than searching the whole project's test collection
    # by bare basename, which is exactly the kind of query that's ambiguous the moment
    # another same-named test exists elsewhere
    elsif (!release) and !test_context.empty? and (source_file == File.basename( test_context ))
      found_file = find_test_file_from_name( test_context )

    end

    if !found_file.nil?
      return found_file
    end

    #
    # Above we can confidently rely on the complain parameter passed to file_finder_helper because
    # we know the specific type of file being searched for.
    #
    # Below we ignore file misses because of lgoical complexities of searching for potentially either
    # assmebly or C files, including C files that may not exist (counterparts to header files by convention).
    # We save the existence handling until the end.
    #

    # A module-under-test or release source's object mirrors that source's own subdirectory
    # below whichever configured root it came from -- recovering that mirrored subdirectory
    # here lets the query go straight to the matching source, rather than a bare basename
    # that's ambiguous the moment another same-named source exists elsewhere.
    query_file = mirrored_query(filepath, release: release, test: test, context: context)

    # Assembly files for release build
    if release and @configurator.release_build_use_assembly
      found_file = try_extensions(query_file, @configurator.extension_assembly, @configurator.collection_release_build_input)

    # Assembly files for test build
    elsif (!release) and @configurator.test_build_use_assembly
      found_file = try_extensions(query_file, @configurator.extension_assembly, @configurator.collection_existing_test_build_input)
    end

    if !found_file.nil?
        return found_file
    end

    # Release build C files
    if release
      found_file = try_extensions(query_file, @configurator.extension_source, @configurator.collection_release_build_input)

    # Test build C files
    else
      found_file = try_extensions(query_file, @configurator.extension_source, @configurator.collection_existing_test_build_input)
    end

    if found_file.nil?
      # Every name actually attempted above, laid out for the reader in the same order they
      # were tried, so a missing-file complaint names every filename ceedling went looking for.
      tried = @configurator.extension_source.map { |ext| query_file + ext }
      tried += @configurator.extension_assembly.map { |ext| query_file + ext } if @configurator.release_build_use_assembly
      @file_finder_helper.handle_missing_file(tried.join(' or '), complain)
    end

    return found_file
  end


  def find_header_file(filepath, complain = :error)
    return find_first_candidate(filepath, @configurator.extension_header, @configurator.collection_all_headers, complain)
  end

  def find_source_file(filepath, complain = :error)
    return find_first_candidate(filepath, @configurator.extension_source, @configurator.collection_all_source, complain)
  end


  def find_assembly_file(filepath, complain = :error)
    return find_first_candidate(filepath, @configurator.extension_assembly, @configurator.collection_all_assembly, complain)
  end

  def find_file_from_list(filepath, file_list, complain)
    return @file_finder_helper.find_file_in_collection(filepath, file_list, complain)
  end

  ### Private ###

  private

  # A test object's build directory identity mirrors the configured test root a source
  # file lives under (e.g. `unit/test_foo` for `test/unit/test_foo.c`, plain `test_foo` for
  # a flat file). Recovering that identity from a build artifact's own path lets a lookup
  # go straight to the one test it belongs to, rather than searching the whole project by
  # bare basename -- exactly the query shape that's ambiguous when another same-named test
  # exists elsewhere.
  #
  # A filepath that isn't under the test build root at all (a source-tree-relative query
  # from an #include or TEST_SOURCE_FILE(), rather than a build artifact's own path) has no
  # test identity to recover -- empty string, never a directory name that could coincidentally
  # match some unrelated file's own basename.
  def test_context_of(filepath)
    dir  = File.dirname( filepath )
    root = @configurator.project_test_build_output_path
    return dir.start_with?( root + '/' ) ? dir[(root.length + 1)..] : ''
  end

  # A flat test's own runner lives in the shared flat runners directory; only a nested
  # test's own mirrored subdirectory (excluding its own basename) narrows the search
  # further -- mirroring FilePathUtils#form_test_runners_path's own directory-forming rule.
  # Takes the test identity already recovered by the caller rather than a raw filepath, so
  # it isn't independently re-deriving what the caller already has in hand.
  def runner_scope_dir(test_context)
    subdir = File.dirname( test_context )
    root   = @configurator.project_test_runners_path
    return subdir == '.' ? root : File.join(root, subdir)
  end

  # A release or module-under-test object's own path mirrors its source's subdirectory
  # below whichever configured root it came from, rooted at the release build output path
  # or (given the current test's identity) that test's own build path. Recovering that
  # mirrored subdirectory and combining it with the bare basename recreates a query that
  # identifies the same one source PathMirror originally mirrored it from.
  #
  # A filepath that isn't under the project's build root at all is already a source-tree-
  # relative query in its own right -- straight from an #include or a TEST_SOURCE_FILE()
  # directive, say -- so whatever path it already carries is preserved rather than
  # collapsed to a bare basename that would throw away real disambiguating information.
  #
  # A filepath that IS somewhere under the build root, but either belongs to a build
  # context this method doesn't specifically know how to mirror (a plugin's own object
  # output, e.g. build/valgrind/out/..., rather than release or test) or lacks enough to
  # peel back a known per-test root (test build input queried without a test identity),
  # falls back to the bare basename -- exactly what every caller has always seen for those
  # cases.
  def mirrored_query(filepath, release:, test:, context:)
    dir = File.dirname(filepath)
    build_root = @configurator.project_build_root

    return filepath.ext('') unless dir == build_root || dir.start_with?(build_root + '/')

    basename = File.basename(filepath).ext('')

    root =
      if release
        @configurator.project_release_build_output_path
      elsif test
        @file_path_utils.form_test_build_path(test, context: context)
      end

    return basename if root.nil?

    subdir = PathMirror.relative_subdir(filepath, [root])
    return subdir.empty? ? basename : File.join(subdir, basename)
  end

  # A file type may be named by any one of several configured extensions, so a basename
  # alone doesn't say which candidate filename actually exists. Every candidate but the
  # last is searched for quietly by plain exact match -- a miss there just means trying
  # the next spelling, not a real problem, and critically, must not go through
  # find_file_in_collection at all: that helper's own case-insensitive "did you mean"
  # fallback would otherwise fire on an early, expected miss (trying `.s` before `.S`, say)
  # the moment ANY differently-cased candidate happens to exist on disk, well before every
  # real candidate has had its turn. Only the true last candidate is searched under the
  # caller's own complain-on-miss behavior, so a genuine failure still reports one sensible name.
  def find_first_candidate(query, extension, collection, complain)
    candidates = extension.candidates(query)

    candidates[0...-1].each do |candidate|
      found = match_candidate(candidate, collection)
      return found unless found.nil?
    end

    return @file_finder_helper.find_file_in_collection(candidates.last, collection, complain)
  end

  # As `find_first_candidate`, but builds each candidate by plain string concatenation
  # rather than `String#ext` -- some legacy filenames carry a dotted version segment
  # (e.g. `foo.44`), and `.ext` would clobber that segment while re-adding the extension.
  # Every candidate is searched for quietly; the caller decides how to react if none exist.
  def try_extensions(basename, extension, collection)
    extension.each do |ext|
      found = match_candidate(basename + ext, collection)
      return found unless found.nil?
    end

    return nil
  end

  # A single candidate query, matched against `collection` via the shared path-aware
  # matcher, with no fuzzy fallback of any kind -- callers trying several candidate
  # spellings in turn need each individual attempt to simply say yes or no (or raise on
  # genuine ambiguity), not fall back to guessing partway through.
  def match_candidate(candidate, collection)
    return PathMatcher.match(candidate, collection)
  end

end
