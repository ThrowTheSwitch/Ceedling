# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/partials/partials'
require 'ceedling/file_path_utils'
require 'ceedling/generator_test_runner' # From lib/ not vendor/unity/auto
require 'ceedling/encodinator'

class TestContextExtractor

  # Context extraction options
  module Context
    BUILD_DIRECTIVE_INCLUDE_PATHS = :build_directive_include_paths
    BUILD_DIRECTIVE_SOURCE_FILES  = :build_directive_source_files
    INCLUDES                      = :includes
    TEST_RUNNER_DETAILS           = :test_runner_details
    PARTIALS_CONFIGURATION        = :partials_configuration
    
    ALL = [
      BUILD_DIRECTIVE_INCLUDE_PATHS,
      BUILD_DIRECTIVE_SOURCE_FILES,
      INCLUDES,
      TEST_RUNNER_DETAILS,
      PARTIALS_CONFIGURATION
    ].freeze
  end

  constructor :configurator, :parsing_parcels, :include_factory, :file_path_utils, :file_wrapper, :loginator

  def setup
    # Per test-file lookup hashes
    @header_includes     = {} # Full list of all headers as Include objects from #include statements
    @source_includes     = {} # List of C files #include'd in a test file as Include objects
    @source_extras       = {} # List of C source files as strings outside of header convention added to test build by TEST_SOURCE_FILE()
    @test_runner_details = {} # Test case lists & Unity runner generator instances
    @partials_config     = {} # List of single item hash Partials configuration by test name
    @include_paths       = {} # List of additional search paths as strings added to a test build via TEST_INCLUDE_PATH()
    
    # Arrays
    @all_include_paths   = [] # List of all search paths added through individual test files using TEST_INCLUDE_PATH()

    @lock = Mutex.new
  end

  # Reads through a file's content line by line to extract relevant information by context.
  # `content_filepath` is the file to be read.
  # `source_fileapth` is the test filepath to use for results storage and lookup.
  # `*args` is a list of context symbols.
  # If `source_filepath` is not provided, then `content_filepath` is used for results storage and lookup.
  def collect_simple_context_from_file( content_filepath, source_filepath=nil, *args )
    # Load content_filepath
    @file_wrapper.open( content_filepath, 'r' ) do |input|
      collect_simple_context(
        # Use source_filepath if provided, else use content_filepath
        (source_filepath.nil? ? content_filepath : source_filepath),
        input,
        *args
      )
    end
  end

  # Reads through IO interface line by line to extract relevant information by context.
  # `*args` is a list of context symbols.
  # `input` must have the interface of IO -- StringIO for testing or File in typical use.
  def collect_simple_context( filepath, input, *args )
    # Code error check--bad context symbol argument
    args.each do |context|
      msg = "Unrecognized test context for collection :#{context}"
      raise CeedlingException.new( msg ) if !Context::ALL.include?( context )
    end

    include_paths = []
    source_extras = []
    includes = []
    partials_config = []

    @parsing_parcels.code_lines( input ) do |line|
      if args.include?( :build_directive_include_paths )
        # Scan for build directives: TEST_INCLUDE_PATH()
        include_paths += extract_build_directive_include_paths( line )
      end

      if args.include?( :build_directive_source_files )
        # Scan for build directives: TEST_SOURCE_FILE()
        source_extras += extract_build_directive_source_files( line )
      end

      if args.include?( :includes )
        # Scan for contents of #include directives
        includes += _extract_includes( line )
      end

      if args.include?( :partials_configuration )
        # Scan for Partials directive macros
        partials_config += _extract_partials_config( line )
      end
    end

    collect_build_directive_include_paths( filepath, include_paths ) if !include_paths.empty?
    collect_build_directive_source_files( filepath, source_extras ) if !source_extras.empty?
    collect_includes( filepath, partials_config, includes ) if (!includes.empty? or !partials_config.empty?)
    collect_partials_configuration( filepath, partials_config ) if !partials_config.empty?

    # Different code processing pattern for test runner
    if args.include?( :test_runner_details )
      # Go back to beginning of IO object for a full string extraction
      input.rewind()

      # Ultimately, we rely on Unity's runner generator that processes file contents as a single string
      _collect_test_runner_details( filepath, input.read() )
    end
  end

  def collect_test_runner_details(test_filepath, input_filepath=nil)
    # Ultimately, we rely on Unity's runner generator that processes file contents as a single string
    _collect_test_runner_details(
      test_filepath,
      @file_wrapper.read( test_filepath ),
      input_filepath.nil? ? nil : @file_wrapper.read( input_filepath )
    )
  end

  # All header includes .h as list of Include objects of test file
  def lookup_all_header_includes_list(filepath)
    val = nil
    @lock.synchronize do
      val = @header_includes[form_file_key( filepath )] || []
    end
    return val
  end

  # Include paths of test file specified with TEST_INCLUDE_PATH()
  def lookup_include_paths_list(filepath)
    val = nil
    @lock.synchronize do
      val = @include_paths[form_file_key( filepath )] || []
    end
    return val
  end

  # Source C includes as list of Include objects within test file
  def lookup_source_includes_list(filepath)
    val = nil
    @lock.synchronize do
      val = @source_includes[form_file_key( filepath )] || []
    end
    return val
  end

  # Source extras as list of string via TEST_SOURCE_FILE() within test file
  def lookup_build_directive_sources_list(filepath)
    val = nil
    @lock.synchronize do
      val = @source_extras[form_file_key( filepath )] || []
    end
    return val
  end

  # Test case names as list of strings
  def lookup_test_cases(filepath)
    val = []
    @lock.synchronize do
      details = @test_runner_details[form_file_key( filepath )]
      if !details.nil?
        val = details[:test_cases]
      end
    end
    return val
  end

  # Fetch Unity runner generator instance for test file
  def lookup_test_runner_generator(filepath)
    val = nil
    @lock.synchronize do
      details = @test_runner_details[form_file_key( filepath )]
      if !details.nil?
        val = details[:generator]
      end
    end
    return val
  end

  # Mocks within test file header includes list as list of MockInclude objects
  def lookup_mock_header_includes_list(filepath)
    includes = lookup_all_header_includes_list(filepath)
    return includes.select { |include| include.is_a?( MockInclude ) }
  end

  # Test file header includes list minus mocks as list of Include objects
  def lookup_nonmock_header_includes_list(filepath)
    includes = lookup_all_header_includes_list(filepath)
    return includes.reject { |include| include.is_a?( MockInclude ) }
  end

  # List of single item hashes for Partials configuration by test name
  # { <Partial type symbol> => <Module name string> }
  def lookup_partials_config(filepath)
    val = nil
    @lock.synchronize do
      val = @partials_config[form_file_key( filepath )] || []
    end
    return val
  end

  # Full list of all search paths added through individual test files using TEST_INCLUDE_PATH()
  def lookup_all_include_paths()
    val = nil
    @lock.synchronize do
      val = @all_include_paths.uniq
    end
    return val
  end

  def inspect_include_paths()
    @lock.synchronize do
      @include_paths.each { |test, paths| yield test, paths }
    end
  end

  # Unlike other ingest() calls, ingest_includes() can be called externally.
  def ingest_includes(filepath, includes)
    _includes = Includes.sanitize(includes)

    file_key = form_file_key( filepath )
    
    headers = []
    sources = []

    # Processing list of UserInclude and/or SystemInclude
    _includes.each do |include|
      # <*.h>
      if include.filename =~ /#{Regexp.escape(@configurator.extension_header)}$/
        # Add to .h includes list
        headers << include
      elsif include.filename =~ /#{Regexp.escape(@configurator.extension_source)}$/
        # Add to .c includes list
        sources << include
      end
    end

    @lock.synchronize do
      @header_includes[file_key] = headers
      @source_includes[file_key] = sources
    end

    return _includes
  end

  private #################################

  def collect_build_directive_source_files(filepath, files)
    _files = files.compact
    _files.uniq!

    ingest_build_directive_source_files( filepath, _files )

    debug_log_list(
      "Extra source files found via TEST_SOURCE_FILE()",
      filepath,
      _files
    )
  end

  def collect_build_directive_include_paths(filepath, paths)
    ingest_build_directive_include_paths( filepath, paths.uniq )

    debug_log_list(
      "Search paths for #includes found via TEST_INCLUDE_PATH()",
      filepath,
      paths
    )
  end

  def collect_includes(filepath, partials_config, includes)
    # Squeeze out any nil elements
    includes.compact!

    # `partials_config` is a list of single element hashes.
    # Each hash associates a partial type with module name (no file extension).
    # Note: This processing can yield duplicate includes, but `ingest_includes()` handles duplicates.
    partials_config.each do |config|
      # Switch on partial type
      _module = config.values.first
      case config.keys.first
      when Partials::TEST_PUBLIC, Partials::TEST_PRIVATE
        filename = @file_path_utils.form_partial_implementation_header_filename( _module )
        includes << @include_factory.user_include_from_filepath( filename )
      when Partials::MOCK_PUBLIC, Partials::MOCK_PRIVATE
        filename = @file_path_utils.form_mock_partial_interface_header_filename( _module )
        includes << @include_factory.user_include_from_filepath( filename )
      end
    end

    # `ingest_includes()` does some housekeeping on the list
    _includes = ingest_includes( filepath, includes )

    debug_log_list( "#includes found", filepath, _includes )
  end

  def collect_partials_configuration(filepath, partials_config)
    partials_config.uniq!
    ingest_partials_configuration(filepath, partials_config)
    debug_log_list( "Partials configurations found", filepath, partials_config )
  end

  def _collect_test_runner_details(filepath, test_content, input_content=nil)
    unity_test_runner_generator = GeneratorTestRunner.new(
      config: @configurator.get_runner_config,
      test_file_contents: test_content,
      preprocessed_file_contents: input_content
    )

    ingest_test_runner_details(
      filepath: filepath,
      test_runner_generator: unity_test_runner_generator
    )

    test_cases = unity_test_runner_generator.test_cases
    test_cases = test_cases.map {|test_case| "#{test_case[:line_number]}:#{test_case[:test]}()" }

    debug_log_list( "Test cases found", filepath, test_cases )
  end

  def extract_build_directive_source_files(line)
    source_extras = []

    # Look for TEST_SOURCE_FILE("<*>") statement
    results = line.scan(PATTERNS::TEST_SOURCE_FILE)
    results.each do |result|
      source_extras << FilePathUtils.standardize( result[0] )
    end

    return source_extras
  end

  def extract_build_directive_include_paths(line)
    include_paths = []

    # Look for TEST_INCLUDE_PATH("<*>") statements
    results = line.scan(PATTERNS::TEST_INCLUDE_PATH)
    results.each do |result|
      include_paths << FilePathUtils.standardize( result[0] )
    end

    return include_paths
  end

  def _extract_includes(line)
    includes = []

    _include = @include_factory.system_include_from_directive( line )
    includes << _include if !_include.nil?

    # All of the UserInclude types
    _include = @include_factory.user_include_from_directive( line )
    includes << _include if !_include.nil?
  
    return includes
  end

  def _extract_partials_config(line)
    configs = []

    # Look for #include partials config directives
    results = line.match(PATTERNS::TEST_PARTIAL_PUBLIC_MODULE)
    if !results.nil?
      configs << {Partials::TEST_PUBLIC => results[1]}
      return configs
    end

    results = line.match(PATTERNS::TEST_PARTIAL_PRIVATE_MODULE)
    if !results.nil?
      configs << {Partials::TEST_PRIVATE => results[1]}
      return configs
    end

    results = line.match(PATTERNS::MOCK_PARTIAL_PUBLIC_MODULE)
    if !results.nil?
      configs << {Partials::MOCK_PUBLIC => results[1]}
      return configs
    end

    results = line.match(PATTERNS::MOCK_PARTIAL_PRIVATE_MODULE)
    if !results.nil?
      configs << {Partials::MOCK_PRIVATE => results[1]}
      return configs
    end

    return configs
  end

  ##
  ## Data structure management ingest methods
  ##

  def ingest_build_directive_source_files(filepath, source_extras)
    return if source_extras.empty?
    
    key = form_file_key( filepath )

    @lock.synchronize do
      @source_extras[key] = source_extras
    end
  end

  def ingest_build_directive_include_paths(filepath, include_paths)
    return if include_paths.empty?

    key = form_file_key( filepath )

    @lock.synchronize do
      @include_paths[key] = include_paths
    end

    @lock.synchronize do
      @all_include_paths += include_paths
    end
  end

  def ingest_test_runner_details(filepath:, test_runner_generator:)
    key = form_file_key( filepath )

    @lock.synchronize do
      @test_runner_details[key] = {
        :test_cases => test_runner_generator.test_cases,
        :generator => test_runner_generator
      }
    end
  end

  def ingest_partials_configuration(filepath, partials_config)
    return if partials_config.empty?
    
    key = form_file_key( filepath )

    @lock.synchronize do
      @partials_config[key] = partials_config
    end
  end 

  ##
  ## Utility methods
  ##

  def form_file_key( filepath )
    return filepath.to_s.to_sym
  end

  def debug_log_list(message, filepath, list)
    header = "#{message} in #{filepath}"
    @loginator.log_list( list, header, Verbosity::DEBUG )
  end

end
