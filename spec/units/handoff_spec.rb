# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'rbconfig'
require 'ceedling/handoff'

describe Handoff do
  def installation_with_version(root, version)
    FileUtils.mkdir_p( File.join( root, 'lib' ) )
    File.write( File.join( root, 'lib', 'version.rb' ), "module Ceedling; module Version; TAG = '#{version}'; end; end\n" )
    return Installation.new( root )
  end

  describe '.take_markers' do
    it 'removes both markers from the environment and returns them' do
      env = {'CEEDLING_HANDOFF_LAUNCHER' => '/gem', 'CEEDLING_HANDOFF_TARGET' => '/app', 'OTHER' => 'x'}

      expect(described_class.take_markers( env )).to eq( {launcher: '/gem', target: '/app'} )
      expect(env).to eq( {'OTHER' => 'x'} )
    end

    it 'returns nil when this process was not handed off' do
      expect(described_class.take_markers( {} )).to be_nil
    end
  end

  describe '.received?' do
    it 'is true when the markers name this installation as the target' do
      Dir.mktmpdir do |root|
        expect(described_class.received?( {launcher: '/gem', target: root + '/'}, own: Installation.new( root ) )).to be( true )
      end
    end

    # GH #1365: markers an older target leaks to a nested launcher name someone else
    it 'is false when the markers name another installation' do
      Dir.mktmpdir do |root|
        expect(described_class.received?( {launcher: '/gem', target: '/elsewhere'}, own: Installation.new( root ) )).to be( false )
      end
    end

    it 'is false without markers' do
      expect(described_class.received?( nil, own: Installation.new( '/gem' ) )).to be( false )
    end
  end

  describe 'messages' do
    it 'names both installations and their versions when handing off' do
      Dir.mktmpdir do |dir|
        launcher = installation_with_version( File.join( dir, 'gem' ), '1.2.2' )
        target   = installation_with_version( File.join( dir, 'app' ), '1.2.0' )

        expect(described_class.handing_off_message( launcher: launcher, target: target )).to eq(
          "Ceedling launcher 1.2.2 at #{launcher.root}/ is handing off to Ceedling 1.2.0 at #{target.root}/, which runs in its own process."
        )
      end
    end

    it 'names the launcher a handed-off process came from' do
      Dir.mktmpdir do |dir|
        own = installation_with_version( File.join( dir, 'app' ), '1.2.2' )
        launcher = installation_with_version( File.join( dir, 'gem' ), '1.2.3' )

        expect(described_class.received_message( {launcher: launcher.root, target: own.root}, own: own )).to eq(
          "Ceedling 1.2.2 at #{own.root}/ is now running, launched from Ceedling 1.2.3 at #{launcher.root}/."
        )
      end
    end
  end

  describe '.exec' do
    before(:each) do
      @loginator = double('loginator')
      allow(@loginator).to receive(:wrapup)
      allow(described_class).to receive(:replace_process)
    end

    it 'replaces this process with the target\'s own launcher, given the original command line and both markers' do
      launcher = Installation.new( '/gem' )
      target   = Installation.new( '/app' )

      described_class.exec( target: target, launcher: launcher, argv: ['test:all', '--mixin', '=:a: b c'], loginator: @loginator )

      expect(described_class).to have_received(:replace_process).with(
        {'CEEDLING_HANDOFF_LAUNCHER' => launcher.root, 'CEEDLING_HANDOFF_TARGET' => target.root},
        RbConfig.ruby, target.bin_path, 'test:all', '--mixin', '=:a: b c'
      )
    end

    it 'drains logging and flushes the standard streams before the process is replaced' do
      expect(@loginator).to receive(:wrapup).ordered
      expect($stdout).to receive(:flush).ordered
      expect($stderr).to receive(:flush).ordered
      expect(described_class).to receive(:replace_process).ordered

      described_class.exec( target: Installation.new( '/app' ), launcher: Installation.new( '/gem' ), argv: [], loginator: @loginator )
    end
  end
end
