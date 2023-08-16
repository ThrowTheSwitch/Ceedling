
class TestContextExtractor

  constructor :configurator, :yaml_wrapper, :file_wrapper

  def setup
    @header_includes = {}
    @source_includes = {}
    @source_extras   = {}
    @mocks           = {}
    @include_paths   = {}

    @lock = Mutex.new
  end


  # open, scan for, and sort & store all test includes, mocks, build directives, etc
  def parse_test_file(filepath)
    test_context_extraction( filepath, @file_wrapper.read(filepath) )
  end

  # for includes_list file, slurp up array from yaml file and sort & store header_includes
  def parse_includes_list(filepath)
    ingest_includes_and_mocks( includes_list, @yaml_wrapper.load(filepath) )
  end

  # header header_includes of test file with file extension
  def lookup_header_includes_list(test)
    return @header_includes[form_file_key(test)] || []
  end

  # include paths of test file specified with TEST_INCLUDE_PATH()
  def lookup_include_paths_list(test)
    return @include_paths[form_file_key(test)] || []
  end

  # source header_includes within test file
  def lookup_source_includes_list(test)
    return @source_includes[form_file_key(test)] || []
  end

  # source extras via TEST_SOURCE_FILE() within test file
  def lookup_source_extras_list(test)
    return @source_extras[form_file_key(test)] || []
  end

  # mocks within test file with no file extension
  def lookup_raw_mock_list(test)
    return @mocks[form_file_key(test)] || []
  end

  private #################################

  def test_context_extraction(filepath, contents)
    header_includes = []
    include_paths = []
    source_includes = []
    source_extras = []

    source_extension = @configurator.extension_source
    header_extension = @configurator.extension_header

    # Remove line comments
    contents = contents.gsub(/\/\/.*$/, '')
    # Remove block comments
    contents = contents.gsub(/\/\*.*?\*\//m, '')

    contents.split("\n").each do |line|
      # Look for #include statement for .h files
      scan_results = line.scan(/#\s*include\s+\"\s*(.+#{'\\'+header_extension})\s*\"/)
      header_includes << scan_results[0][0] if (scan_results.size > 0)

      # Look for TEST_INCLUDE_PATH() statement
      scan_results = line.scan(/#{UNITY_TEST_INCLUDE_PATH}\(\s*\"\s*(.+)\s*\"\s*\)/)
      include_paths << scan_results[0][0] if (scan_results.size > 0)

      # Look for TEST_SOURCE_FILE() statement
      scan_results = line.scan(/#{UNITY_TEST_SOURCE_FILE}\(\s*\"\s*(.+\.\w+)\s*\"\s*\)/)
      source_extras << scan_results[0][0] if (scan_results.size > 0)

      # Look for #include statement for .c files
      scan_results = line.scan(/#\s*include\s+\"\s*(.+#{'\\'+source_extension})\s*\"/)
      source_includes << scan_results[0][0] if (scan_results.size > 0)
    end

    ingest_includes_and_mocks( filepath, header_includes.uniq )
    ingest_include_paths( filepath, include_paths.uniq )
    ingest_source_extras( filepath, source_extras.uniq )
    ingest_source_includes( filepath, source_includes.uniq )
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
