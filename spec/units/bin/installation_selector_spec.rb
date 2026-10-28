# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'installation_selector'
require 'path_validator'
require 'app_cfg'

describe InstallationSelector do
  before(:each) do
    @file_wrapper      = double('file_wrapper').as_null_object
    @config_walkinator = double('config_walkinator').as_null_object
    @loginator         = double('loginator').as_null_object
    @app_cfg           = CeedlingAppConfig.new

    @selector = described_class.new({
      :file_wrapper      => @file_wrapper,
      :config_walkinator => @config_walkinator,
      # Real, so path standardization is exercised rather than assumed
      :path_validator    => PathValidator.new( {:file_wrapper => @file_wrapper, :loginator => @loginator} ),
      :loginator         => @loginator,
    })

    # Baseline: no :project ↳ :which_ceedling entry found. Examples exercising that
    # config path override this with a more specific `.with(...)` stub.
    allow(@config_walkinator).to receive(:fetch_value).and_return( [nil, nil] )
  end

  it 'uses the WHICH_CEEDLING environment variable at highest priority' do
    installation = @selector.select( env: {'WHICH_CEEDLING' => 'gem'}, app_cfg: @app_cfg )

    expect(installation).to eq( Installation.new( @app_cfg[:launcher_root_path] ) )
  end

# A console line would print at every verbosity, into `dumpconfig --stdout` YAML among others
it 'logs its use of WHICH_CEEDLING at obnoxious verbosity, as for every other source' do
  @selector.select( env: {'WHICH_CEEDLING' => 'gem'}, app_cfg: @app_cfg )

  expect(@loginator).to have_received(:log).with( " > Set which Ceedling using environment variable WHICH_CEEDLING", Verbosity::OBNOXIOUS )
  expect(@loginator).to_not have_received(:console)
end

  it 'falls back to config :project ↳ :which_ceedling when no environment variable is set' do
    config = {:project => {:which_ceedling => 'gem'}}
    allow(@config_walkinator).to receive(:fetch_value).with( :project, :which_ceedling, hash: config ).and_return( ['gem', nil] )

    installation = @selector.select( env: {}, config: config, app_cfg: @app_cfg )

    expect(installation).to eq( Installation.new( @app_cfg[:launcher_root_path] ) )
  end

  it 'falls back to a vendor/ceedling directory when neither environment nor config specify anything' do
    allow(@file_wrapper).to receive(:directory?).with( 'vendor/ceedling' ).and_return( true )
    allow(@file_wrapper).to receive(:exist?).and_return( true )

    installation = @selector.select( env: {}, app_cfg: @app_cfg )

    expect(installation.root).to eq( File.expand_path( 'vendor/ceedling' ) )
    expect(@app_cfg[:ceedling_root_path]).to eq( File.expand_path( 'vendor/ceedling' ) )
  end

  # GH #1365: `upgrade` run inside a project took the project's own copy as its source
  it 'ignores a vendor/ceedling directory when vendor detection is off' do
    allow(@file_wrapper).to receive(:directory?).with( 'vendor/ceedling' ).and_return( true )

    installation = @selector.select( env: {}, app_cfg: @app_cfg, detect_vendor: false )

    expect(installation).to eq( Installation.new( @app_cfg[:launcher_root_path] ) )
  end

  it 'defaults to the gem when nothing is set and no vendor/ceedling directory exists' do
    allow(@file_wrapper).to receive(:directory?).with( 'vendor/ceedling' ).and_return( false )

    installation = @selector.select( env: {}, app_cfg: @app_cfg )

    expect(installation).to eq( Installation.new( @app_cfg[:launcher_root_path] ) )
  end

  it 'standardizes backslashes in a selected path' do
    allow(@file_wrapper).to receive(:directory?).and_return( true )
    allow(@file_wrapper).to receive(:exist?).and_return( true )

    installation = @selector.select( env: {'WHICH_CEEDLING' => 'tools\\ceedling'}, app_cfg: @app_cfg )

    expect(installation.root).to eq( File.expand_path( 'tools/ceedling' ) )
    expect(@file_wrapper).to have_received(:directory?).with( 'tools/ceedling' )
  end

  it 'raises when a configured launch path does not exist as a directory' do
    config = {:project => {:which_ceedling => 'nonexistent/path'}}
    allow(@config_walkinator).to receive(:fetch_value).with( :project, :which_ceedling, hash: config ).and_return( ['nonexistent/path', nil] )
    allow(@file_wrapper).to receive(:directory?).and_return( false )

    expect {
      @selector.select( env: {}, config: config, app_cfg: @app_cfg )
    }.to raise_error( /does not exist/ )
  end

  it 'raises when a configured launch path exists but contains no Ceedling installation' do
    config = {:project => {:which_ceedling => 'empty/path'}}
    allow(@config_walkinator).to receive(:fetch_value).with( :project, :which_ceedling, hash: config ).and_return( ['empty/path', nil] )
    allow(@file_wrapper).to receive(:directory?).and_return( true )
    allow(@file_wrapper).to receive(:exist?).and_return( false )

    expect {
      @selector.select( env: {}, config: config, app_cfg: @app_cfg )
    }.to raise_error( /contains no Ceedling installation/ )
  end
end
