# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/filename_extension'
require 'ceedling/test_invoker/test_source_file_directive_resolver'
require 'ceedling/exceptions'

describe TestSourceFileDirectiveResolver do
  before(:each) do
    @test_context_extractor = double( "TestContextExtractor" )
    @file_finder             = double( "FileFinder" )
    @configurator               = double( "Configurator" )
    @loginator                     = double( "Loginator" )

    @resolver = described_class.new(
      {
        :test_context_extractor => @test_context_extractor,
        :file_finder             => @file_finder,
        :configurator               => @configurator,
        :loginator                     => @loginator
      }
    )
  end

  describe "#resolve" do
    it "resolves additive-only entries into the first return value, leaving the second empty" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['foo.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.c', complain: :ignore, context: :test ).and_return( 'src/foo.c' )

      additive, subtractive = @resolver.resolve( 'test/TestFoo.c', :test )

      expect(additive).to eq( ['src/foo.c'] )
      expect(subtractive).to eq( {} )
    end

    it "resolves a bare -: entry into the second return value, keyed by resolved path and valued with the raw entry" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['-:foo/bar.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo/bar.c', complain: :ignore, context: :test ).and_return( 'src/foo/bar.c' )

      additive, subtractive = @resolver.resolve( 'test/TestFoo.c', :test )

      expect(additive).to eq( [] )
      expect(subtractive).to eq( { 'src/foo/bar.c' => '-:foo/bar.c' } )
    end

    it "splits a mixed list of additive and subtractive entries correctly" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['foo.c', '-:bar.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.c', complain: :ignore, context: :test ).and_return( 'src/foo.c' )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'bar.c', complain: :ignore, context: :test ).and_return( 'src/bar.c' )

      additive, subtractive = @resolver.resolve( 'test/TestFoo.c', :test )

      expect(additive).to eq( ['src/foo.c'] )
      expect(subtractive).to eq( { 'src/bar.c' => '-:bar.c' } )
    end

    it "drops a subtractive entry the file finder could not resolve, rather than keeping a nil key" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['-:missing.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'missing.c', complain: :ignore, context: :test ).and_return( nil )

      additive, subtractive = @resolver.resolve( 'test/TestFoo.c', :test )

      expect(subtractive).to eq( {} )
    end

    it "strips a +: prefix from an additive entry before resolution" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['+:foo.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.c', complain: :ignore, context: :test ).and_return( 'src/foo.c' )

      additive, subtractive = @resolver.resolve( 'test/TestFoo.c', :test )

      expect(additive).to eq( ['src/foo.c'] )
    end
  end

  describe "#validate!" do
    before(:each) do
      allow(@configurator).to receive(:extension_source).and_return( FilenameExtension.new('.c') )
      allow(@configurator).to receive(:test_build_use_assembly).and_return( false )
    end

    it "does not raise for a -: entry naming a real, correctly-extensioned file" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['-:foo.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.c', complain: :ignore, context: TEST_SYM ).and_return( 'src/foo.c' )

      expect {
        @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
      }.to_not raise_error
    end

    it "raises when a -: entry names a file that cannot be found in the source file collection" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['-:foo.c'] )
      allow(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.c', complain: :ignore, context: TEST_SYM ).and_return( nil )

      expect {
        @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
      }.to raise_error( CeedlingException, /'foo\.c'.*cannot be found in the source file collection/ )
    end

    it "raises for a -: entry with an unrecognized extension, exactly as it would for an additive entry" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['-:foo.txt'] )

      expect {
        @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
      }.to raise_error( CeedlingException, /'foo\.txt'.*not a .*\.c.*source file/ )
    end

    it "references the decorator-stripped filename in file finder calls and error messages" do
      allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
        .with( 'test/TestFoo.c' ).and_return( ['-:foo.c'] )
      expect(@file_finder).to receive(:find_build_input_file)
        .with( filepath: 'foo.c', complain: :ignore, context: TEST_SYM ).and_return( nil )

      expect {
        @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
      }.to raise_error( CeedlingException, /^File 'foo\.c'/ )
    end

    context "when assembly support is enabled" do
      before(:each) do
        allow(@configurator).to receive(:test_build_use_assembly).and_return( true )
        allow(@configurator).to receive(:extension_assembly).and_return( FilenameExtension.new('.asm') )
      end

      it "does not raise for an entry with the assembly extension" do
        allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
          .with( 'test/TestFoo.c' ).and_return( ['foo.asm'] )
        allow(@file_finder).to receive(:find_build_input_file)
          .with( filepath: 'foo.asm', complain: :ignore, context: TEST_SYM ).and_return( 'src/foo.asm' )

        expect {
          @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
        }.to_not raise_error
      end

      it "still does not raise for an entry with the ordinary source extension" do
        allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
          .with( 'test/TestFoo.c' ).and_return( ['foo.c'] )
        allow(@file_finder).to receive(:find_build_input_file)
          .with( filepath: 'foo.c', complain: :ignore, context: TEST_SYM ).and_return( 'src/foo.c' )

        expect {
          @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
        }.to_not raise_error
      end

      it "raises naming both accepted extensions for an entry matching neither" do
        allow(@test_context_extractor).to receive(:lookup_build_directive_sources_list)
          .with( 'test/TestFoo.c' ).and_return( ['foo.txt'] )

        expect {
          @resolver.validate!( test: 'TestFoo', filepath: 'test/TestFoo.c' )
        }.to raise_error( CeedlingException, /not a \.c or \.asm source file/ )
      end
    end
  end

  describe "#remove_subtracted" do
    it "removes a resolved subtractive path present in sources, logging one NOTICE naming the raw entry and the removed path" do
      sources = ['src/foo.c', 'src/bar.c']
      subtractive = { 'src/bar.c' => '-:bar.c' }

      expect(@loginator).to receive(:log).with(
        a_string_matching(/-:bar\.c/).and(a_string_matching(/src\/bar\.c/)).and(a_string_matching(/test\/TestFoo\.c/)),
        Verbosity::COMPLAIN,
        LogLabels::NOTICE
      )

      result = @resolver.remove_subtracted( sources, subtractive: subtractive, test_filepath: 'test/TestFoo.c' )

      expect(result).to eq( ['src/foo.c'] )
    end

    it "does nothing and logs nothing for a subtractive entry not present in sources" do
      sources = ['src/foo.c']
      subtractive = { 'src/nonexistent.c' => '-:nonexistent.c' }

      expect(@loginator).to_not receive(:log)

      result = @resolver.remove_subtracted( sources, subtractive: subtractive, test_filepath: 'test/TestFoo.c' )

      expect(result).to eq( ['src/foo.c'] )
    end

    it "removes more than one subtractive entry correctly" do
      sources = ['src/foo.c', 'src/bar.c', 'src/baz.c']
      subtractive = { 'src/bar.c' => '-:bar.c', 'src/baz.c' => '-:baz.c' }

      allow(@loginator).to receive(:log)

      result = @resolver.remove_subtracted( sources, subtractive: subtractive, test_filepath: 'test/TestFoo.c' )

      expect(result).to eq( ['src/foo.c'] )
    end
  end
end
