
class TestInvokerHelper

  constructor :configurator,
              :streaminator,
              :build_batchinator,
              :task_invoker,
              :test_context_extractor,
              :include_pathinator,
              :defineinator,
              :flaginator,
              :file_finder,
              :file_path_utils,
              :file_wrapper,
              :generator

  def setup
    # Alias for brevity
    @batchinator = @build_batchinator
  end

  def process_project_include_paths
    @include_pathinator.validate_test_directive_paths
    @include_pathinator.augment_environment_header_files
  end

  def validate_build_directive_source_files(test:, filepath:)
    sources = @test_context_extractor.lookup_build_directive_sources_list(filepath)

    sources.each do |source|
      ext = @configurator.extension_source
      unless @file_wrapper.extname(source) == ext
        @streaminator.stderr_puts("File '#{source}' specified with #{UNITY_TEST_SOURCE_FILE}() in #{test} is not a #{ext} source file", Verbosity::NORMAL)
        raise
      end

      if @file_finder.find_compilation_input_file(source, :ignore).nil?
        @streaminator.stderr_puts("File '#{source}' specified with #{UNITY_TEST_SOURCE_FILE}() in #{test} cannot be found in the source file collection", Verbosity::NORMAL)
        raise
      end
    end
  end

  def search_paths(filepath, subdir)
    paths = @include_pathinator.lookup_test_directive_include_paths( filepath )
    paths += @configurator.collection_paths_include
    paths += @configurator.collection_paths_support
    paths << File.join( @configurator.cmock_mock_path, subdir ) if @configurator.project_use_mocks
    paths += @configurator.collection_paths_libraries
    paths += @configurator.collection_paths_vendor
    paths += @configurator.collection_paths_test_toolchain_include
    
    return paths.uniq
  end

  def compile_defines(context:, filepath:)
    # If this context exists ([:defines][context]), use it. Otherwise, default to test context.
    context = TEST_SYM unless @defineinator.defines_defined?( context:context )

    # Defines for the test file
    return @defineinator.defines( context:context, filepath:filepath )
  end

  def augment_vendor_defines(filepath:, defines:)
    # Start with base defines provided
    _defines = defines

    # Unity defines
    if filepath == File.join(PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE)
      _defines += @defineinator.defines( context:UNITY_SYM )

    # CMock defines
    elsif filepath == File.join(PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE)
      _defines += @defineinator.defines( context:CMOCK_SYM ) if @configurator.project_use_mocks

    # CException defines
    elsif filepath == File.join(PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE)
      _defines += @defineinator.defines( context:CEXCEPTION_SYM ) if @configurator.project_use_exceptions
    end

    return _defines.uniq
  end

  def preprocess_defines(test_defines:, filepath:)
    # Preprocessing defines for the test file
    preprocessing_defines = @defineinator.defines( context:PREPROCESS_SYM, filepath:filepath )

    # If no preprocessing defines are present, default to the test compilation defines
    return (preprocessing_defines.empty? ? test_defines : preprocessing_defines)
  end

  def flags(context:, operation:, filepath:)
    # If this context + operation exists ([:flags][context][operation]), use it. Otherwise, default to test context.
    context = TEST_SYM unless @flaginator.flags_defined?( context:context, operation:operation )

    return @flaginator.flag_down( context:context, operation:operation, filepath:filepath )
  end

  def collect_test_framework_sources
    sources = []

    sources << File.join(PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE)
    sources << File.join(PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE) if @configurator.project_use_mocks
    sources << File.join(PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE) if @configurator.project_use_exceptions

    # If we're (a) using mocks (b) a Unity helper is defined and (c) that unity helper includes a source file component,
    # then link in the unity_helper object file too.
    if ( @configurator.project_use_mocks and @configurator.cmock_unity_helper )
      @configurator.cmock_unity_helper.each do |helper|
        if @file_wrapper.exist?(helper.ext(EXTENSION_SOURCE))
          sources << helper
        end
      end
    end

    return sources
  end

  def process_deep_dependencies(files)
    return if (not @configurator.project_use_deep_dependencies)

    dependencies_list = @file_path_utils.form_test_dependencies_filelist( files ).uniq

    if @configurator.project_generate_deep_dependencies
      @task_invoker.invoke_test_dependencies_files( dependencies_list )
    end

    yield( dependencies_list ) if block_given?
  end
  
  def extract_sources(test_filepath)
    sources = []

    # Get any additional source files specified by TEST_SOURCE_FILE() in test file
    _sources = @test_context_extractor.lookup_build_directive_sources_list(test_filepath)
    _sources.each do |source|
      sources << @file_finder.find_compilation_input_file(source, :ignore)
    end

    # Get all #include .h files from test file so we can find any source files by convention
    includes = @test_context_extractor.lookup_header_includes_list(test_filepath)
    includes.each do |include|
      next if File.basename(include).start_with?(CMOCK_MOCK_PREFIX) # Ignore mocks in this list
      sources << @file_finder.find_compilation_input_file(include, :ignore)
    end

    # Remove any nil or duplicate entries in list
    return sources.compact.uniq
  end

  def fetch_shallow_source_includes(test_filepath)
    return @test_context_extractor.lookup_source_includes_list(test_filepath)
  end

  def fetch_include_search_paths_for_test_file(test_filepath)
    return @test_context_extractor.lookup_include_paths_list(test_filepath)
  end

  # TODO: Use search_paths to find/match header file from which to generate mock
  def find_header_input_for_mock_file(mock, search_paths)
    return @file_finder.find_header_input_for_mock_file(mock)
  end

  def clean_test_results(path, tests)
    tests.each do |test|
      @file_wrapper.rm_f( Dir.glob( File.join( path, test + '.*' ) ) )
    end
  end

  def generate_objects_now(object_list, context, options)
    @batchinator.exec(workload: :compile, things: object_list) do |object|
      src = @file_finder.find_compilation_input_file(object)
      if (File.basename(src) =~ /#{EXTENSION_SOURCE}$/)
        @generator.generate_object_file(
          options[:test_compiler],
          OPERATION_COMPILE_SYM,
          context,
          src,
          object,
          @file_path_utils.form_test_build_list_filepath( object ),
          @file_path_utils.form_test_dependencies_filepath( object ))
      elsif (defined?(TEST_BUILD_USE_ASSEMBLY) && TEST_BUILD_USE_ASSEMBLY)
        @generator.generate_object_file(
          options[:test_assembler],
          OPERATION_ASSEMBLE_SYM,
          context,
          src,
          object )
      end
    end
  end

  # Convert libraries configuration form YAML configuration
  # into a string that can be given to the compiler.
  def convert_libraries_to_arguments()
    args = ((@configurator.project_config_hash[:libraries_test] || []) + ((defined? LIBRARIES_SYSTEM) ? LIBRARIES_SYSTEM : [])).flatten
    if (defined? LIBRARIES_FLAG)
      args.map! {|v| LIBRARIES_FLAG.gsub(/\$\{1\}/, v) }
    end
    return args
  end

  def get_library_paths_to_arguments()
    paths = (defined? PATHS_LIBRARIES) ? (PATHS_LIBRARIES || []).clone : []
    if (defined? LIBRARIES_PATH_FLAG)
      paths.map! {|v| LIBRARIES_PATH_FLAG.gsub(/\$\{1\}/, v) }
    end
    return paths
  end

  def generate_executable_now(context:, build_path:, executable:, objects:, flags:, lib_args:, lib_paths:, options:)
    @generator.generate_executable_file(
      options[:test_linker],
      context,
      objects.map{|v| "\"#{v}\""},
      flags,
      executable,
      @file_path_utils.form_test_build_map_filepath( build_path, executable ),
      lib_args,
      lib_paths )
  end

  def run_fixture_now(context:, executable:, result:, options:)
    @generator.generate_test_results(
      tool:       options[:test_fixture], 
      context:    context,
      executable: executable, 
      result:     result)
  end
  
end
