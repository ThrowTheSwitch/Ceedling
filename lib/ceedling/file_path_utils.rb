# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rubygems'
require 'rake' # for ext()
require 'fileutils'
require 'ceedling/system_wrapper'

# global utility methods (for plugins, project files, etc.)
def ceedling_form_filepath(destination_path, original_filepath, new_extension=nil)
  filename = File.basename(original_filepath)
  filename.replace(filename.ext(new_extension)) if (!new_extension.nil?)
  return File.join( destination_path.gsub(/\\/, '/'), filename )
end

class FilePathUtils

  constructor :configurator, :file_wrapper


  ######### Class methods ##########

  # Standardize path to use '/' path separator & have no trailing path separator
  def self.standardize(path)
    if path.is_a? String
      path.strip!
      path.gsub!(/\\/, '/')
      path.chomp!('/')
    end
    return path
  end

  def self.os_executable_ext(executable)
    return executable.ext('.exe') if SystemWrapper.windows?
    return executable
  end

  # Extract path from between optional aggregation modifiers 
  # and up to last path separator before glob specifiers.
  # Examples:
  #  - '+:foo/bar/baz/'       => 'foo/bar/baz'
  #  - 'foo/bar/ba?'          => 'foo/bar'
  #  - 'foo/bar/baz/'         => 'foo/bar/baz'
  #  - 'foo/bar/baz/file.x'   => 'foo/bar/baz/file.x'
  #  - 'foo/bar/baz/file*.x'  => 'foo/bar/baz'
  def self.no_decorators(path)
    path = self.no_aggregation_decorators(path)

    # Find first occurrence of glob specifier: *, ?, {, }, [, ]
    find_index = (path =~ GLOB_PATTERN)

    # Return empty path if first character is part of a glob
    return '' if find_index == 0

    # If path contains no glob, clean it up and return whole path
    return path.chomp('/') if (find_index.nil?)

    # Extract up to first glob specifier
    path = path[0..(find_index-1)]

    # Keep everything from start of path string up to and 
    # including final path separator before glob character
    find_index = path.rindex('/')
    return path[0..(find_index-1)] if (not find_index.nil?)

    # Otherwise, return empty string
    # (Not enough of a usable path exists free of glob operators)
    return ''
  end

  # Return whether the given path is to be aggregated (no aggregation modifier defaults to same as +:)
  def self.add_path?(path)
    return !path.strip.start_with?('-:')
  end

  # Get path (and glob) lopping off optional +: / -: prefixed aggregation modifiers
  def self.no_aggregation_decorators(path)
    return path.sub(/^(\+|-):/, '').strip()
  end

  # To recurse through all subdirectories, the RUby glob is <dir>/**/**, but our paths use
  # convenience convention of only <dir>/** at tail end of a path.
  def self.reform_subdirectory_glob(path)
    return path if path.end_with?( '/**/**' )
    return path + '/**' if path.end_with?( '/**' )
    return path
  end

  ######### instance methods ##########

  ### release ###
  def form_release_build_cache_path(filepath)
    return File.join( @configurator.project_release_build_cache_path, File.basename(filepath) )
  end

  def form_release_dependencies_filepath(filepath)
    return File.join( @configurator.project_release_dependencies_path, File.basename(filepath).ext(@configurator.extension_dependencies) )
  end

  def form_release_build_objects_filelist(files)
    return (@file_wrapper.instantiate_file_list(files)).pathmap("#{@configurator.project_release_build_output_path}/%n#{@configurator.extension_object}")
  end

  def form_release_build_list_filepath(filepath)
    return File.join( @configurator.project_release_build_output_path, File.basename(filepath).ext(@configurator.extension_list) )
  end

  def form_release_dependencies_filelist(files)
    return (@file_wrapper.instantiate_file_list(files)).pathmap("#{@configurator.project_release_dependencies_path}/%n#{@configurator.extension_dependencies}")
  end

  ### Tests ###

  def form_test_build_cache_path(filepath)
    return File.join( @configurator.project_test_build_cache_path, File.basename(filepath) )
  end

  def form_test_dependencies_filepath(filepath)
    return File.join( @configurator.project_test_dependencies_path, File.basename(filepath).ext(@configurator.extension_dependencies) )
  end

  def form_pass_results_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_testpass) )
  end

  def form_fail_results_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_testfail) )
  end

  def form_runner_filepath_from_test(filepath)
    return File.join( @configurator.project_test_runners_path, File.basename(filepath, @configurator.extension_source)) + @configurator.test_runner_file_suffix + EXTENSION_CORE_SOURCE
  end

  def form_test_filepath_from_runner(filepath)
    return filepath.sub(/#{TEST_RUNNER_FILE_SUFFIX}/, '')
  end

  def form_test_executable_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_executable) )
  end

  def form_test_build_map_filepath(build_output_path, filepath)
    return File.join( build_output_path, File.basename(filepath).ext(@configurator.extension_map) )
  end

  def form_test_build_list_filepath(filepath)
    return File.join( @configurator.project_test_build_output_path, File.basename(filepath).ext(@configurator.extension_list) )
  end

  def form_preprocessed_file_filepath(filepath, subdir)
    return File.join( @configurator.project_test_preprocess_files_path, subdir, File.basename(filepath) )
  end

  def form_preprocessed_includes_list_filepath(filepath, subdir)
    return File.join( @configurator.project_test_preprocess_includes_path, subdir, File.basename(filepath) + @configurator.extension_yaml )
  end

  def form_test_build_objects_filelist(path, sources)
    return (@file_wrapper.instantiate_file_list(sources)).pathmap("#{path}/%n#{@configurator.extension_object}")
  end

  def form_mocks_source_filelist(path, mocks)
    list = (@file_wrapper.instantiate_file_list(mocks))
    return list.map{ |file| File.join(path, File.basename(file).ext(@configurator.extension_source)) }
  end

  def form_test_dependencies_filelist(files)
    list = @file_wrapper.instantiate_file_list(files)
    return list.pathmap("#{@configurator.project_test_dependencies_path}/%n#{@configurator.extension_dependencies}")
  end

  def form_pass_results_filelist(path, files)
    list = @file_wrapper.instantiate_file_list(files)
    return list.pathmap("#{path}/%n#{@configurator.extension_testpass}")
  end

end
