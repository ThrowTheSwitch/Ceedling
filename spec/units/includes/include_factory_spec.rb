# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/include_factory'
require 'ceedling/filesystem/test_build_layout'

describe IncludeFactory do
  before(:each) do
    @configurator = double( "Configurator" )
    allow(@configurator).to receive(:cmock_mock_prefix).and_return( 'Mock' )
    allow(@configurator).to receive(:cmock_mock_path).and_return( 'build/test/mocks' )
    allow(@configurator).to receive(:project_use_mocks).and_return( true )

    file_wrapper = double( "FileWrapper" )
    allow(file_wrapper).to receive(:check_path_length)
    layout = TestBuildLayout.new( { configurator: @configurator, file_wrapper: file_wrapper } )

    @factory = described_class.new( { configurator: @configurator, test_build_layout: layout } )
  end

  describe '#user_include_from_filepath' do
    it 'strips a test\'s own mock subdirectory down to the bare mock filename' do
      include_obj = @factory.user_include_from_filepath( 'build/test/mocks/test/TestFoo/_t_/MockBar.h', test: 'test/TestFoo' )
      expect( include_obj.filename ).to eq( 'MockBar.h' )
      expect( include_obj.filepath ).to eq( 'MockBar.h' )
    end

    it 'strips a nested test\'s own multi-segment mock subdirectory down to the bare mock filename' do
      include_obj = @factory.user_include_from_filepath(
        'build/test/mocks/test/adc/TestAdcConductor/_t_/MockAdcHardware.h', test: 'test/adc/TestAdcConductor'
      )
      expect( include_obj.filename ).to eq( 'MockAdcHardware.h' )
      expect( include_obj.filepath ).to eq( 'MockAdcHardware.h' )
    end

    it 'preserves a mocked header\'s own mirrored subdirectory beyond the test\'s own mock subdirectory' do
      include_obj = @factory.user_include_from_filepath(
        'build/test/mocks/TestFoo/_t_/calculators/MockBar.h', test: 'TestFoo'
      )
      expect( include_obj.filename ).to eq( 'MockBar.h' )
      expect( include_obj.filepath ).to eq( 'calculators/MockBar.h' )
    end

    # A test's mock lies in a folder named like a test nested below it
    it 'keeps a mocked header\'s subdirectory named like a nested test' do
      include_obj = @factory.user_include_from_filepath( 'build/test/mocks/test/test_c/_t_/test_x/Mockqux.h', test: 'test/test_c' )
      expect( include_obj.filepath ).to eq( 'test_x/Mockqux.h' )
    end

    it 'leaves a mock below another test\'s mock root untouched' do
      include_obj = @factory.user_include_from_filepath( 'build/test/mocks/test/test_c/test_x/_t_/Mockqux.h', test: 'test/test_c' )
      expect( include_obj.filepath ).to eq( 'build/test/mocks/test/test_c/test_x/_t_/Mockqux.h' )
    end

    it 'falls back to stripping through the last segment when no test identity is given' do
      include_obj = @factory.user_include_from_filepath( 'build/test/mocks/TestFoo/_t_/MockBar.h' )
      expect( include_obj.filepath ).to eq( 'MockBar.h' )
    end

    it 'leaves an ordinary (non-mock) filepath untouched' do
      include_obj = @factory.user_include_from_filepath( 'src/foo/bar.h', test: 'TestFoo' )
      expect( include_obj.filepath ).to eq( 'src/foo/bar.h' )
    end
  end
end
