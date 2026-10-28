# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# How configuration takes in the paths a project file names, before any build: where each
# lands, and which a build can't use safely. Each example names the gap it probes (the path
# handling audit around GH #1370). Where the right behavior is a policy still to be chosen,
# the example states the one it assumes.

require 'spec_helper'
require 'configurator_integration_helper'

describe 'Path intake (integration)' do
  include ConfiguratorIntegrationHelpers

  def yaml(project: {}, paths: {}, extra: '')
    project_lines = { build_root: 'build' }.merge( project ).map { |key, value| "  :#{key}: #{value.inspect}" }.join( "\n" )
    path_lines = { test: ['test/**'], source: ['src/**'], include: ['src/**'] }.merge( paths ).map { |key, value| "  :#{key}: #{value.inspect}" }.join( "\n" )
    return ":project:\n#{project_lines}\n  :use_test_preprocessor: :none\n:paths:\n#{path_lines}\n#{extra}"
  end

  # Assumes a build root holding the project's own directories is refused, since clobber
  # empties the build root's test and release trees. An empty build root is left out
  # here: it names the filesystem root, where configuring would create directories.
  it 'G16: refuses a build root that is the project directory', pending: 'G16: the build root is never checked' do
    in_temp_project( minimal_project_files ) do
      expect { configure( yaml( project: { build_root: '.' } ) ) }.to raise_error( CeedlingException )
    end
  end

  it 'G18: includes a Unity helper written with backslashes in every mock by its own filename', pending: "G18: the helper filename is taken before paths are standardized" do
    files = minimal_project_files.merge( 'test/support/helper.h' => "\n" )
    in_temp_project( files ) do
      config = configure( yaml( extra: ":cmock:\n  :unity_helper_path: 'test\\support\\helper.h'\n" ) )[:configurator]

      expect(config.cmock_includes).to include( 'helper.h' )
    end
  end

  # Assumes an absolute release output names the release itself
  it 'G19: places a release named by an absolute :output where it names', pending: "G19: an absolute :output is joined below the release root" do
    in_temp_project( minimal_project_files ) do |dir|
      output = File.join( File.realpath( dir ), 'out', 'app.elf' )
      config = configure( yaml( project: { release_build: true }, extra: ":release_build:\n  :output: #{output}\n" ) )[:configurator]

      expect(config.project_release_build_target).to eq( output )
    end
  end

  # Assumes `~` means the home directory, as it does in a shell
  it 'G21: reads a `~` path as below the home directory' do
    in_temp_project( minimal_project_files.merge( 'home/inc/extra.h' => "\n" ) ) do |dir|
      home = ENV['HOME']
      begin
        ENV['HOME'] = File.join( File.realpath( dir ), 'home' )
        config = configure( yaml( paths: { include: ['src/**', '~/inc'] } ) )[:configurator]

        expect(config.collection_all_headers.map { |header| File.basename( header ) }).to include( 'extra.h' )
      ensure
        ENV['HOME'] = home
      end
    end
  end
end
