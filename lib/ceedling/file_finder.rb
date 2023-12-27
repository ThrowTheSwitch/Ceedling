require 'rubygems'
require 'rake' # for adding ext() method to string
require 'ceedling/exceptions'

class FileFinder

  constructor :configurator, :file_finder_helper, :cacheinator, :file_path_utils, :file_wrapper, :yaml_wrapper


  def find_header_file(mock_file)
    header = File.basename(mock_file).sub(/#{@configurator.cmock_mock_prefix}/, '').ext(@configurator.extension_header)

    found_path = @file_finder_helper.find_file_in_collection(header, @configurator.collection_all_headers, :error, mock_file)

    return found_path
  end


  def find_header_input_for_mock_file(mock_file)
    return find_header_file(mock_file)
  end


  def find_source_from_test(test, complain)
    test_prefix  = @configurator.project_test_file_prefix
    source_paths = @configurator.collection_all_source

    source = File.basename(test).sub(/#{test_prefix}/, '')

    # we don't blow up if a test file has no corresponding source file
    return @file_finder_helper.find_file_in_collection(source, source_paths, complain, test)
  end


  def find_test_from_runner_path(runner_path)
    extension_source = @configurator.extension_source

    test_file = File.basename(runner_path).sub(/#{@configurator.test_runner_file_suffix}#{'\\'+extension_source}/, extension_source)

    found_path = @file_finder_helper.find_file_in_collection(test_file, @configurator.collection_all_tests, :error, runner_path)

    return found_path
  end


  def find_test_input_for_runner_file(runner_path)
    found_path   = find_test_from_runner_path(runner_path)
    runner_input = found_path

    if (@configurator.project_use_test_preprocessor)
      runner_input = @cacheinator.diff_cached_test_file( @file_path_utils.form_preprocessed_file_filepath( found_path ) )
    end

    return runner_input
  end


  def find_test_from_file_path(filepath)
    test_file = File.basename(filepath).ext(@configurator.extension_source)

    found_path = @file_finder_helper.find_file_in_collection(test_file, @configurator.collection_all_tests, :error, filepath)

    return found_path
  end


  def find_build_input_file(filepath:, complain: :error, context:)
    release = (context == RELEASE_SYM)

    found_file = nil

    source_file = File.basename(filepath).ext('')

    # We only collect files that already exist when we start up.
    # FileLists can produce undesired results for dynamically generated files depending on when they're accessed.
    # So collect mocks and runners separately and right now.
    # Assume that project configuration options will have already filtered out any files that should not be searched for.

    # Generated test runners
    if (!release) and (source_file =~ /^#{@configurator.project_test_file_prefix}.+#{@configurator.test_runner_file_suffix}$/)
      _source_file = source_file.ext(EXTENSION_CORE_SOURCE)
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing( File.join(@configurator.project_test_runners_path, '*') ),
          complain,
          filepath)

    # Generated mocks
    elsif (!release) and (source_file =~ /^#{@configurator.cmock_mock_prefix}/)
      _source_file = source_file.ext(EXTENSION_CORE_SOURCE)
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @file_wrapper.directory_listing( File.join(@configurator.cmock_mock_path, '**/*') ),
          complain,
          filepath)

    # Vendor framework sources (unity.c, cmock.c, cexception.c, etc.)
    # Note: Taking a small chance by mixing test and release frameworks without smart checks on test/release build
    elsif (@configurator.collection_vendor_framework_sources.include?(source_file.ext(EXTENSION_CORE_SOURCE)))
      _source_file = source_file.ext(EXTENSION_CORE_SOURCE)
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
      _source_file = File.basename(filepath).ext(@configurator.extension_assembly)
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_release_build_input,
          :ignore,
          filepath)

    # Assembly files for test build 
    elsif (!release) and @configurator.test_build_use_assembly
      _source_file = File.basename(filepath).ext(@configurator.extension_assembly)
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_existing_test_build_input,
          :ignore,
          filepath)
    end

    if !found_file.nil?
        return found_file
    end

    # Release build C files
    if release
      _source_file = File.basename(filepath).ext(@configurator.extension_source)
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_release_build_input,
          :ignore,
          filepath)
        
    # Test build C files
    else
      _source_file = File.basename(filepath).ext(@configurator.extension_source)
      found_file =
        @file_finder_helper.find_file_in_collection(
          _source_file,
          @configurator.collection_existing_test_build_input,
          :ignore,
          filepath)
    end

    if found_file.nil?
      _source_file += " or #{_source_file.ext(@configurator.extension_assembly)}" if @configurator.release_build_use_assembly
      @file_finder_helper.handle_missing_file(_source_file, complain)
    end

    return found_file
  end


  def find_source_file(filepath, complain = :error)
    source_file = File.basename(filepath).ext(@configurator.extension_source)
    return @file_finder_helper.find_file_in_collection(source_file, @configurator.collection_all_source, complain, filepath)
  end


  def find_assembly_file(filepath, complain = :error)
    assembly_file = File.basename(filepath).ext(@configurator.extension_assembly)
    return @file_finder_helper.find_file_in_collection(assembly_file, @configurator.collection_all_assembly, complain, filepath)
  end

  def find_file_from_list(filepath, file_list, complain)
    return @file_finder_helper.find_file_in_collection(filepath, file_list, complain, filepath)
  end
end

