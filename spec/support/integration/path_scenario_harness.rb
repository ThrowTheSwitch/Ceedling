# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Runs a project layout through configuration, collection, build-path mapping, and the
# lookups that invert that mapping, without compiling anything.
#
# A scenario is a workspace: the project in `app/`, with siblings beside it (`shared/`,
# `vendor/`) for paths that reach outside the project, and a separate directory elsewhere
# for paths far outside it, as a vendor SDK installed at a drive's root is. YAML may name
# absolute paths with `%{ws}`, `%{app}` and `%{far}`. The workspace is resolved through File.realpath first, so a
# system temp directory behind a symlink (macOS's /tmp) doesn't add a second spelling.
#
# Test preprocessing is off, so no preprocessor is probed, and nothing is built.

require 'tmpdir'
require 'fileutils'
require 'configurator_integration_helper'
require 'ceedling/file_path_utils'
require 'ceedling/file_finder'
require 'ceedling/file_finder_helper'
require 'ceedling/test_invoker/test_build_setup'
require 'ceedling/test_invoker/test_invoker_types'

module PathScenarioHarness
  include ConfiguratorIntegrationHelpers

  # Runs each test of a batch in turn, in place of the thread pool
  class SerialBatchinator
    def exec(things:, **_options)
      things.each { |thing| yield thing }
    end
  end

  # A root spelled each way a project file might, for one place in the workspace
  ROOT_SPELLINGS = {
    plain:     ->(root, **) { root },
    dot_slash: ->(root, **) { "./#{root}" },
    absolute:  ->(root, app:, **) { File.join( app, root ) },
    backslash: ->(root, **) { root.tr( '/', '\\' ) },
    symlink:   ->(root, ws:, **) { File.join( ws, 'link', root ) }
  }.freeze

  # Runs the block in a workspace holding `files` (paths relative to the workspace), from
  # `cwd` within it, with `far` files in a directory outside the workspace. A `link`
  # symlink to `app/` is made when `symlink` is set.
  def in_workspace(files, cwd: 'app', symlink: false, far: {})
    Dir.mktmpdir do |dir|
      Dir.mktmpdir do |far_dir|
        ws = File.realpath( dir )
        @far = File.join( File.realpath( far_dir ), 'deep', 'sdk' )
        write_files( ws, files )
        write_files( @far, far )
        FileUtils.mkdir_p( File.join( ws, 'app' ) )
        File.symlink( File.join( ws, 'app' ), File.join( ws, 'link' ) ) if symlink

        Dir.chdir( File.join( ws, cwd ) ) { yield ws, File.join( ws, 'app' ) }
      end
    end
  end

  def write_files(root, files)
    files.each do |path, content|
      FileUtils.mkdir_p( File.join( root, File.dirname( path ) ) )
      File.write( File.join( root, path ), content )
    end
  end

  # A project file for a scenario. `paths` and `files` are the :paths and :files sections.
  def scenario_yaml(ws:, app:, paths:, files: {}, project: {})
    config = {
      project: { build_root: 'build', use_test_preprocessor: :none, use_mocks: true, release_build: true }.merge( project ),
      paths:   paths,
      files:   files
    }
    # Psych writes Symbol keys and values in the `:key:` form a project file uses
    return YAML.dump( placed( config, ws: ws, app: app ) )
  end

  # Fills `%{ws}`, `%{app}` and `%{far}` in every string with the workspace's absolute paths
  def placed(value, ws:, app:)
    case value
    when Hash   then value.transform_values { |item| placed( item, ws: ws, app: app ) }
    when Array  then value.map { |item| placed( item, ws: ws, app: app ) }
    when String then value.gsub( '%{ws}', ws ).gsub( '%{app}', app ).gsub( '%{far}', @far.to_s )
    else value
    end
  end

  # Configures the project, and prepares every test's build paths, as stage 1 of a build does
  def scenario(yaml)
    configurator = configure( yaml )[:configurator]

    file_wrapper    = FileWrapper.new( loginator: double( 'loginator', log: nil ), verbosinator: double( 'verbosinator', should_output?: false ) )
    file_path_utils = FilePathUtils.new( configurator: configurator, file_wrapper: file_wrapper )

    collaborators = TestBuildSetup.constructor_keys.to_h { |key| [key, double( key.to_s )] }
    setup = TestBuildSetup.new( collaborators.merge(
      configurator: configurator, file_wrapper: file_wrapper, file_path_utils: file_path_utils, batchinator: SerialBatchinator.new
    ) )
    state = TestInvokerTypes::PipelineState.new( tests: configurator.collection_all_tests, testables: {}, context: :test, options: [], lock: Mutex.new )
    setup.stage_prepare_build_paths( state )

    finder = FileFinder.new(
      configurator: configurator, file_finder_helper: FileFinderHelper.new( loginator: double( 'loginator', log: nil ) ),
      file_path_utils: file_path_utils, file_wrapper: file_wrapper, yaml_wrapper: nil
    )

    return { configurator: configurator, state: state, paths: file_path_utils, finder: finder }
  end

  # Every build file a scenario's sources and headers map to, by kind
  def placements(scene)
    configurator, state, paths = scene.values_at( :configurator, :state, :paths )
    testable = state.testables.values.first
    sources  = configurator.collection_all_source

    return {
      test_objects:    paths.form_test_build_objects_filelist( testable.paths[:build], sources ),
      release_objects: paths.form_release_build_objects_filelist( sources ),
      preprocessed:    configurator.collection_all_headers.map { |header| paths.form_preprocessed_file_filepath( header, testable.name ) },
      mocks:           configurator.collection_all_headers.map { |header| mock_output_path( scene, testable, header ) }
    }
  end

  # Where a mock of `header` is generated, through the lookup a build's mock stage makes
  def mock_output_path(scene, testable, header)
    mock = "#{scene[:configurator].cmock_mock_prefix}#{File.basename( header )}"
    _source, subdir = scene[:finder].resolve_mock( mock, complain: :ignore )
    return nil if subdir.nil?

    return scene[:paths].form_mock_output_path( testable.paths[:mocks], subdir )
  end

  # Every path lies within the build root, by real containment
  def expect_inside_build(paths, build: File.expand_path( 'build' ))
    paths.compact.each do |path|
      expanded = File.expand_path( path )
      expect(expanded).to start_with( build + '/' ), "#{path} lies outside #{build}/"
      expect(path.split( %r{[\\/]} )).to_not include( '..' ), "#{path} holds `..`"
    end
  end

  # Distinct inputs map to distinct build files
  def expect_distinct(paths, label)
    duplicates = paths.compact.group_by { |path| File.expand_path( path ) }.select { |_, group| group.size > 1 }.keys
    expect(duplicates).to be_empty, "#{label} collide: #{duplicates.join( ', ' )}"
  end

  # No collection holds a file under the build root
  def expect_collections_outside_build(configurator, build: File.expand_path( 'build' ))
    entries = configurator.collection_all_source + configurator.collection_all_headers + configurator.collection_all_tests
    inside  = entries.select { |entry| File.expand_path( entry ).start_with?( build + '/' ) }
    expect(inside).to be_empty, "collected from the build root: #{inside.join( ', ' )}"
  end

  # No file is collected twice, under two spellings
  def expect_one_spelling_each(configurator)
    entries = configurator.collection_all_source + configurator.collection_all_headers
    twice = entries.group_by { |entry| File.realpath( entry ) rescue File.expand_path( entry ) }.select { |_, group| group.size > 1 }
    expect(twice).to be_empty, "collected twice: #{twice.values.map { |group| group.join( ' and ' ) }.join( '; ' )}"
  end

  # Build placements relative to the build root, comparable across spellings
  def relative_placements(scene, build: File.expand_path( 'build' ))
    return placements( scene ).transform_values do |paths|
      paths.compact.map { |path| File.expand_path( path ).delete_prefix( build + '/' ) }.sort
    end
  end
end
