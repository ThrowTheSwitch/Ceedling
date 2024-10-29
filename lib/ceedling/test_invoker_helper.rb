# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

class TestInvokerHelper

  constructor :configurator,
              :loginator,
              :build_batchinator,
              :task_invoker,
              :test_context_extractor,
              :include_pathinator,
              :preprocessinator,
              :defineinator,
              :flaginator,
              :file_finder,
              :file_path_utils,
              :file_wrapper,
              :generator,
              :test_runner_manager

  def setup
    # Alias for brevity
    @batchinator = @build_batchinator
  end

  def process_project_include_paths
    @include_pathinator.validate_test_build_directive_paths
    headers = @include_pathinator.validate_header_files_collection
    @include_pathinator.augment_environment_header_files(headers)
  end

  def extract_include_directives(arg_hash)
    # Run test file through preprocessor to parse out include statements and then collect header files, mocks, etc.
    includes = @preprocessinator.preprocess_includes( **arg_hash )

    # Store the include statements we found
    @test_context_extractor.ingest_includes( arg_hash[:filepath], includes )
  end

  def validate_build_directive_source_files(test:, filepath:)
    sources = @test_context_extractor.lookup_build_directive_sources_list(filepath)

    ext_message = @configurator.extension_source
    if @configurator.test_build_use_assembly
      ext_message += " or #{@configurator.extension_assembly}"
    end

    sources.each do |source|
      valid_extension = true

      # Only C files in test build
      if not @configurator.test_build_use_assembly
        valid_extension = false if @file_wrapper.extname(source) != @configurator.extension_source      
      # C and assembly files in test build
      else
        ext = @file_wrapper.extname(source)
        valid_extension = false if (ext != @configurator.extension_assembly) and (ext != @configurator.extension_source)
      end

      if not valid_extension
        error = "File '#{source}' specified with #{UNITY_TEST_SOURCE_FILE}() in #{test} is not a #{ext_message} source file"
        raise CeedlingException.new(error)
      end

      if @file_finder.find_build_input_file(filepath: source, complain: :ignore, context: TEST_SYM).nil?
        error = "File '#{source}' specified with #{UNITY_TEST_SOURCE_FILE}() in #{test} cannot be found in the source file collection"
        raise CeedlingException.new(error)
      end
    end
  end

  def search_paths(filepath, subdir)
    paths = []

    # Start with mock path to ensure any CMock-reworked header files are encountered first
    paths << File.join( @configurator.cmock_mock_path, subdir ) if @configurator.project_use_mocks
    paths += @include_pathinator.lookup_test_directive_include_paths( filepath )
    paths += @include_pathinator.collect_test_include_paths()
    paths += @configurator.collection_paths_support
    paths += @configurator.collection_paths_include
    paths += @configurator.collection_paths_libraries
    paths += @configurator.collection_paths_vendor
    paths += @configurator.collection_paths_test_toolchain_include
    
    return paths.uniq
  end

  def framework_defines()
    defines = []

    # Unity defines
    defines += @defineinator.defines( topkey:UNITY_SYM, subkey: :defines )

    # CMock defines
    defines += @defineinator.defines( topkey:CMOCK_SYM, subkey: :defines )

    # CException defines
    defines += @defineinator.defines( topkey:CEXCEPTION_SYM, subkey: :defines )

    return defines.uniq
  end

  def tailor_search_paths(filepath:, search_paths:)
    _search_paths = []

    # Unity search paths
    if filepath == File.join(PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE)
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_UNITY_PATH

    # CMock search paths
    elsif @configurator.project_use_mocks and 
      (filepath == File.join(PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE))
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_UNITY_PATH
      _search_paths << PROJECT_BUILD_VENDOR_CMOCK_PATH
      _search_paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH if @configurator.project_use_exceptions

    # CException search paths
    elsif @configurator.project_use_exceptions and 
      (filepath == File.join(PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE))
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH

    # Support files search paths
    elsif (@configurator.collection_all_support.include?(filepath))
      _search_paths = search_paths
      _search_paths += @configurator.collection_paths_support
      _search_paths << PROJECT_BUILD_VENDOR_UNITY_PATH
      _search_paths << PROJECT_BUILD_VENDOR_CMOCK_PATH if @configurator.project_use_mocks
      _search_paths << PROJECT_BUILD_VENDOR_CEXCEPTION_PATH if @configurator.project_use_exceptions
    end

    # Not a vendor file, return original search paths
    if _search_paths.length == 0
      return search_paths
    end

    return _search_paths.uniq
  end

  def runner_defines()
    return @test_runner_manager.collect_defines()
  end

  def compile_defines(context:, filepath:)
    # If this context exists ([:defines][context]), use it. Otherwise, default to test context.
    context = TEST_SYM unless @defineinator.defines_defined?( context:context )

    defines = @defineinator.generate_test_definition( filepath:filepath )
    defines += @defineinator.defines( subkey:context, filepath:filepath )

    return defines.uniq
  end

  def preprocess_defines(test_defines:, filepath:)
    # Preprocessing defines for the test file
    preprocessing_defines = @defineinator.defines( subkey:PREPROCESS_SYM, filepath:filepath, default:nil )

    # If no defines were set, default to using test_defines
    return test_defines if preprocessing_defines.nil?
      
    # Otherwise, return the defines we looked up
    # This includes an explicitly set empty list to override / clear test_defines
    return preprocessing_defines
  end

  def flags(context:, operation:, filepath:, default:[])
    # If this context + operation exists ([:flags][context][operation]), use it. Otherwise, default to test context.
    context = TEST_SYM unless @flaginator.flags_defined?( context:context, operation:operation )

    return @flaginator.flag_down( context:context, operation:operation, filepath:filepath, default:default )
  end

  def preprocess_flags(context:, compile_flags:, filepath:)
    preprocessing_flags = flags( context:context, operation:OPERATION_PREPROCESS_SYM, filepath:filepath, default:nil )

    # If no flags were set, default to using compile_flags
    return compile_flags if preprocessing_flags.nil?

    # Otherwise, return the flags we looked up
    # This includes an explicitly set empty list to override / clear compile_flags
    return preprocessing_flags
  end

  def collect_test_framework_sources(mocks)
    sources = []

    sources << File.join(PROJECT_BUILD_VENDOR_UNITY_PATH, UNITY_C_FILE)
    sources << File.join(PROJECT_BUILD_VENDOR_CMOCK_PATH, CMOCK_C_FILE) if @configurator.project_use_mocks and mocks
    sources << File.join(PROJECT_BUILD_VENDOR_CEXCEPTION_PATH, CEXCEPTION_C_FILE) if @configurator.project_use_exceptions

    # If we're (a) using mocks (b) a Unity helper is defined and (c) that unity helper includes a source file component,
    # then link in the unity_helper object file too.
    if @configurator.project_use_mocks
      @configurator.cmock_unity_helper_path.each do |helper|
        if @file_wrapper.exist?( helper.ext( EXTENSION_SOURCE ) )
          sources << helper
        end
      end
    end

    return sources
  end

  def extract_sources(test_filepath)
    sources = []

    # Get any additional source files specified by TEST_SOURCE_FILE() in test file
    _sources = @test_context_extractor.lookup_build_directive_sources_list(test_filepath)
    _sources.each do |source|
      sources << @file_finder.find_build_input_file(filepath: source, complain: :ignore, context: TEST_SYM)
    end

    _support_headers = COLLECTION_ALL_SUPPORT.map { |filepath| File.basename(filepath).ext(EXTENSION_HEADER) }

    # Get all #include .h files from test file so we can find any source files by convention
    includes = @test_context_extractor.lookup_full_header_includes_list(test_filepath)
    includes.each do |include|
      _basename = File.basename(include)
      next if _basename == UNITY_H_FILE                # Ignore Unity in this list
      next if _basename.start_with?(CMOCK_MOCK_PREFIX) # Ignore mocks in this list
      next if _support_headers.include?(_basename)     # Ignore any sources in our support files list

      sources << @file_finder.find_build_input_file(filepath: include, complain: :ignore, context: TEST_SYM)
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
  # Today, this is just a pass-through wrapper
  def find_header_input_for_mock(mock, search_paths)
    return @file_finder.find_header_input_for_mock( mock )
  end

  # Transform list of mock names into filenames with source extension
  def form_mock_filenames(mocklist)
    return mocklist.map {|mock| mock + @configurator.extension_source}
  end

  def remove_mock_original_headers( filelist, mocklist )
    filelist.delete_if do |filepath|
      # Create a simple mock name from the filepath => mock prefix + filepath base name with no extension
      mock_name = @configurator.cmock_mock_prefix + File.basename( filepath, '.*' )
      # Tell `delete_if()` logic to remove inspected filepath if simple mocklist includes the name we just generated
      mocklist.include?( mock_name )
    end
  end

  def clean_test_results(path, tests)
    tests.each do |test|
      @file_wrapper.rm_f( Dir.glob( File.join( path, test + '.*' ) ) )
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
    begin
      @generator.generate_executable_file(
        options[:test_linker],
        context,
        objects.map{|v| "\"#{v}\""},
        flags,
        executable,
        @file_path_utils.form_test_build_map_filepath( build_path, executable ),
        lib_args,
        lib_paths )
    rescue ShellException => ex
      if ex.shell_result[:output] =~ /symbol/i
        notice =    "If the linker reports missing symbols, the following may be to blame:\n" +
                    "  1. This test lacks #include statements corresponding to needed source files (see note below).\n" +
                    "  2. Project file paths omit source files corresponding to #include statements in this test.\n" +
                    "  3. Complex macros, #ifdefs, etc. have obscured correct #include statements in this test.\n" +
                    "  4. Your project is attempting to mix C++ and C file extensions (not supported).\n"
        if (@configurator.project_use_mocks)
          notice += "  5. This test does not #include needed mocks (that triggers their generation).\n"
        end

        notice +=   "\n"
        notice +=   "NOTE: A test file directs the build of a test executable with #include statemetns:\n" +
                    "  * By convention, Ceedling assumes header filenames correspond to source filenames.\n" +
                    "  * Which code files to compile and link are determined by #include statements.\n"
        if (@configurator.project_use_mocks)
          notice += "  * An #include statement convention directs the generation of mocks from header files.\n"
        end

        notice +=   "\n"
        notice +=   "OPTIONS:\n" +
                    "  1. Doublecheck this test's #include statements.\n" +
                    "  2. Simplify complex macros or fully specify symbols for this test in :project ↳ :defines.\n" +
                    "  3. If no header file corresponds to the needed source file, use the #{UNITY_TEST_SOURCE_FILE}()\n" +
                    "     build diective macro in this test to inject a source file into the build.\n\n" +
                    "See the docs on conventions, paths, preprocessing, compilation symbols, and build directive macros.\n\n"

        # Print helpful notice
        @loginator.log( notice, Verbosity::COMPLAIN, LogLabels::NOTICE )
      end

      # Re-raise the exception
      raise ex
    end
  end

  def run_fixture_now(context:, test_name:, test_filepath:, executable:, result:, options:)
    @generator.generate_test_results(
      tool:          options[:test_fixture], 
      context:       context,
      test_name:     test_name,
      test_filepath: test_filepath,
      executable:    executable, 
      result:        result)
  end
  
end
