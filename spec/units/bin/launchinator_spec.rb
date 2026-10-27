# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/constants'
require 'launchinator'
require 'app_cfg'

describe Launchinator do
  before(:each) do
    @selector  = double('installation_selector')
    @loginator = double('loginator').as_null_object
    @app_cfg   = CeedlingAppConfig.new( argv: ['test:all', '--verbosity=obnoxious'] )
    @launcher  = Installation.new( @app_cfg[:launcher_root_path] )

    @launchinator = described_class.new({
      :installation_selector => @selector,
      :loginator             => @loginator,
    })

    allow(Handoff).to receive(:exec)
  end

  def select(installation)
    allow(@selector).to receive(:select) do |app_cfg:, **|
      app_cfg.set_paths( installation.root )
      installation
    end
  end

  describe '#resolve' do
    it 'selects which Ceedling without handing off' do
      Dir.mktmpdir do |other|
        select( Installation.new( other ) )

        expect(@launchinator.resolve( env: {}, app_cfg: @app_cfg )).to eq( Installation.new( other ) )
        expect(Handoff).to_not have_received(:exec)
      end
    end

    it 'passes the configuration and vendor detection through to selection' do
      select( @launcher )
      config = {:project => {}}

      @launchinator.resolve( env: {'X' => '1'}, app_cfg: @app_cfg, config: config, detect_vendor: false )

      expect(@selector).to have_received(:select).with( env: {'X' => '1'}, config: config, app_cfg: @app_cfg, detect_vendor: false )
    end
  end

  describe '#launch' do
    it 'continues in-process and returns the rakefile when the launcher\'s own installation is selected' do
      select( @launcher )

      expect(@launchinator.launch( env: {}, app_cfg: @app_cfg )).to eq( @launcher.rakefile_path )
      expect(Handoff).to_not have_received(:exec)
      expect(@loginator).to_not have_received(:log)
    end

    # GH #1365: another installation once ran inside this launcher's process
    it 'hands off to another installation with the original command line, after saying so' do
      Dir.mktmpdir do |other|
        target = Installation.new( other )
        FileUtils.mkdir_p( File.dirname( target.bin_path ) )
        FileUtils.touch( target.bin_path )
        select( target )

        expect(@loginator).to receive(:log).with(
          Handoff.handing_off_message( launcher: @launcher, target: target ), Verbosity::COMPLAIN, LogLabels::NOTICE
        ).ordered
        expect(Handoff).to receive(:exec).with(
          target: target, launcher: @launcher, argv: ['test:all', '--verbosity=obnoxious'], loginator: @loginator
        ).ordered

        @launchinator.launch( env: {}, app_cfg: @app_cfg )
      end
    end

    it 'raises rather than hand off to an installation with no launcher' do
      Dir.mktmpdir do |other|
        select( Installation.new( other ) )

        expect {
          @launchinator.launch( env: {}, app_cfg: @app_cfg )
        }.to raise_error( CeedlingException, /#{Regexp.escape( Installation.new( other ).bin_path )}/ )
        expect(Handoff).to_not have_received(:exec)
      end
    end

    # GH #1365: such a copy only ever ran inside another launcher's process
    it 'stops with advice to upgrade rather than hand off to a copy vendored without its built-in mixins' do
      Dir.mktmpdir do |other|
        target = Installation.new( other )
        FileUtils.mkdir_p( File.dirname( target.bin_path ) )
        FileUtils.touch( target.bin_path )
        File.write( File.join( other, 'bin', 'mixins.rb' ), "BUILTIN_MIXIN_LOAD_PATHS = []\n" )
        select( target )

        expect {
          @launchinator.launch( env: {}, app_cfg: @app_cfg )
        }.to raise_error( CeedlingException, /#{Regexp.escape( target.describe )} cannot run on its own.*ceedling upgrade/m )
        expect(Handoff).to_not have_received(:exec)
      end
    end

    context 'in a process another launcher handed off to' do
      before(:each) do
        @app_cfg.set_handoff( {launcher: '/usr/lib/gems/ceedling-1.2.3', target: @launcher.root} )
      end

      it 'says where it was launched from and continues in-process' do
        select( @launcher )

        expect(@loginator).to receive(:log).with(
          Handoff.received_message( @app_cfg[:handoff], own: @launcher ), Verbosity::COMPLAIN, LogLabels::NOTICE
        )

        expect(@launchinator.launch( env: {}, app_cfg: @app_cfg )).to eq( @launcher.rakefile_path )
        expect(Handoff).to_not have_received(:exec)
      end

      it 'never hands off again, even when another installation is selected' do
        Dir.mktmpdir do |other|
          select( Installation.new( other ) )

          expect(@launchinator.launch( env: {}, app_cfg: @app_cfg )).to eq( Installation.new( other ).rakefile_path )
          expect(Handoff).to_not have_received(:exec)
        end
      end
    end

    it 'ignores markers naming another installation as the target' do
      Dir.mktmpdir do |other|
        FileUtils.mkdir_p( File.join( other, 'bin' ) )
        FileUtils.touch( File.join( other, 'bin', 'ceedling' ) )
        @app_cfg.set_handoff( {launcher: '/gem', target: '/somewhere/else'} )
        select( Installation.new( other ) )

        @launchinator.launch( env: {}, app_cfg: @app_cfg )

        expect(Handoff).to have_received(:exec)
      end
    end
  end
end
