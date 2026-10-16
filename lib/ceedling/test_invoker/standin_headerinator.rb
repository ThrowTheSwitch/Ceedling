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
class StandinHeaderinator

  include TestPipelineHelpers

  constructor :configurator, :loginator, :reportinator, :file_wrapper, :file_path_utils, :mock_locator

  # Places a stand-in for each mock and Partial among `includes`, and gives the mirrored
  # directories of the ordinary mocks, the mock search paths these includes call for.
  #
  # A path already holding a file, whether a real mock or Partial from an earlier run or
  # an earlier stand-in, is left alone. Mock generation tracks the file at a mock's path
  # as an input, so rewriting it would invalidate the mock for nothing.
  def place(testable, includes)
    mock_dirs = place_mocks( testable, Includes.filter( includes, /^#{@configurator.cmock_mock_prefix}/ ) )
    place_partials( testable, Includes.filter( includes, /^#{PARTIAL_FILENAME_PREFIX}/ ) )

    return mock_dirs.uniq
  end

  private

  # A Partial mock is Ceedling's own generated content with no real header, so its
  # stand-in follows its own #include's path. An ordinary mock's stand-in mirrors its
  # real header's directory, as the real mock will.
  def place_mocks(testable, mocks)
    collection = @mock_locator.header_collection( testable.search_paths, testable.mock_search_paths )

    return mocks.filter_map do |include|
      if mock_partial?( include )
        write( testable.name, @file_path_utils.form_mock_header_filepath( testable.name, include.filepath ), include )
        next
      end

      _source, subdir = @mock_locator.locate( include, collection: collection )
      mock_dir = subdir.empty? ? testable.name : File.join( testable.name, subdir )
      write( testable.name, @file_path_utils.form_mock_header_filepath( mock_dir, include.filename ), include )

      @file_path_utils.form_mock_output_path( testable.paths[:mocks], subdir ) if testable.paths[:mocks]
    end
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

    msg = @reportinator.generate_module_progress(
      operation:   'Generating stand-in header for',
      module_name: test,
      filename:    include.filename
    )
    @loginator.log( msg, Verbosity::DEBUG )
    @file_wrapper.mkdir( File.dirname( filepath ) )
    @file_wrapper.write_blank_file( filepath )
  end

end
