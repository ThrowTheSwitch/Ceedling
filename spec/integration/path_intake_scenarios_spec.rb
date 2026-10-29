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

  # Clobber empties the build root's test and release trees, so a build root holding the
  # whole project is refused. An empty build root is left to the unit specs: it names the
  # filesystem root, where a configuration that got past it would create directories.
  { '.' => 'the project directory', '..' => 'a directory above the project' }.each do |root, what|
    it "G16: refuses a build root that is #{what}" do
      in_temp_project( minimal_project_files ) do
        expect { configure( yaml( project: { build_root: root } ) ) }.to raise_error( CeedlingException )
        expect(logged.join( "\n" )).to match( /build_root.*'#{Regexp.escape( root )}'/ )
      end
    end
  end

  it 'G16: accepts a build root beside the project\'s own directories' do
    in_temp_project( minimal_project_files ) do
      expect { configure( yaml( project: { build_root: 'out/build' } ) ) }.to_not raise_error
    end
  end

  it 'G16: accepts a build root holding sources, warning of the entry' do
    in_temp_project( minimal_project_files ) do
      expect { configure( yaml( project: { build_root: 'src' } ) ) }.to_not raise_error
      expect(logged.join( "\n" )).to match( %r{:paths ↳ :source => 'src/\*\*' lies in the build root 'src'} )
    end
  end

  # A `-:` entry names what a build leaves out, and nothing there to leave out is no error.
  # Below the build root, where nothing exists before a first build, it is not worth a word.
  it 'G24: accepts a `-:` path below the build root that names nothing, silently' do
    in_temp_project( minimal_project_files ) do
      configure( yaml( paths: { include: ['src/**', '-:build/gen'] } ) )

      expect(logged.join( "\n" )).to_not match( %r{build/gen} )
    end
  end

  it 'G24: accepts a `-:` path elsewhere that names nothing, warning of it' do
    in_temp_project( minimal_project_files ) do
      configure( yaml( paths: { include: ['src/**', '-:src/gone'] } ) )

      expect(logged.join( "\n" )).to match( %r{'-:src/gone' leaves out nothing} )
    end
  end

  it "G18: includes a Unity helper written with backslashes in every mock by its own filename" do
    files = minimal_project_files.merge( 'test/support/helper.h' => "\n" )
    in_temp_project( files ) do
      config = configure( yaml( extra: ":cmock:\n  :unity_helper_path: 'test\\support\\helper.h'\n" ) )[:configurator]

      expect(config.cmock_includes).to include( 'helper.h' )
    end
  end

  # Assumes an absolute release output names the release itself
  it 'G19: places a release named by an absolute :output where it names' do
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
