# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/file_path_utils'
require 'ceedling/generator_test_runner' # From lib/ not vendor/unity/auto
require 'ceedling/encodinator'

class TestContextExtractor

  constructor :configurator, :file_wrapper, :loginator, :parsing_parcels

  def setup
    # Per test-file lookup hashes
    @all_header_includes = {} # Full list of all headers from test #include statements
    @header_includes     = {} # List of all headers minus mocks & framework files
    @source_includes     = {} # List of C files #include'd in a test file
    @source_extras       = {} # C source files outside of header convention added to test build by TEST_SOURCE_FILE()
    @test_runner_details = {} # Test case lists & Unity runner generator instances
    @mocks               = {} # List of mocks by name without header file extension
    @include_paths       = {} # Additional search paths added to a test build via TEST_INCLUDE_PATH()
    
    # Arrays
    @all_include_paths   = [] # List of all search paths added through individual test files using TEST_INCLUDE_PATH()

    @lock = Mutex.new
  end

  # `input` must have the interface of IO -- StringIO for testing or File in typical use
  def collect_simple_context( filepath, input, *args )
    all_options = [
      :build_directive_include_paths,
      :build_directive_source_files,
      :includes,
      :test_runner_details
    ]

    # Code error check--bad context symbol argument
    args.each do |context|
      next if context == :all
      msg = "Unrecognized test context for collection :#{context}"
      raise CeedlingException.new( msg ) if !all_options.include?( context )
    end

    # Handle the :all shortcut to redefine list to include all contexts
    args = all_options if args.include?( :all )

    include_paths = []
    source_extras = []
    includes = []

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
    end

    collect_build_directive_include_paths( filepath, include_paths ) if args.include?( :build_directive_include_paths )
    collect_build_directive_source_files( filepath, source_extras ) if args.include?( :build_directive_source_files )
    collect_includes( filepath, includes ) if args.include?( :includes )

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

  # Scan for all includes.
  # Unlike other extract() calls, extract_includes() is public to be called externally.
  # `input` must have the interface of IO -- StringIO for testing or File in typical use  
  def extract_includes(input)
    includes = []

    @parsing_parcels.code_lines( input ) {|line| includes += _extract_includes( line ) }

    return includes.uniq
  end

  # All header includes .h of test file
  def lookup_full_header_includes_list(filepath)
    val = nil
    @lock.synchronize do
      val = @all_header_includes[form_file_key( filepath )] || []
    end
    return val
  end

  # Header includes .h (minus mocks & framework headers) in test file
  def lookup_header_includes_list(filepath)
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

  # Source C includes within test file
  def lookup_source_includes_list(filepath)
    val = nil
    @lock.synchronize do
      val = @source_includes[form_file_key( filepath )] || []
    end
    return val
  end

  # Source extras via TEST_SOURCE_FILE() within test file
  def lookup_build_directive_sources_list(filepath)
    val = nil
    @lock.synchronize do
      val = @source_extras[form_file_key( filepath )] || []
    end
    return val
  end

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

  # Mocks within test file with no file extension
  def lookup_raw_mock_list(filepath)
    val = nil
    @lock.synchronize do
      val = @mocks[form_file_key( filepath )] || []
    end
    return val
  end

  def lookup_all_include_paths
    val = nil
    @lock.synchronize do
      val = @all_include_paths.uniq
    end
    return val
  end

  def inspect_include_paths
    @lock.synchronize do
      @include_paths.each { |test, paths| yield test, paths }
    end
  end

  # Unlike other ingest() calls, ingest_includes() can be called externally.
  def ingest_includes(filepath, includes)
    mock_prefix = @configurator.cmock_mock_prefix
    file_key    = form_file_key( filepath )
    
    mocks       = []
    all_headers = []
    headers     = []
    sources     = []

    includes.each do |include|
      # <*.h>
      if include =~ /#{Regexp.escape(@configurator.extension_header)}$/
        # Check if include is a mock with regex match that extracts only mock name (no .h)
        scan_results = include.scan(/([^\s]*\b#{mock_prefix}.+)#{Regexp.escape(@configurator.extension_header)}/)
        
        if (scan_results.size > 0)
          # Collect mock name
          mocks << scan_results[0][0]
        else
          # If not a mock or framework file, collect tailored header filename
          headers << include unless VENDORS_FILES.include?( include.ext('') )
        end

        # Add to .h includes list
        all_headers << include
      # <*.c>
      elsif include =~ /#{Regexp.escape(@configurator.extension_source)}$/
        # Add to .c includes list
        sources << include
      end
    end

    @lock.synchronize do
      @mocks[file_key] = mocks
      @all_header_includes[file_key] = all_headers
      @header_includes[file_key] = headers
      @source_includes[file_key] = sources
    end
  end

  private #################################

  def collect_build_directive_source_files(filepath, files)
    ingest_build_directive_source_files( filepath, files.uniq )

    debug_log_list(
      "Extra source files found via TEST_SOURCE_FILE()",
      filepath,
      files
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

  def collect_includes(filepath, includes)
    ingest_includes( filepath, includes.uniq )
    debug_log_list( "#includes found", filepath, includes )
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

    debug_log_list( "Test cases found ", filepath, test_cases )
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

    # Look for #include statements
    results = line.match(/#\s*include\s+\"\s*((\w|\.)+)\s*\"/)
    includes << results[1] if !results.nil?

    return includes
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

  ##
  ## Utility methods
  ##

  def form_file_key( filepath )
    return filepath.to_s.to_sym
  end

  def debug_log_list(message, filepath, list)
    msg = "#{message} in #{filepath}:"
    if list.empty?
      msg += " <none>"
    else
      msg += "\n"
      list.each do |item|
        msg += " - #{item}\n"
      end
    end

    @loginator.log( msg, Verbosity::DEBUG )
    @loginator.log( '', Verbosity::DEBUG )
  end

end
