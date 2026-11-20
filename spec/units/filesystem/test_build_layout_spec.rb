# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filesystem/test_build_layout'
require 'ceedling/filesystem/build_subpath'

describe TestBuildLayout do

  LAYOUT_BASES = {
    mocks:               'build/test/mocks',
    partials:            'build/test/partials',
    preprocess_includes: 'build/test/preprocess/includes',
    preprocess_files:    'build/test/preprocess/files',
    build_directives:    'build/test/preprocess/build_directives',
    out:                 'build/test/out',
    dependencies:        'build/test/dependencies'
  }.freeze

  before(:each) do
    @configurator = double( 'configurator' )
    @file_wrapper = double( 'file_wrapper' )
    allow(@file_wrapper).to receive(:check_path_length)

    allow(@configurator).to receive(:project_build_root).and_return( 'build' )
    allow(@configurator).to receive(:project_use_mocks).and_return( true )
    allow(@configurator).to receive(:project_use_partials).and_return( true )
    allow(@configurator).to receive(:cmock_mock_path).and_return( LAYOUT_BASES[:mocks] )
    allow(@configurator).to receive(:project_test_partials_path).and_return( LAYOUT_BASES[:partials] )
    allow(@configurator).to receive(:project_test_preprocess_includes_path).and_return( LAYOUT_BASES[:preprocess_includes] )
    allow(@configurator).to receive(:project_test_preprocess_files_path).and_return( LAYOUT_BASES[:preprocess_files] )
    allow(@configurator).to receive(:project_test_preprocess_build_directives_path).and_return( LAYOUT_BASES[:build_directives] )

    @layout = described_class.new( { :configurator => @configurator, :file_wrapper => @file_wrapper } )
  end

  it 'reserves the segment `_t_`' do
    expect( BuildSubpath::OWN_SEGMENT ).to eq( '_t_' )
  end

  describe '#base' do
    LAYOUT_BASES.each do |kind, base|
      it "gives the shared #{kind} directory" do
        expect( @layout.base( kind, context: :test ) ).to eq( base )
      end
    end

    it 'places the output and dependencies bases below their build context' do
      expect( @layout.base( :out, context: :gcov ) ).to eq( 'build/gcov/out' )
      expect( @layout.base( :dependencies, context: :gcov ) ).to eq( 'build/gcov/dependencies' )
      expect( @layout.base( :out ) ).to eq( 'build/out' )
    end

    it 'gives no base for a disabled feature' do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      allow(@configurator).to receive(:project_use_partials).and_return( false )

      expect( @layout.base( :mocks ) ).to be_nil
      expect( @layout.base( :partials ) ).to be_nil
    end
  end

  describe '#root' do
    LAYOUT_BASES.each do |kind, base|
      it "closes a test's #{kind} directory with `_t_`" do
        expect( @layout.root( kind, 'test/unit/test_foo', context: :test ) ).to eq( "#{base}/test/unit/test_foo/_t_" )
      end
    end

    it 'gives no root for a nil or empty name' do
      expect( @layout.root( :mocks, nil ) ).to be_nil
      expect( @layout.root( :mocks, '' ) ).to be_nil
      expect( @layout.root( :out, nil, context: :test ) ).to be_nil
    end

    it 'gives no root for a disabled feature' do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )
      allow(@configurator).to receive(:project_use_partials).and_return( false )

      expect( @layout.root( :mocks, 'test/test_c' ) ).to be_nil
      expect( @layout.root( :partials, 'test/test_c' ) ).to be_nil
    end

    it "places a nested test's root beside its parent's subdirectory of the same name" do
      expect( @layout.root( :mocks, 'test/test_c/test_x' ) ).to eq( 'build/test/mocks/test/test_c/test_x/_t_' )
      expect( @layout.file( :mocks, 'test/test_c', 'test_x/mock_qux.c' ) ).to eq( 'build/test/mocks/test/test_c/_t_/test_x/mock_qux.c' )
    end

    it "checks the root's length once" do
      @layout.root( :out, 'test/test_c', context: :test )

      expect(@file_wrapper).to have_received(:check_path_length).once
    end

    # Windows limits a directory's path more tightly than a file's
    it "checks the root's length as a directory's" do
      @layout.root( :mocks, 'test/test_c' )

      expect(@file_wrapper).to have_received(:check_path_length).with( 'build/test/mocks/test/test_c/_t_', origin: 'TestBuildLayout#root', directory: true )
    end
  end

  describe '#file' do
    LAYOUT_BASES.each do |kind, base|
      it "places a file below a test's #{kind} root" do
        expect( @layout.file( kind, 'test/test_c', 'drv/x.h', context: :test ) ).to eq( "#{base}/test/test_c/_t_/drv/x.h" )
      end
    end

    it 'gives the root itself for no subpath' do
      expect( @layout.file( :mocks, 'test/test_c', '' ) ).to eq( 'build/test/mocks/test/test_c/_t_' )
      expect( @layout.file( :mocks, 'test/test_c', nil ) ).to eq( 'build/test/mocks/test/test_c/_t_' )
    end

    it 'gives nothing where the test has no root' do
      allow(@configurator).to receive(:project_use_partials).and_return( false )

      expect( @layout.file( :mocks, nil, 'mock_x.h' ) ).to be_nil
      expect( @layout.file( :partials, 'test/test_c', 'x.h' ) ).to be_nil
    end
  end

  describe '#generated_roots' do
    it "gives a test's Partials root and mock root" do
      expect( @layout.generated_roots( 'test/test_c' ) ).to eq( ['build/test/partials/test/test_c/_t_', 'build/test/mocks/test/test_c/_t_'] )
    end

    it 'leaves out a disabled feature' do
      allow(@configurator).to receive(:project_use_partials).and_return( false )

      expect( @layout.generated_roots( 'test/test_c' ) ).to eq( ['build/test/mocks/test/test_c/_t_'] )
    end

    it 'gives none for no test' do
      expect( @layout.generated_roots( nil ) ).to eq( [] )
    end
  end

  describe '#locate' do
    LAYOUT_BASES.each do |kind, base|
      it "names the test of a file below its #{kind} root" do
        expect( @layout.locate( "#{base}/test/test_c/_t_/test_x/mock_qux.c", context: :test ) ).to eq( 'test/test_c' )
      end
    end

    it "tells a nested test's file from its parent's file in a folder of the nested test's name" do
      expect( @layout.locate( 'build/test/mocks/test/test_c/test_x/_t_/mock_qux.c' ) ).to eq( 'test/test_c/test_x' )
      expect( @layout.locate( 'build/test/mocks/test/test_c/_t_/test_x/mock_qux.c' ) ).to eq( 'test/test_c' )
    end

    # The first `_t_` ends the name, since no name holds one
    it 'ends the name at the first `_t_`' do
      expect( @layout.locate( 'build/test/mocks/test/test_c/_t_/_t_/mock_qux.c' ) ).to eq( 'test/test_c' )
    end

    it "names a test whose own directory is named like `_t_` by its escaped name" do
      name = BuildSubpath.encode( 'test/_t_/test_c' )

      expect( @layout.locate( @layout.file( :out, name, 'x.o', context: :test ), context: :test ) ).to eq( 'test/__t_/test_c' )
    end

    it 'names the test of its root itself' do
      expect( @layout.locate( 'build/test/out/test/test_c/_t_', context: :test ) ).to eq( 'test/test_c' )
    end

    it "locates a file below the context's own output root" do
      expect( @layout.locate( 'build/gcov/out/test/test_c/_t_/src/x.o', context: :gcov ) ).to eq( 'test/test_c' )
      expect( @layout.locate( 'build/gcov/out/test/test_c/_t_/src/x.o', context: :test ) ).to be_nil
    end

    it 'locates nothing below no test root' do
      expect( @layout.locate( 'build/test/out/test/test_c/test_c.o', context: :test ) ).to be_nil
      expect( @layout.locate( 'build/test/mocks/_t_/mock_x.c' ) ).to be_nil
      expect( @layout.locate( 'src/test_x/qux.c', context: :test ) ).to be_nil
      expect( @layout.locate( 'build/test/runners/test/test_c_runner.c', context: :test ) ).to be_nil
    end

    it 'locates nothing below a disabled feature' do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )

      expect( @layout.locate( 'build/test/mocks/test/test_c/_t_/mock_x.c' ) ).to be_nil
    end

    # Below the output base, the mock's test would be `mocks/test/test_c`
    it 'counts the most specific base holding a path' do
      allow(@configurator).to receive(:cmock_mock_path).and_return( 'build/test/out/mocks' )

      expect( @layout.locate( 'build/test/out/mocks/test/test_c/_t_/mock_x.c', context: :test ) ).to eq( 'test/test_c' )
    end
  end

  describe '#subpath' do
    LAYOUT_BASES.reject { |kind, _| TestBuildLayout::CONTEXTUAL.key?( kind ) }.each do |kind, base|
      it "gives a path below a test's #{kind} root" do
        expect( @layout.subpath( "#{base}/test/test_c/_t_/drv/x.h", kind: kind, name: 'test/test_c' ) ).to eq( 'drv/x.h' )
      end
    end

    it "gives nothing for a path outside the test's root" do
      expect( @layout.subpath( 'build/test/mocks/test/test_c/test_x/_t_/mock_qux.h', kind: :mocks, name: 'test/test_c' ) ).to be_nil
      expect( @layout.subpath( 'test_x/mock_qux.h', kind: :mocks, name: 'test/test_c' ) ).to be_nil
    end

    it 'gives nothing for no name or a disabled feature' do
      allow(@configurator).to receive(:project_use_mocks).and_return( false )

      expect( @layout.subpath( 'build/test/partials/test/test_c/_t_/x.h', kind: :partials, name: nil ) ).to be_nil
      expect( @layout.subpath( 'build/test/mocks/test/test_c/_t_/x.h', kind: :mocks, name: 'test/test_c' ) ).to be_nil
    end
  end

end
