
class TestContextExtractor

  constructor :configurator, :file_wrapper

  def setup
    @header_includes   = {}
    @source_includes   = {}
    @source_extras     = {}
    @mocks             = {}
    @include_paths     = {}
    @all_include_paths = []

    @lock = Mutex.new
  end


  def collect_build_directives(filepath)
    extract_build_directives( filepath, @file_wrapper.read(filepath) )
  end

  # Scan for & store all test includes, mocks, build directives, etc
  def collect_testing_details(filepath)
    extract_test_details( filepath, @file_wrapper.read(filepath) )
  end

  # header header_includes of test file with file extension
  def lookup_header_includes_list(filepath)
    return @header_includes[form_file_key(filepath)] || []
  end

  # include paths of test file specified with TEST_INCLUDE_PATH()
  def lookup_include_paths_list(filepath)
    return @include_paths[form_file_key(filepath)] || []
  end

  # source header_includes within test file
  def lookup_source_includes_list(filepath)
    return @source_includes[form_file_key(filepath)] || []
  end

  # source extras via TEST_SOURCE_FILE() within test file
  def lookup_build_directive_sources_list(filepath)
    return @source_extras[form_file_key(filepath)] || []
  end

  # mocks within test file with no file extension
  def lookup_raw_mock_list(filepath)
    return @mocks[form_file_key(filepath)] || []
  end

  def lookup_all_include_paths
    return @all_include_paths.uniq
  end

  def inspect_include_paths
    @include_paths.each { |test, paths| yield test, paths }
  end

  def ingest_includes_and_mocks(filepath, includes)
    mock_prefix      = @configurator.cmock_mock_prefix
    header_extension = @configurator.extension_header
    file_key         = form_file_key(filepath)
    mocks            = []

    # Add header_includes to lookup hash
    includes.each do |include|
      # Check if include is a mock with regex match that extracts only mock name (no path or .h)
      scan_results = include.scan(/.*(#{mock_prefix}.+)#{'\\'+header_extension}/)
      # Add mock to lookup hash
      mocks << scan_results[0][0] if (scan_results.size > 0)
    end

    # finalize the information
    @lock.synchronize do
      @mocks[file_key] = mocks
      @header_includes[file_key] = includes
    end
  end

  private #################################

  def extract_build_directives(filepath, contents)
    include_paths = []
    source_extras = []

    # Remove line comments
    contents = contents.gsub(/\/\/.*$/, '')
    # Remove block comments
    contents = contents.gsub(/\/\*.*?\*\//m, '')

    contents.split("\n").each do |line|
      # Look for TEST_INCLUDE_PATH("<*>") statements
      results = line.scan(/#{UNITY_TEST_INCLUDE_PATH}\(\s*\"\s*(.+)\s*\"\s*\)/)
      include_paths << FilePathUtils.standardize( results[0][0] ) if (results.size > 0)

      # Look for TEST_SOURCE_FILE("<*>.<*>) statement
      results = line.scan(/#{UNITY_TEST_SOURCE_FILE}\(\s*\"\s*(.+\.\w+)\s*\"\s*\)/)
      source_extras << FilePathUtils.standardize( results[0][0] ) if (results.size > 0)
    end

    ingest_include_paths( filepath, include_paths.uniq )
    ingest_source_extras( filepath, source_extras.uniq )

    @lock.synchronize do
      @all_include_paths += include_paths
    end
  end

  def extract_test_details(filepath, contents)
    header_includes = []
    source_includes = []

    source_extension = @configurator.extension_source
    header_extension = @configurator.extension_header

    # Remove line comments
    contents = contents.gsub(/\/\/.*$/, '')
    # Remove block comments
    contents = contents.gsub(/\/\*.*?\*\//m, '')

    contents.split("\n").each do |line|
      # Look for #include statement for .h files
      results = line.scan(/#\s*include\s+\"\s*(.+#{'\\'+header_extension})\s*\"/)
      header_includes << results[0][0] if (results.size > 0)

      # Look for #include statement for .c files
      results = line.scan(/#\s*include\s+\"\s*(.+#{'\\'+source_extension})\s*\"/)
      source_includes << results[0][0] if (results.size > 0)
    end

    ingest_includes_and_mocks( filepath, header_includes.uniq )
    ingest_source_includes( filepath, source_includes.uniq )
  end

  def ingest_include_paths(filepath, paths)
    # finalize the information
    @lock.synchronize do
      @include_paths[form_file_key(filepath)] = paths
    end
  end

  def ingest_source_extras(filepath, sources)
    # finalize the information
    @lock.synchronize do
      @source_extras[form_file_key(filepath)] = sources
    end
  end

  def ingest_source_includes(filepath, includes)
    # finalize the information
    @lock.synchronize do
      @source_includes[form_file_key(filepath)] = includes
    end
  end

  def form_file_key(filepath)
    return filepath.to_s.to_sym
  end

end
