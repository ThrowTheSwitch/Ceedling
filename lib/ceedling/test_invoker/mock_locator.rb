# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/test_invoker/test_pipeline_helpers'

# Where a test's mocks come from and where they go. A mock's real header resolves
# against the test's search paths, and the mock is written to a directory below the
# test's mock root mirroring that header's location. Stand-ins, mock search paths, and
# the real mock must all agree on that directory, so every stage locates mocks here.
class MockLocator

  include TestPipelineHelpers

  constructor :configurator, :include_pathinator, :file_finder, :file_path_utils

  # The headers a test's mocks resolve against: those on its search paths, in search
  # order, without its own mock directories, which hold mocks rather than real headers
  def header_collection(search_paths, mock_search_paths = [])
    return @include_pathinator.ordered_header_files( search_paths - mock_search_paths )
  end

  # A mock's real header and the subdirectory mirroring its location. `complain` sets
  # what a missing header does: :error raises, and :ignore gives [nil, nil].
  def locate(include, collection:, complain: :error)
    return @file_finder.resolve_mock( include.filepath, collection: collection, complain: complain )
  end

  # Each mock's mirrored directory below `mocks_root`, once each. A Partial mock has no
  # real header and lives in the root itself, and a mock whose missing header the caller
  # tolerates has no directory.
  def directories(includes, mocks_root:, collection:, complain: :error)
    dirs = includes.filter_map do |include|
      next if mock_partial?( include )

      source, subdir = locate( include, collection: collection, complain: complain )
      next if source.nil?

      @file_path_utils.form_mock_output_path( mocks_root, subdir )
    end

    return dirs.uniq
  end

end
