# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'pathname'
require 'ceedling/exceptions'

class IncludePathinator

  constructor :configurator, :test_context_extractor, :loginator, :file_wrapper

  def setup
    # TODO: When Ceedling's base project path handling is resolved, update this value to automatically 
    #       modify TEST_INCLUDE_PATH() locations relative to the working directory or project file location
    # @base_path = '.'

    # Alias for brevity
    @extractor = @test_context_extractor
  end

  def validate_test_build_directive_paths
    @extractor.inspect_include_paths do |test_filepath, include_paths|
      include_paths.each do |path|

        # TODO: When Ceedling's base project path handling is resolved, enable this path redefinition
        # path = File.join( @base_path, path )
        unless @file_wrapper.exist?(path)
          error = "'#{path}' specified by #{UNITY_TEST_INCLUDE_PATH}() within #{test_filepath} not found"
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

    # Add to collection of headers (Rake FileList) with directive paths and shallow wildcard matching on header file extension
    headers += @file_wrapper.instantiate_file_list( directive_paths.map { |path| File.join(path, '*' + EXTENSION_HEADER) } )
    headers.resolve()

    headers.uniq!

    if headers.length == 0
      error = "No header files found in project.\n" +
              "Add search paths to :paths ↳ :include in your project file and/or use #{UNITY_TEST_INCLUDE_PATH}() in your test files.\n" +
              "Verify header files with `ceedling paths:include` and\\or `ceedling files:include`."
      @loginator.log( error, Verbosity::COMPLAIN )
    end

    return headers
  end

  def augment_environment_header_files(headers)
    @configurator.redefine_element(:collection_all_headers, headers)
  end

  def lookup_test_directive_include_paths(filepath)
    # TODO: When Ceedling's base project path handling is resolved, enable this path redefinition
    # return @extractor.lookup_include_paths_list(filepath).map { |path| File.join( @base_path, path) }
    return @extractor.lookup_include_paths_list(filepath)
  end

  # Gather together [:paths][:test] that actually contain .h files
  def collect_test_include_paths
    paths = []
    @configurator.collection_paths_test.each do |path|
      headers = @file_wrapper.directory_listing( File.join( path, '*' + @configurator.extension_header ) )
      paths << path if headers.length > 0
    end

    return paths
  end

end
