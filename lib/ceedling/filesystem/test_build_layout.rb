# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/filesystem/build_subpath'
require 'ceedling/filesystem/project_paths'

# Where each test's own build files go. Each kind of file has a base directory every test
# shares, and a test's root of that kind is the base, the test's name, and the reserved
# segment `_t_` (BuildSubpath::OWN_SEGMENT). A name is a path, so a test's root sits beside
# the directories of other tests' names rather than among them. No name holds the segment,
# since BuildSubpath escapes a directory named like it, so no test's root lies inside
# another's. Below a base, the first such segment therefore ends a test's name exactly.
#
# Runners, results, logs and artifacts are files named by a test's basename below the
# directories of its name. Those can't collide, so they stay outside this layout.
class TestBuildLayout

  # A path's place in the layout: the kind of its base, its test's name, and its path below
  # that test's root
  Location = Struct.new( :kind, :name, :subpath, keyword_init: true )

  # Each kind with a configured base, and the setting that enables it, if any
  CONFIGURED = {
    mocks:               [:cmock_mock_path,                               :project_use_mocks],
    partials:            [:project_test_partials_path,                    :project_use_partials],
    preprocess_includes: [:project_test_preprocess_includes_path,         nil],
    preprocess_files:    [:project_test_preprocess_files_path,            nil],
    build_directives:    [:project_test_preprocess_build_directives_path, nil]
  }.freeze

  # Each kind whose base belongs to a build context, and its directory there
  CONTEXTUAL = { out: BUILD_OUT_DIR, dependencies: BUILD_DEPENDENCIES_DIR }.freeze

  KINDS = (CONFIGURED.keys + CONTEXTUAL.keys).freeze

  constructor :configurator, :file_wrapper

  # The directory every test's files of `kind` share, or nil for a disabled feature. The
  # output and dependencies bases sit below a build context, such as `build/gcov/out`.
  def base(kind, context: nil)
    dir = CONTEXTUAL[kind]
    return File.join( *[@configurator.project_build_root, context&.to_s, dir].compact ) unless dir.nil?

    setting, feature = CONFIGURED.fetch( kind )
    return nil unless feature.nil? or @configurator.public_send( feature )

    return @configurator.public_send( setting )
  end

  # A test's own directory of `kind`, or nil for an empty name or a disabled feature. The
  # root's length is checked here, since every file of the test's own lies below it.
  def root(kind, name, context: nil)
    return nil if name.to_s.empty?

    base = base( kind, context: context )
    return nil if base.nil?

    path = File.join( base, name.to_s, BuildSubpath::OWN_SEGMENT )
    @file_wrapper.check_path_length( path, origin: 'TestBuildLayout#root' )
    return path
  end

  # A file at `subpath` below a test's root of `kind`, or nil where the test has no root
  def file(kind, name, subpath, context: nil)
    root = root( kind, name, context: context )
    return root if root.nil? or subpath.to_s.empty?

    return File.join( root, subpath )
  end

  # The roots of a test's generated Partials and mocks, as far as each feature is enabled.
  # A mock or a Partial mirrors its own subdirectory below one of these.
  def generated_roots(name)
    return [root( :partials, name ), root( :mocks, name )].compact
  end

  # Where `path` lies in the layout, or nil for a path below no test's root. The most
  # specific base holding the path counts, should one base be configured inside another.
  def locate(path, context: nil)
    held( path, context ).each do |kind, segments|
      index = segments.index( BuildSubpath::OWN_SEGMENT )
      next if index.nil? or index.zero?

      return Location.new( kind: kind, name: segments.take( index ).join( '/' ), subpath: segments.drop( index + 1 ).join( '/' ) )
    end

    return nil
  end

  # The path below a test's root of `kind` that `path` lies at, '' for the root itself, or
  # nil for a path outside it
  def subpath(path, kind:, name:, context: nil)
    root = root( kind, name, context: context )
    return nil if root.nil?

    return ProjectPaths.subdir_below( root, path )
  end

  private

  # Each kind whose base holds `path`, with the segments of the path below that base, the
  # most specific base first
  def held(path, context)
    found = KINDS.filter_map do |kind|
      base = base( kind, context: context )
      rest = base.nil? ? nil : ProjectPaths.subdir_below( base, path )
      rest.nil? ? nil : [kind, rest.split( '/' )]
    end

    return found.sort_by { |_, segments| segments.length }
  end

end
