require 'rubygems'
require 'rake' # for adding ext() method to string

class FileFinder

  constructor :configurator, :file_finder_helper

  def find_mockable_header(mock_file)
    # since we already have full test list in memory, this is faster than searching on-disk
    header = File.basename(mock_file).sub(/#{@configurator.cmock_mock_prefix}/, '').ext(@configurator.extension_header)

    found_path = @file_finder_helper.find_file_in_collection(header, @configurator.collection_all_headers)

    return found_path
  end


  def find_mockable_headers(mock_files)
    headers = []
    
    mock_files.each do |mock_file|
      headers << find_mockable_header(mock_file)
    end
    
    return headers
  end


  def find_sources_from_tests(tests)
    # since we already have full test list in memory, this is faster than searching on-disk
    source_files = []
    
    test_prefix  = @configurator.project_test_file_prefix
    source_paths = @configurator.collection_all_source
    
    tests.each do |test|
      source = File.basename(test).sub(/#{test_prefix}/, '')

      # we don't blow up if a test file has no corresponding source file
      found_path = @file_finder_helper.find_file_in_collection(source, source_paths, {:should_complain => false})
      source_files << found_path if (not found_path.empty?)
    end

    return source_files    
  end


  def find_test_from_runner_path(runner_path)
    # since we already have full test list in memory, this is faster than searching on-disk
    extension_source = @configurator.extension_source

    test_file = File.basename(runner_path).sub(/#{@configurator.test_runner_file_suffix}#{'\\'+extension_source}/, extension_source)
    
    found_path = @file_finder_helper.find_file_in_collection(test_file, @configurator.collection_all_tests)
    
    return found_path
  end
  
  
  def find_test_from_file_path(file_path)
    # since we already have full test list in memory, this is faster than searching on-disk
    test_file = File.basename(file_path).ext(@configurator.extension_source)
    
    found_path = @file_finder_helper.find_file_in_collection(test_file, @configurator.collection_all_tests)
    
    return found_path    
  end


  def find_any_file(file_path)
    # we seach on disk because though we have most files in memory, we don't have all -
    # such as source files in test paths that don't begin with test file prefix and all generated files
    file = File.basename(file_path)
    return @file_finder_helper.find_file_on_disk(file, @configurator.collection_paths_test_and_source_include)
  end
  
  
  def find_test_or_source_file(file_path)
    # we seach on disk because though we have all source and test files in memory, we don't have 
    # in memory any files supporting testing that don't begin with the test file prefix
    source_file = File.basename(file_path).ext(@configurator.extension_source)
    return @file_finder_helper.find_file_on_disk(source_file, @configurator.collection_paths_test_and_source)
  end


  # given a set of simple headers extracted from a source file, find all corresponding source filepaths
  def find_source_files_from_headers(headers)
    # we search on disk because some files we need to find are generated and not easily collected
    source_files = []
    
    source_extension = @configurator.extension_source
    source_paths     = @configurator.collection_paths_test_and_source
    
    headers.each do |header|
      # we don't blow up if a header file has no corresponding source file
      source = @file_finder_helper.find_file_on_disk(header.ext(source_extension), source_paths, {:should_complain => false})
      source_files << source if (not source.empty?)
    end
    
    return source_files
  end
    
end

