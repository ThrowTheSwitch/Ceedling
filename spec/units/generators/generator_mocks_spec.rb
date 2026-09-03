# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/generators/generator_mocks'

describe GeneratorMocks do
  before(:each) do
    @configurator = double( 'Configurator' )
    @mocks = described_class.new( { configurator: @configurator } )
  end

  describe '#build_configuration' do

    it 'sets :mock_path to the given output path' do
      allow(@configurator).to receive(:get_cmock_config).and_return( {} )
      allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::NORMAL )

      config = @mocks.build_configuration( 'build/test/mocks/a_test' )

      expect( config[:mock_path] ).to eq( 'build/test/mocks/a_test' )
    end

    describe 'verbosity mapping' do
      # CMock's own verbosity scale is coarser than Ceedling's: 0 errors only,
      # 1 warnings and errors, 2 normal, 3 verbose. Only the two ends of
      # Ceedling's own scale get a distinct mapping; everything in the middle
      # settles on CMock's "warnings and errors" as a reasonable default.
      it 'maps SILENT to 0' do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::SILENT )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 0 )
      end

      it 'defaults to 1 at COMPLAIN' do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::COMPLAIN )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 1 )
      end

      it 'defaults to 1 at NORMAL' do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::NORMAL )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 1 )
      end

      it 'defaults to 1 at OBNOXIOUS' do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::OBNOXIOUS )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 1 )
      end

      it 'maps DEBUG to 3' do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::DEBUG )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 3 )
      end

      # CMock has no level quieter than "errors only" -- it is never fully silent.
      it 'also maps ERRORS to 0, the same as SILENT' do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::ERRORS )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 0 )
      end
    end

    describe 'configuration overrides' do
      it "merges a given override onto the computed configuration, the override winning" do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::NORMAL )

        config = @mocks.build_configuration( 'out', overrides: { verbosity: 3 } )

        expect( config[:verbosity] ).to eq( 3 )
      end

      it "leaves the computed configuration untouched when no override is given" do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::NORMAL )

        config = @mocks.build_configuration( 'out' )

        expect( config[:verbosity] ).to eq( 1 )
      end

      it "merges an override key that isn't otherwise computed here at all" do
        allow(@configurator).to receive(:get_cmock_config).and_return( {} )
        allow(@configurator).to receive(:project_verbosity).and_return( Verbosity::NORMAL )

        config = @mocks.build_configuration( 'out', overrides: { treat_inlines: :exclude } )

        expect( config[:treat_inlines] ).to eq( :exclude )
      end
    end

  end

  describe '#manufacture' do
    it 'builds a CMock instance from the given configuration' do
      config = { mock_path: 'out' }

      cmock = @mocks.manufacture( config )

      expect( cmock ).to be_a( CMock )
    end
  end

end
