# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/include_factory'

describe IncludeFactory do
  before(:each) do
    @configurator = double( "Configurator" )
    allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
    allow(@configurator).to receive(:cmock_mock_path).and_return( 'build/test/mocks' )

    @factory = described_class.new( { configurator: @configurator } )
  end

  describe '#user_include_from_filepath' do
    it 'strips a flat test\'s own mock subdirectory down to the bare mock filename' do
      include_obj = @factory.user_include_from_filepath( 'build/test/mocks/TestFoo/MockBar.h', test: 'TestFoo' )
      expect( include_obj.filename ).to eq( 'MockBar.h' )
      expect( include_obj.filepath ).to eq( 'MockBar.h' )
    end

    it 'strips a nested test\'s own multi-segment mock subdirectory down to the bare mock filename' do
      include_obj = @factory.user_include_from_filepath(
        'build/test/mocks/adc/TestAdcConductor/MockAdcHardware.h', test: 'adc/TestAdcConductor'
      )
      expect( include_obj.filename ).to eq( 'MockAdcHardware.h' )
      expect( include_obj.filepath ).to eq( 'MockAdcHardware.h' )
    end

    it 'preserves a mocked header\'s own mirrored subdirectory beyond the test\'s own mock subdirectory' do
      include_obj = @factory.user_include_from_filepath(
        'build/test/mocks/TestFoo/calculators/MockBar.h', test: 'TestFoo'
      )
      expect( include_obj.filename ).to eq( 'MockBar.h' )
      expect( include_obj.filepath ).to eq( 'calculators/MockBar.h' )
    end

    it 'falls back to stripping through the last segment when no test identity is given' do
      include_obj = @factory.user_include_from_filepath( 'build/test/mocks/TestFoo/MockBar.h' )
      expect( include_obj.filepath ).to eq( 'MockBar.h' )
    end

    it 'leaves an ordinary (non-mock) filepath untouched' do
      include_obj = @factory.user_include_from_filepath( 'src/foo/bar.h', test: 'TestFoo' )
      expect( include_obj.filepath ).to eq( 'src/foo/bar.h' )
    end
  end
end
