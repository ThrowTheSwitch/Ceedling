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
require 'ceedling/constants'
require 'app_cfg'

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

  # GH #1365: a launcher before 1.2.2 always loads the application into its own process
  describe '.complete_in_process' do
    before(:each) do
      # This repository's launcher stands in for an older one: its CeedlingAppConfig is
      # defined beneath this repository's bin/, so any other application root is foreign
      @app_cfg = CeedlingAppConfig.new
      @launcher = Installation.new( @app_cfg[:launcher_root_path] )
      @loginator = double('loginator').as_null_object
      @system_wrapper = double('system_wrapper', get_cmdline: ['test:all', '-v', 'obnoxious'])
      @handoff_objects = {loginator: @loginator, system_wrapper: @system_wrapper}
      allow(described_class).to receive(:exec)
    end

    def complete(app_root, env: {})
      described_class.complete_in_process( app_root: app_root, app_cfg: @app_cfg, handoff_objects: @handoff_objects, env: env )
    end

    it 'restarts a foreign launcher\'s application in its own process, with the original command line' do
      Dir.mktmpdir do |root|
        app = Installation.new( root )

        expect(@loginator).to receive(:log).with(
          "#{@launcher.describe( 'Ceedling launcher' )} loaded #{app.describe} into its own process. " +
          "Restarting in #{app.name}'s own process. Upgrade Ceedling and review your installations to avoid this.",
          Verbosity::COMPLAIN
        ).ordered
        expect(described_class).to receive(:exec).with(
          target: app, launcher: @launcher, argv: ['test:all', '-v', 'obnoxious'], loginator: @loginator
        ).ordered

        complete( root )
      end
    end

    it 'does nothing for the launcher\'s own application' do
      complete( @launcher.root )

      expect(described_class).to_not have_received(:exec)
      expect(@loginator).to_not have_received(:log)
    end

    def expect_fallback(app)
      expect(@loginator).to receive(:log).with(
        "#{@launcher.describe( 'Ceedling launcher' )} loaded #{app.describe} into its own process. " +
        "Continuing in the launcher's process, which can fail or misbehave. Upgrade Ceedling, or run this " +
        "installation's own launcher directly with `ruby #{app.bin_path}`. A project created with `--local` has a " +
        "launch script at its root that does this: run `./ceedling` from the project root (`.\\ceedling.cmd` on Windows).",
        Verbosity::COMPLAIN
      )
    end

    it 'warns and continues when the launcher kept no command line to restart with' do
      Dir.mktmpdir do |root|
        @handoff_objects[:system_wrapper] = double('old_system_wrapper')
        expect_fallback( Installation.new( root ) )

        complete( root )

        expect(described_class).to_not have_received(:exec)
      end
    end

    # A hand-off already happened in this chain; restarting again could cycle
    it 'warns and continues when a launcher handed off to this process' do
      Dir.mktmpdir do |root|
        @app_cfg.set_handoff( {launcher: '/gem', target: @launcher.root} )
        expect_fallback( Installation.new( root ) )

        complete( root )

        expect(described_class).to_not have_received(:exec)
      end
    end

    it 'warns and continues when hand-off markers are still in the environment' do
      Dir.mktmpdir do |root|
        expect_fallback( Installation.new( root ) )

        complete( root, env: {'CEEDLING_HANDOFF_TARGET' => '/somewhere'} )

        expect(described_class).to_not have_received(:exec)
      end
    end

    it 'names the launcher relative to the working directory when it lies beneath it' do
      Dir.mktmpdir do |root|
        Dir.chdir( root ) do
          app = Installation.new( File.join( Dir.pwd, 'vendor', 'ceedling' ) )
          @handoff_objects[:system_wrapper] = double('old_system_wrapper')

          expect(@loginator).to receive(:log).with( /directly with `ruby vendor\/ceedling\/bin\/ceedling`/, Verbosity::COMPLAIN )

          complete( app.root )
        end
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
