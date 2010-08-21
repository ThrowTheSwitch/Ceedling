require 'rubygems'
require 'rake' # for adding ext() method to string

class FileFinder

  constructor :configurator, :file_finder_helper, :file_path_utils, :file_wrapper, :yaml_wrapper

  def prepare_search_sources
    @all_test_source_and_header_file_collection = 
      @configurator.collection_all_tests +
      @configurator.collection_all_source + 
      @configurator.collection_all_headers
  end


  def find_mockable_header(mock_file)
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


  def find_source_from_test(test)
    test_prefix  = @configurator.project_test_file_prefix
    source_paths = @configurator.collection_all_source
    
    source = File.basename(test).sub(/#{test_prefix}/, '')

    # we don't blow up if a test file has no corresponding source file
    return @file_finder_helper.find_file_in_collection(source, source_paths, {:should_complain => false})
  end


  def find_test_from_runner_path(runner_path)
    extension_source = @configurator.extension_source

    test_file = File.basename(runner_path).sub(/#{@configurator.test_runner_file_suffix}#{'\\'+extension_source}/, extension_source)
    
    found_path = @file_finder_helper.find_file_in_collection(test_file, @configurator.collection_all_tests)
    
    return found_path
  end
  

  def find_test_from_file_path(file_path)
    test_file = File.basename(file_path).ext(@configurator.extension_source)
    
    found_path = @file_finder_helper.find_file_in_collection(test_file, @configurator.collection_all_tests)
    
    return found_path    
  end


  def find_test_or_source_or_header_file(file_path)
    file = File.basename(file_path)
    return @file_finder_helper.find_file_in_collection(file, @all_test_source_and_header_file_collection)
  end
  
  
  def find_compilation_input_file(file_path)
    found_file = ''
    
    source_file = File.basename(file_path).ext(@configurator.extension_source)

    # we only collect files that already exist when we startup.
    # FileLists can produce undesired results for dynamically generated files depending on when they're accessed.
    # so collect mocks and runners separately and right now.
    if (source_file =~ /#{@configurator.test_runner_file_suffix}/)
      found_file = 
        @file_finder_helper.find_file_in_collection(
          source_file,
          @file_wrapper.directory_listing( File.join(@configurator.project_test_runners_path, '*') ))
          
    elsif (@configurator.project_use_mocks and (source_file =~ /#{@configurator.cmock_mock_prefix}/))
      found_file = 
        @file_finder_helper.find_file_in_collection(
          source_file,
          @file_wrapper.directory_listing( File.join(@configurator.cmock_mock_path, '*') ))

    else
      found_file = 
        @file_finder_helper.find_file_in_collection(
          source_file,
          @configurator.collection_all_existing_compilation_input)
    end

    @file_finder.blow_up(source_file) if (found_file.nil?)
    return found_file
  end


  # given a set of simple headers extracted from a source file, find all corresponding source filepaths
  def find_source_files_from_headers(headers)
    source_files = []
    
    # we only collect files that already exist when we startup.
    # rake's FileLists can produce undesired results for dynamically generated files depending on when they're accessed.
    # so collect mocks separately and right now.
    source_extension =  @configurator.extension_source
    all_files        =  @configurator.collection_all_existing_compilation_input.to_a
    all_files        += @file_wrapper.directory_listing( File.join(@configurator.cmock_mock_path, "*#{source_extension}") ) if (@configurator.project_use_mocks)
    
    headers.each do |header|
      # we don't blow up if a header file has no corresponding source file
      source = @file_finder_helper.find_file_in_collection(header.ext(source_extension), all_files, {:should_complain => false})
      source_files << source if (not source.nil?)
    end
    
    return source_files
  end

  def find_source_file(file_path, complain = {:should_complain => true})
    source_file = File.basename(file_path).ext(@configurator.extension_source)
    return @file_finder_helper.find_file_in_collection(source_file, @configurator.collection_all_source, complain)
  end

  def find_assembly_file(file_path)
    assembly_file = File.basename(file_path).ext(@configurator.extension_assembly)
    return @file_finder_helper.find_file_in_collection(assembly_file, @configurator.collection_all_assembly)
  end

  # given a test, open its shallow include list and build an include list with full paths from it
  def find_header_files_included_by_test(test_file)
    includes = @yaml_wrapper.load( @file_path_utils.form_preprocessed_includes_list_path(test_file) )

    # ignore files (e.g. mocks) which may not yet exist on disk
    includes.map! { |header| @file_finder_helper.find_file_in_collection(header, @configurator.collection_all_existing_compilation_input, {:should_complain => false}) }
    includes.delete_if { |header| header.nil? } 

    return includes
  end
    
end

