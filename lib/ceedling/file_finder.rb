# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for adding ext() method to string
require 'ceedling/exceptions'

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
      :error,
      header.ext()
    )

    return found_path
  end


  # Find test filepath from another filepath (e.g. test executable with same base name, a/path/test_foo.exe)
  def find_test_file_from_filepath(filepath)
    # Strip filepath down to filename and remove file extension
    name = File.basename( filepath ).ext('')

    return find_test_file_from_name( name )
  end


  # Find test filepath from only the base name of a test file (e.g. 'test_foo')
  def find_test_file_from_name(name)
    return find_first_candidate(name, @configurator.extension_source, @configurator.collection_all_tests, :error, name)
  end


  def find_build_input_file(filepath:, complain: :error, context:)
    release = (context == RELEASE_SYM)

    found_file = nil

    # Extract filename without file extension
    source_file = File.basename(filepath).ext('')

    # We only collect files that already exist when we start up.
    # FileLists can produce undesired results for dynamically generated files depending on when they're accessed.
    # So collect mocks and runners separately and right now.
    # Assume that project configuration options will have already filtered out any files that should not be searched for.

    # Note: We carefully add file extensions below with string addition instead of using .ext()
    #       Some legacy files can include naming conventions like <name>.##.<ext> for versioning.
    #       If we use .ext() below we'll clobber the dotted portion of the filename

    # Generated test runners
    if (!release) and
       (source_file =~ /^#{Regexp.escape(@configurator.project_test_file_prefix)}.+#{Regexp.escape(@configurator.test_runner_file_suffix)}$/)
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing( File.join(@configurator.project_test_runners_path, '*') ),
          complain,
          filepath)

    # Generated mocks
    elsif (!release) and 
          (source_file.start_with?( @configurator.cmock_mock_prefix ))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing(
            File.join(@configurator.cmock_mock_path,
            ('**/*' + EXTENSION_CORE_SOURCE))
          ),
          complain,
          filepath)

    # Generated partials
    elsif (!release) and 
          (source_file.start_with?( PARTIAL_FILENAME_PREFIX ))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing(
            File.join(@configurator.project_test_partials_path,
            ('**/*' + EXTENSION_CORE_SOURCE))
          ),
          complain,
          filepath)

    # Vendor framework sources (unity.c, cmock.c, cexception.c, etc.)
    # Note: Taking a small chance by mixing test and release frameworks without smart checks on test/release build
    elsif (@configurator.collection_vendor_framework_sources.include?(source_file.ext(EXTENSION_CORE_SOURCE)))
      _source_file = source_file + EXTENSION_CORE_SOURCE
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_existing_test_build_input,
          complain,
          filepath)

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

    # Assembly files for release build
    if release and @configurator.release_build_use_assembly
      found_file = try_extensions(source_file, @configurator.extension_assembly, @configurator.collection_release_build_input)

    # Assembly files for test build
    elsif (!release) and @configurator.test_build_use_assembly
      found_file = try_extensions(source_file, @configurator.extension_assembly, @configurator.collection_existing_test_build_input)
    end

    if !found_file.nil?
        return found_file
    end

    # Release build C files
    if release
      found_file = try_extensions(source_file, @configurator.extension_source, @configurator.collection_release_build_input)

    # Test build C files
    else
      found_file = try_extensions(source_file, @configurator.extension_source, @configurator.collection_existing_test_build_input)
    end

    if found_file.nil?
      # Every name actually attempted above, laid out for the reader in the same order they
      # were tried, so a missing-file complaint names every filename ceedling went looking for.
      tried = @configurator.extension_source.map { |ext| source_file + ext }
      tried += @configurator.extension_assembly.map { |ext| source_file + ext } if @configurator.release_build_use_assembly
      @file_finder_helper.handle_missing_file(tried.join(' or '), complain)
    end

    return found_file
  end


  def find_header_file(filepath, complain = :error)
    return find_first_candidate(File.basename(filepath), @configurator.extension_header, @configurator.collection_all_headers, complain, filepath)
  end

  def find_source_file(filepath, complain = :error)
    return find_first_candidate(File.basename(filepath), @configurator.extension_source, @configurator.collection_all_source, complain, filepath)
  end


  def find_assembly_file(filepath, complain = :error)
    return find_first_candidate(File.basename(filepath), @configurator.extension_assembly, @configurator.collection_all_assembly, complain, filepath)
  end

  def find_file_from_list(filepath, file_list, complain)
    return @file_finder_helper.find_file_in_collection(filepath, file_list, complain, filepath)
  end

  ### Private ###

  private

  # A file type may be named by any one of several configured extensions, so a basename
  # alone doesn't say which candidate filename actually exists. Every candidate but the
  # last is searched for quietly by plain exact-basename matching -- a miss there just
  # means trying the next spelling, not a real problem, and critically, must not go through
  # find_file_in_collection at all: that helper's own case-insensitive "did you mean"
  # fallback would otherwise fire on an early, expected miss (trying `.s` before `.S`, say)
  # the moment ANY differently-cased candidate happens to exist on disk, well before every
  # real candidate has had its turn. Only the true last candidate is searched under the
  # caller's own complain-on-miss behavior, so a genuine failure still reports one sensible name.
  def find_first_candidate(basename, extension, collection, complain, filepath)
    candidates = extension.candidates(basename)

    candidates[0...-1].each do |candidate|
      found = exact_basename_match(candidate, collection)
      return found unless found.nil?
    end

    return @file_finder_helper.find_file_in_collection(candidates.last, collection, complain, filepath)
  end

  # As `find_first_candidate`, but builds each candidate by plain string concatenation
  # rather than `String#ext` -- some legacy filenames carry a dotted version segment
  # (e.g. `foo.44`), and `.ext` would clobber that segment while re-adding the extension.
  # Every candidate is searched for quietly; the caller decides how to react if none exist.
  def try_extensions(basename, extension, collection)
    extension.each do |ext|
      found = exact_basename_match(basename + ext, collection)
      return found unless found.nil?
    end

    return nil
  end

  # A single candidate's exact basename, matched case-sensitively against `collection`,
  # with no fuzzy fallback of any kind -- callers trying several candidate spellings in
  # turn need each individual attempt to simply say yes or no, not raise partway through.
  def exact_basename_match(candidate, collection)
    collection.find { |v| File.basename(v) == File.basename(candidate) }
  end

end

