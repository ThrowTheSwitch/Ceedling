# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'generator_test_runner' # From lib/ not vendor/unity/auto

class TestContextExtractor

  constructor :configurator, :file_wrapper, :loginator

  def setup
    @header_includes     = {}
    @source_includes     = {}
    @source_extras       = {}
    @test_runner_details = {} # Test case lists & Unity runner generator instances
    @mocks               = {}
    @include_paths       = {}
    @all_include_paths   = []

    @lock = Mutex.new
  end

  def collect_simple_context( filepath, *args )
    args.each do |context|
      case context
      when :build_directive_macros
        collect_build_directives( filepath )

      when :includes
        collect_includes( filepath )

      when :test_runner_details
        collect_test_runner_details( filepath )

      else
        raise "Unrecognized test context :#{context}"
      end
    end

  end

  def collect_test_runner_details(test_filepath, input_filepath=nil)
    unity_test_runner_generator = GeneratorTestRunner.new(
      config: @configurator.get_runner_config,
      test_file_contents: @file_wrapper.read( test_filepath ),
      preprocessed_file_contents: input_filepath.nil? ? nil : @file_wrapper.read( input_filepath )
    )

    ingest_test_runner_details(
      filepath: test_filepath,
      test_runner_generator: unity_test_runner_generator
    )

    msg = "Test cases found in #{test_filepath}:"
    test_cases = unity_test_runner_generator.test_cases
    if test_cases.empty?
      msg += " <none>"
    else
      msg += "\n"
      test_cases.each do |test_case|
        msg += " - #{test_case[:line_number]}:#{test_case[:test]}()\n"
      end
    end

    @loginator.log( msg, Verbosity::DEBUG )
  end

  # Scan for all includes
  def scan_includes(filepath)
    return extract_includes( filepath, @file_wrapper.read( filepath ) )
  end

  # Header includes of test file with file extension
  def lookup_header_includes_list(filepath)
    return @header_includes[form_file_key( filepath )] || []
  end

  # Include paths of test file specified with TEST_INCLUDE_PATH()
  def lookup_include_paths_list(filepath)
    return @include_paths[form_file_key( filepath )] || []
  end

  # Source header_includes within test file
  def lookup_source_includes_list(filepath)
    return @source_includes[form_file_key( filepath )] || []
  end

  # Source extras via TEST_SOURCE_FILE() within test file
  def lookup_build_directive_sources_list(filepath)
    return @source_extras[form_file_key( filepath )] || []
  end

  def lookup_test_cases(filepath)
    return @test_runner_details[form_file_key( filepath )][:test_cases] || []
  end

  def lookup_test_runner_generator(filepath)
    return @test_runner_details[form_file_key( filepath )][:generator]
  end

  # Mocks within test file with no file extension
  def lookup_raw_mock_list(filepath)
    return @mocks[form_file_key( filepath )] || []
  end

  def lookup_all_include_paths
    return @all_include_paths.uniq
  end

  def inspect_include_paths
    @include_paths.each { |test, paths| yield test, paths }
  end

  def ingest_includes(filepath, includes)
    mock_prefix = @configurator.cmock_mock_prefix
    file_key    = form_file_key( filepath )
    
    mocks   = []
    headers = []
    sources = []

    includes.each do |include|
      # <*.h>
      if include =~ /#{Regexp.escape(@configurator.extension_header)}$/
        # Check if include is a mock with regex match that extracts only mock name (no .h)
        scan_results = include.scan(/(#{mock_prefix}.+)#{Regexp.escape(@configurator.extension_header)}/)
        mocks << scan_results[0][0] if (scan_results.size > 0)

        # Add to .h includes list
        headers << include
      # <*.c>
      elsif include =~ /#{Regexp.escape(@configurator.extension_source)}$/
        # Add to .c includes list
        sources << include
      end
    end

    @lock.synchronize do
      @mocks[file_key] = mocks
      @header_includes[file_key] = headers
      @source_includes[file_key] = sources
    end
  end

  private #################################

  # Scan for & store build directives
  #  - TEST_SOURCE_FILE()
  #  - TEST_INCLUDE_PATH()
  #
  # Note: This method is private unlike other `collect_ ()` methods. It is always
  #       called in the context collection process by way of `collect_context()`.
  def collect_build_directives(filepath)
    include_paths, source_extras = 
      extract_build_directives(
        filepath,
        @file_wrapper.read( filepath )
      )

    ingest_build_directives(
      filepath: filepath,
      include_paths: include_paths,
      source_extras: source_extras
    )
  end

  # Scan for & store includes (.h & .c) and mocks
  # Note: This method is private unlike other `collect_ ()` methods. It is only 
  #       called by way of `collect_context()`.
  def collect_includes(filepath)
    includes = extract_includes( filepath, @file_wrapper.read(filepath) )
    ingest_includes( filepath, includes )
  end

  def extract_build_directives(filepath, content)
    include_paths = []
    source_extras = []

    content = remove_comments(content)

    content.split("\n").each do |line|
      # Look for TEST_INCLUDE_PATH("<*>") statements
      results = line.scan(/#{UNITY_TEST_INCLUDE_PATH}\(\s*\"\s*(.+)\s*\"\s*\)/)
      include_paths << FilePathUtils.standardize( results[0][0] ) if (results.size > 0)

      # Look for TEST_SOURCE_FILE("<*>.<*>) statement
      results = line.scan(/#{UNITY_TEST_SOURCE_FILE}\(\s*\"\s*(.+\.\w+)\s*\"\s*\)/)
      source_extras << FilePathUtils.standardize( results[0][0] ) if (results.size > 0)
    end

    return include_paths.uniq, source_extras.uniq
  end

  def extract_includes(filepath, content)
    includes = []

    content = check_encoding(content)
    content = remove_comments(content)

    content.split("\n").each do |line|
      # Look for #include statements
      results = line.scan(/#\s*include\s+\"\s*(.+)\s*\"/)
      includes << results[0][0] if (results.size > 0)
    end

    return includes.uniq
  end

  def ingest_build_directives(filepath:, include_paths:, source_extras:)
    key = form_file_key( filepath )

    @lock.synchronize do
      @include_paths[key] = include_paths
    end

    @lock.synchronize do
      @source_extras[key] = source_extras
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

  # Note: This method modifies encoding in place (encode!) in an attempt to reduce long string copies
  def check_encoding(content)
    if not content.valid_encoding?
      content.encode!("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8')
    end
    return content
  end

  # Note: This method is destructive to argument content in an attempt to reduce memory usage
  def remove_comments(content)
    # Remove line comments
    content.gsub!(/\/\/.*$/, '')

    # Remove block comments
    content.gsub!(/\/\*.*?\*\//m, '')

    return content
  end

  def form_file_key( filepath )
    return filepath.to_s.to_sym
  end

end
