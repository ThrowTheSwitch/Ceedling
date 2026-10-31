# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/filesystem/working_dir'
require 'ceedling/filesystem/project_paths'

describe WorkingDir do
  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @ws = File.realpath( dir )
      FileUtils.mkdir_p( File.join( @ws, 'app/dep' ) )
      Dir.chdir( File.join( @ws, 'app' ) ) { example.run }
    end
  end

  describe '.path' do
    it 'reads the working directory once, however often it is asked' do
      WorkingDir.path
      expect(Dir).not_to receive(:pwd)

      3.times { expect(WorkingDir.path).to eq( File.join( @ws, 'app' ) ) }
    end

    it 'keeps answering for the directory Ceedling started in across a plain Dir.chdir' do
      WorkingDir.path

      answer = WorkingDirTracking.untracked { Dir.chdir( 'dep' ) { WorkingDir.path } }
      expect(answer).to eq( File.join( @ws, 'app' ) )
    end

    # The spec suite's own Dir.chdir hook, which every in-process spec relies on
    it 'answers for a directory a spec changes to' do
      WorkingDir.path

      expect(Dir.chdir( 'dep' ) { WorkingDir.path }).to eq( File.join( @ws, 'app/dep' ) )
      expect(WorkingDir.path).to eq( File.join( @ws, 'app' ) )
    end
  end

  # Untracked, so the spec suite's Dir.chdir hook can't do WorkingDir.chdir's work for it
  describe '.chdir' do
    around(:each) { |example| WorkingDirTracking.untracked { example.run } }

    before(:each) do
      WorkingDir.path
    end

    it 'answers for the directory it changes to, then for the one it left' do
      inside = WorkingDir.chdir( 'dep' ) { [WorkingDir.path, ProjectPaths.canonical( File.join( @ws, 'app/dep/x' ) )] }

      expect(inside).to eq( [File.join( @ws, 'app/dep' ), 'x'] )
      expect(WorkingDir.path).to eq( File.join( @ws, 'app' ) )
      expect(ProjectPaths.canonical( File.join( @ws, 'app/dep/x' ) )).to eq( 'dep/x' )
    end

    it 'answers for the directory it left after a block that raises' do
      inside = nil
      expect { WorkingDir.chdir( 'dep' ) { inside = WorkingDir.path; raise 'failed' } }.to raise_error( 'failed' )

      expect(inside).to eq( File.join( @ws, 'app/dep' ) )
      expect(WorkingDir.path).to eq( File.join( @ws, 'app' ) )
    end
  end
end
