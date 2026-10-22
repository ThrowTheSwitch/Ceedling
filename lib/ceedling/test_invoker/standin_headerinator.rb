# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes/includes'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Stand-in headers: files placed where a test's mocks and Partials will be generated, so
# the preprocessor finds something at each of their #includes before stage 8 or stage 10
# writes the real file. A stand-in sits exactly where the real file will. A test build
# that never reaches those stages, such as a :sources_only run, keeps only the stand-in,
# which is all it needs.
#
# A mock's stand-in includes the mock's real header, as the generated mock will, so a
# macro that header defines is visible through the stand-in. A Partial's is blank.
class StandinHeaderinator

  include TestPipelineHelpers

  # The first line of every stand-in, which tells one apart from a real mock
  MARKER = '// Ceedling stand-in header'

  # The first line of the blank stand-ins earlier versions wrote (FileWrapper#write_blank_file)
  BLANK_MARKER = '// Ceedling intentionally blank file'

  MARKER_READ_LENGTH = 64

  constructor :configurator, :loginator, :reportinator, :file_wrapper, :file_path_utils, :mock_locator

  # Places a stand-in for each mock and Partial among `includes`, and gives the mirrored
  # directories of the ordinary mocks, the mock search paths these includes call for.
  #
  # A real mock or Partial from an earlier run is left alone, as is a mock's stand-in that
  # is already current. Mock generation tracks the file at a mock's path as an input, so
  # rewriting it would invalidate the mock for nothing. A mock's stand-in that is out of
  # date, such as a blank one from an earlier version, is rewritten.
  #
  # `complain` sets what a mock without a real header does: :error raises, and :ignore
  # places nothing for it.
  def place(testable, includes, complain: :error)
    mocks     = Includes.filter( includes, /^#{@configurator.cmock_mock_prefix}/ )
    mock_dirs = place_mocks( testable, mocks, complain )
    place_partials( testable, Includes.filter( includes, /^#{PARTIAL_FILENAME_PREFIX}/ ) )

    return mock_dirs.uniq
  end

  private

  # A Partial mock is Ceedling's own generated content with no real header, so its
  # stand-in follows its own #include's path. An ordinary mock's stand-in mirrors its
  # real header's directory, as the real mock will.
  def place_mocks(testable, mocks, complain)
    collection = @mock_locator.header_collection( testable.search_paths, testable.mock_search_paths )

    return mocks.filter_map do |include|
      if mock_partial?( include )
        write( testable.name, @file_path_utils.form_mock_header_filepath( testable.name, include.filepath ), include )
        next
      end

      place_mock( testable, include, collection, complain )
    end
  end

  # Gives the mock's mirrored directory, or nil when its missing header is tolerated or
  # the test has no mock root
  def place_mock(testable, include, collection, complain)
    source, subdir = @mock_locator.locate( include, collection: collection, complain: complain )
    return nil if source.nil?

    mock_dir = subdir.empty? ? testable.name : File.join( testable.name, subdir )
    write_mock( testable.name, @file_path_utils.form_mock_header_filepath( mock_dir, include.filename ), include, source )

    return nil if testable.paths[:mocks].nil?

    return @file_path_utils.form_mock_output_path( testable.paths[:mocks], subdir )
  end

  # A Partial's generated #include names whatever directory its module was named by, and
  # the stand-in sits where that #include points
  def place_partials(testable, partials)
    partials.each do |include|
      write( testable.name, @file_path_utils.form_partial_header_filepath( testable.name, include.filepath ), include )
    end
  end

  def write(test, filepath, include)
    return if @file_wrapper.exist?( filepath )

    log_placement( test, include )
    @file_wrapper.mkdir( File.dirname( filepath ) )
    @file_wrapper.write_blank_file( filepath )
  end

  def write_mock(test, filepath, include, header)
    contents = "#{MARKER}\n#{header_include( header )}\n"
    return if current?( filepath, contents )

    log_placement( test, include )
    @file_wrapper.mkdir( File.dirname( filepath ) )
    @file_wrapper.write( filepath, contents )
  end

  # The line CMock opens a mock with: its :orig_header_include_fmt around the header's name.
  # Ceedling hands CMock no folder, so the name is the header's own.
  def header_include( header )
    format = @configurator.get_cmock_config[:orig_header_include_fmt] || '#include "%s"'
    return format.gsub( '%s', File.basename( header ) )
  end

  # A file that is not a stand-in, such as a real mock, counts as current. Only its first
  # line is read to tell, since a real mock can be large.
  def current?(filepath, contents)
    return false unless @file_wrapper.exist?( filepath )

    start = @file_wrapper.read( filepath, MARKER_READ_LENGTH ).to_s
    return true unless start.start_with?( MARKER, BLANK_MARKER )

    return @file_wrapper.read( filepath ) == contents
  end

  def log_placement(test, include)
    msg = @reportinator.generate_module_progress(
      operation:   'Generating stand-in header for',
      module_name: test,
      filename:    include.filename
    )
    @loginator.log( msg, Verbosity::DEBUG )
  end

end
