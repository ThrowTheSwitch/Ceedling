require 'rubygems'
require 'rake' # for ext()
require 'fileutils'


class FilePathUtils

  GLOB_MATCHER = /[\*\?\{\}\[\]]/

  constructor :configurator, :file_wrapper


  ######### class methods ##########

  # standardize path to use '/' path separator & begin with './' & have no trailing path separator
  def self.standardize(path)
    path.strip!
    path.gsub!(/\\/, '/')
    path.gsub!(/^\.\//, '')
    path.chomp!('/')
    return path
  end


  # extract directory path up to glob specifiers
  # note: slightly different than File.dirname in that /files/foo remains /files/foo and does not become /files
  def self.dirname(path)
    path.strip!
    
    # find first occurrence of path separator followed by directory glob specifier: *, ?, {, }, [, ]
    find_index = (path =~ GLOB_MATCHER)
    
    # no changes needed (lop off final path separator)
    return path.chomp('/') if (find_index.nil?)
    
    # extract up to first glob specifier
    path = path[0..(find_index-1)]
    
    # lop off everything up to and including final path separator
    find_index = path.rindex('/')
    return path[0..(find_index-1)] if (not find_index.nil?)
    
    # return string up to first glob specifier if no path separator found
    return path
  end

  
  # all the globs that may be in a path string work fine with one exception;
  # to recurse through all subdirectories, the glob is dir/**/** but our paths use
  # convention of only dir/**
  def self.reform_glob(path)
    return path if (path =~ /\/\*\*$/).nil?
    return path + '/**'
  end

  def self.form_ceedling_vendor_path(filepath)
    return File.join( CEEDLING_ROOT, 'vendor', filepath)
  end

  ######### instance methods ##########
 
  def form_temp_path(filepath)
    return File.join( @configurator.project_temp_path, File.basename(filepath) )    
  end

  def form_runner_object_filepath_from_test(filepath)
    return (form_object_filepath(filepath)).sub(/(#{@configurator.extension_object})$/, "#{@configurator.test_runner_file_suffix}\\1")
  end

  def form_object_filepath(filepath)
    return File.join( @configurator.project_test_build_output_path, File.basename(filepath).ext(@configurator.extension_object) )
  end

  def form_executable_filepath(filepath)
    return File.join( @configurator.project_test_build_output_path, File.basename(filepath).ext(@configurator.extension_executable) )    
  end

  def form_preprocessed_file_path(filepath)
    return File.join( @configurator.project_test_preprocess_files_path, File.basename(filepath) )    
  end

  def form_preprocessed_includes_list_path(filepath)
    return File.join( @configurator.project_test_preprocess_includes_path, File.basename(filepath) )    
  end

  def form_source_objects_filelist(sources)
    return (@file_wrapper.instantiate_file_list(sources)).pathmap("#{@configurator.project_test_build_output_path}/%n#{@configurator.extension_object}")
  end

  def form_preprocessed_includes_list_filelist(files)
    return (@file_wrapper.instantiate_file_list(files)).pathmap("#{@configurator.project_test_preprocess_includes_path}/%f")
  end
  
  def form_preprocessed_files_filelist(files)
    return (@file_wrapper.instantiate_file_list(files)).pathmap("#{@configurator.project_test_preprocess_files_path}/%f")
  end

  def form_preprocessed_mockable_headers_filelist(mocks)
    # pathmapping note: "%{#{@configurator.cmock_mock_prefix},}n" replaces mock_prefix with nothing (signified by absence of anything after comma inside replacement brackets)
    return (@file_wrapper.instantiate_file_list(mocks)).pathmap("#{@configurator.project_test_preprocess_files_path}/%{#{@configurator.cmock_mock_prefix},}n#{@configurator.extension_header}")
  end

  def form_mocks_filelist(mocks)
    return (@file_wrapper.instantiate_file_list(mocks)).pathmap("#{@configurator.cmock_mock_path}/%n#{@configurator.extension_source}")
  end

  def form_dependencies_filelist(files)
    return (@file_wrapper.instantiate_file_list(files)).pathmap("#{@configurator.project_test_dependencies_path}/%n#{@configurator.extension_dependencies}")    
  end

end
