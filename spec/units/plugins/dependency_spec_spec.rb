# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/dependencies/lib', __dir__ ) )

require 'dependency_spec'

describe DependencySpec do

  def dependency(**overrides)
    return { name: 'Worker Bees', fetch: { method: :none }, artifacts: { static_libraries: ['libworker.a'] } }.merge( overrides )
  end

  def spec_for(**overrides)
    return DependencySpec.build_all( [dependency( **overrides )] ).first
  end

  describe 'naming' do
    it 'keeps the configured name and derives a task name of its word characters' do
      spec = spec_for

      expect(spec.name).to eq( 'Worker Bees' )
      expect(spec.task_name).to eq( 'WorkerBees' )
    end

    it 'refuses a dependency without a name' do
      expect { DependencySpec.build_all( [{ fetch: { method: :none } }] ) }.to raise_error( CeedlingException, /must have a :name/ )
    end

    it 'refuses a name with no letters or digits' do
      expect { spec_for( name: '-- --' ) }.to raise_error( CeedlingException, /`-- --`.*letters or digits/ )
    end

    it 'refuses two names that make the same task name' do
      deps = [dependency( name: 'Worker Bees' ), dependency( name: 'WorkerBees' )]

      expect { DependencySpec.build_all( deps ) }.to raise_error( CeedlingException, /`Worker Bees` and `WorkerBees`.*WorkerBees/ )
    end

    it 'returns frozen specs' do
      expect(spec_for).to be_frozen
    end
  end

  describe 'paths' do
    it 'places every path under dependencies/<task name> when none are configured' do
      spec = spec_for

      expect([spec.fetch_path, spec.source_path, spec.build_path, spec.artifact_path]).to all( eq( 'dependencies/WorkerBees' ) )
    end

    it 'falls back from source to fetch, and from fetch to source' do
      expect(spec_for( paths: { fetch: 'f' } ).source_path).to eq( 'f' )
      expect(spec_for( paths: { source: 's' } ).fetch_path).to eq( 's' )
    end

    it 'falls back from build to source, then fetch' do
      expect(spec_for( paths: { source: 's', fetch: 'f' } ).build_path).to eq( 's' )
      expect(spec_for( paths: { fetch: 'f' } ).build_path).to eq( 'f' )
    end

    it 'falls back from artifact to build' do
      expect(spec_for( paths: { build: 'b' } ).artifact_path).to eq( 'b' )
    end

    it 'deploys to the configured deploy path, or a default it is given' do
      expect(spec_for( paths: { deploy: 'bin' } ).deploy_path( 'build/release' )).to eq( 'bin' )
      expect(spec_for.deploy_path( 'build/release' )).to eq( 'build/release' )
    end

    # The deploy path holds deployed copies alongside the project's own files
    it 'never offers the deploy path as a working path' do
      expect(spec_for( paths: { fetch: 'f', deploy: 'bin' } ).working_paths).to eq( ['f'] )
    end

    it 'lists every configured path as a working path, or only the artifact path' do
      spec = spec_for( paths: { fetch: 'f', source: 'f', build: 'f/b', artifact: 'f/a' } )

      expect(spec.working_paths).to eq( ['f', 'f/b', 'f/a'] )
      expect(spec.working_paths( artifacts_only: true )).to eq( ['f/a'] )
    end

    it 'takes the artifact path, falling back to the build path, as the artifacts-only working path' do
      expect(spec_for( paths: { source: 's', build: 's/build' } ).working_paths( artifacts_only: true )).to eq( ['s/build'] )
    end

    # Cleaning a dependency that is not fetched removes only its artifacts, never its source
    it 'never offers the source path as an artifacts-only working path' do
      expect(spec_for( paths: { source: 's', build: 's' } ).working_paths( artifacts_only: true )).to eq( [] )
    end

    it 'uses the default path as its working path when none are configured' do
      expect(spec_for.working_paths).to eq( ['dependencies/WorkerBees'] )
    end

    # With no paths configured, the artifact path is the source path
    it 'offers no artifacts-only working path when none are configured' do
      expect(spec_for.working_paths( artifacts_only: true )).to eq( [] )
    end
  end

  describe 'artifacts' do
    let(:spec) do
      spec_for( paths: { artifact: 'out' },
                artifacts: { static_libraries: ['libw.a'], dynamic_libraries: ['libw.so'],
                             includes: ['inc/w.h', 'api'], source: ['src'] } )
    end

    it 'places each artifact under the artifact path' do
      expect(spec.static_libraries).to eq( ['out/libw.a'] )
      expect(spec.dynamic_libraries).to eq( ['out/libw.so'] )
      expect(spec.include_files).to eq( ['out/inc/w.h', 'out/api'] )
      expect(spec.source_paths).to eq( ['out/src'] )
      expect(spec_for( paths: { artifact: 'out' }, artifacts: { executables: ['bin/tool'] } ).executables).to eq( ['out/bin/tool'] )
    end

    it 'lists the directory of an included header and an included directory itself' do
      expect(spec.include_directories( ->( _glob ) { raise 'no glob here' } )).to eq( ['out/inc', 'out/api'] )
    end

    # The collector finds directories on disk, so it receives the glob under the artifact path
    it 'expands an include glob under the artifact path through the path collector' do
      spec = spec_for( paths: { artifact: 'out' }, artifacts: { includes: ['inc/**'] } )

      expect(spec.include_directories( ->( glob ) { ["#{glob}/a", "#{glob}/b"] } )).to eq( ['out/inc/**/a', 'out/inc/**/b'] )
    end

    it 'treats missing artifacts as empty' do
      spec = DependencySpec.build_all( [{ name: 'tool', fetch: { method: :none } }] ).first

      expect([spec.static_libraries, spec.dynamic_libraries, spec.executables, spec.include_files, spec.source_paths]).to all( be_empty )
    end
  end

  describe 'fetching and building' do
    it 'reads the fetch method, with no method meaning nothing to fetch' do
      expect(spec_for( fetch: { method: :git, source: 'url' } ).fetch_method).to eq( :git )
      expect(spec_for( fetch: nil ).fetch_method).to be_nil
    end

    it 'refuses an unknown fetch method' do
      expect { spec_for( fetch: { method: :ftp } ) }.to raise_error( CeedlingException, /Unknown fetch method `ftp`.*Worker Bees/ )
    end

    it 'refuses a fetch method that needs a source without one' do
      %i[zip tar_gzip git svn].each do |method|
        expect { spec_for( fetch: { method: method } ) }.to raise_error( CeedlingException, /:#{method}.*:source/ )
      end
    end

    it 'refuses a custom fetch without commands' do
      expect { spec_for( fetch: { method: :custom } ) }.to raise_error( CeedlingException, /:custom.*:executable/ )
    end

    it 'reads build steps, environment entries, defines, and flags, each defaulting empty' do
      spec = spec_for

      expect([spec.build_steps, spec.environment, spec.defines, spec.flags]).to all( be_empty )
      expect(spec_for( build: ['make', :build_lib] ).build_steps).to eq( ['make', :build_lib] )
    end
  end

end
