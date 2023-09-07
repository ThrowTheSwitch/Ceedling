
require 'pathname'

class IncludePathinator

  constructor :configurator, :test_context_extractor, :streaminator, :file_wrapper

  def setup
    # TODO: When Ceedling's base project path handling is resolved, update this value to automatically 
    #       modify TEST_INCLUDE_PATH() locations relative to the working directory or project file location
    # @base_path = '.'

    # Alias for brevity
    @extractor = @test_context_extractor
  end

  def validate_test_directive_paths
    @extractor.inspect_include_paths do |test_filepath, include_paths|
      include_paths.each do |path|

        # TODO: When Ceedling's base project path handling is resolved, enable this path redefinition
        # path = File.join( @base_path, path )
        unless @file_wrapper.exist?(path)
          @streaminator.stderr_puts("'#{path}' specified by #{UNITY_TEST_INCLUDE_PATH}() within #{test_filepath} not found", Verbosity::NORMAL)
          raise
        end
      end
    end
  end

  def augment_environment_header_files
    # Get existing, possibly minimal header file collection
    headers = @configurator.collection_all_headers

    # Get all paths specified by TEST_INCLUDE_PATH() directive in test files
    directive_paths = @extractor.lookup_all_include_paths

    # Add to collection of headers (Rake FileList) with directive paths and shallow wildcard matching on header file extension
    headers += @file_wrapper.instantiate_file_list( directive_paths.map { |path| File.join(path, '*' + EXTENSION_HEADER) } )

    headers.uniq!

    @configurator.redefine_element(:collection_all_headers, headers)
  end

  def lookup_test_directive_include_paths(filepath)
    # TODO: When Ceedling's base project path handling is resolved, enable this path redefinition
    # return @extractor.lookup_include_paths_list(filepath).map { |path| File.join( @base_path, path) }
    return @extractor.lookup_include_paths_list(filepath)
  end

end
