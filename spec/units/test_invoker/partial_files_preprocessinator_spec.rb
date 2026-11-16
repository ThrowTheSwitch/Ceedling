# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/partial_files_preprocessinator'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/partials/partials'

describe PartialFilesPreprocessinator do
  let(:target)         { 'build/preprocess/files/a_test/src/Foo.h' }
  let(:raw_directives) { 'build/preprocess/files/a_test/directives_only/raw/src/Foo.h' }
  let(:raw_expansion)  { 'build/preprocess/files/a_test/full_expansion/src/Foo.h' }
  let(:expanded_code)  { 'build/preprocess/files/a_test/expanded_code/src/Foo.h' }
  let(:includes_list)  { 'build/preprocess/includes/a_test/src/Foo.h.yml' }

  before(:each) do
    @configurator     = double( 'Configurator' )
    @loginator        = double( 'Loginator' )
    @reportinator     = double( 'Reportinator' )
    @batchinator      = double( 'Batchinator' )
    @preprocessinator = double( 'Preprocessinator' )
    @file_path_utils  = double( 'FilePathUtils' )
    @file_wrapper     = double( 'FileWrapper' )
    @dependinator     = double( 'Dependinator' )

    @tools = { directives_only: { name: 'directives-only' }, bare: { name: 'bare' }, full: { name: 'full' } }
    allow(@configurator).to receive(:tools_test_file_directives_only_preprocessor).and_return( @tools[:directives_only] )
    allow(@configurator).to receive(:tools_test_bare_includes_preprocessor).and_return( @tools[:bare] )
    allow(@configurator).to receive(:tools_test_file_full_preprocessor).and_return( @tools[:full] )
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )
    allow(@configurator).to receive(:get_partials_config).and_return( { max_extraction_length: 5000 } )
    allow(@configurator).to receive(:project_build_vendor_ceedling_path).and_return( 'build/vendor/ceedling' )
    allow(@configurator).to receive(:project_build_root).and_return( 'build' )
    allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( true )

    allow(@reportinator).to receive(:generate_module_progress) { |operation:, module_name:, filename:| "#{operation} #{module_name}::#{filename}" }
    allow(@reportinator).to receive(:generate_skip_summary).and_return( nil )
    allow(@loginator).to receive(:log)

    allow(@batchinator).to receive(:exec) { |things:, **, &block| things.each { |thing| block.call( thing ) } }

    allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return( target )
    allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath).and_return( raw_directives )
    allow(@file_path_utils).to receive(:form_preprocessed_file_full_expansion_filepath).and_return( raw_expansion )
    allow(@file_path_utils).to receive(:form_preprocessed_file_expanded_code_filepath).and_return( expanded_code )
    allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return( includes_list )

    # Files on disk, by path. An example adds what an earlier run would have left.
    @on_disk = []
    allow(@file_wrapper).to receive(:exist?) { |path| @on_disk.include?( path ) }
    allow(@file_wrapper).to receive(:rm_f)

    allow(@dependinator).to receive(:register)
    allow(@dependinator).to receive(:stale?).and_return( true )
    allow(@dependinator).to receive(:mark_fresh)

    @includes = [double( 'Include' )]
    allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( raw_directives )
    allow(@preprocessinator).to receive(:preprocess_partial_file).and_return( [target, @includes] )
    allow(@preprocessinator).to receive(:generate_partial_expansion).and_return( expanded_code )
    allow(@preprocessinator).to receive(:load_includes_list).and_return( @includes )
    allow(@preprocessinator).to receive(:preprocessed_dependencies).and_return( ['src/Foo.h', 'src/config.h', 'build/standins/a.h'] )

    @testable = TestInvokerTypes::Testable.new(
      name: 'a_test', preprocess_flags: ['-Wall'], preprocess_defines: ['TEST'], search_paths: ['src']
    )
    @config = Partials::ConfigFileInfo.new( filepath: 'src/Foo.h' )
    @state  = TestInvokerTypes::PipelineState.new(
      testables: { a_test: @testable }, partials_headers: [TestInvokerTypes::PartialWork.new( config: @config, testable: @testable )],
      partials_sources: [], context: :test, options: [], lock: Mutex.new
    )

    @preprocessinator_object = described_class.new(
      configurator: @configurator, loginator: @loginator, reportinator: @reportinator, batchinator: @batchinator,
      preprocessinator: @preprocessinator, file_path_utils: @file_path_utils, file_wrapper: @file_wrapper,
      dependinator: @dependinator
    )
  end

  def preprocess_headers
    @preprocessinator_object.preprocess_headers( @state )
  end

  it 'registers the assembled copy as the target, with the file and every setting that shapes the runs' do
    expect(@dependinator).to receive(:register).with(
      target,
      files: ['src/Foo.h'],
      meta:  {
        flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'],
        tools: [@tools[:directives_only], @tools[:bare], @tools[:full]], preprocess_force_fallback: false,
        partials: { max_extraction_length: 5000 }
      }
    )

    preprocess_headers()
  end

  # The previous run's expansion names every header it entered. Files below the build root
  # derive from project files and would only ever look changed.
  it 'depends, before checking staleness, on the project headers the previous expansion entered' do
    @on_disk << raw_expansion

    expect(@preprocessinator).to receive(:preprocessed_dependencies).with( preprocessed_filepath: raw_expansion ).ordered.and_return( ['src/Foo.h', 'src/config.h', 'build/standins/a.h'] )
    expect(@dependinator).to receive(:register).with( target, files: ['src/Foo.h', 'src/config.h'] ).ordered
    expect(@dependinator).to receive(:stale?).with( target ).ordered.and_return( false )
    @on_disk << expanded_code

    preprocess_headers()
  end

  it 'reads no dependencies before the first run, when no expansion exists' do
    expect(@preprocessinator).to receive(:preprocessed_dependencies).once

    preprocess_headers()
  end

  context 'when stale' do
    it 'runs directives-only, then assembly with the raw output, then the full expansion, and marks the target fresh last' do
      expect(@preprocessinator).to receive(:generate_directives_only_output).with(
        filepath: 'src/Foo.h', test: 'a_test', flags: ['-Wall'], include_paths: ['src'], vendor_paths: ['build/vendor/ceedling'], defines: ['TEST']
      ).ordered
      expect(@preprocessinator).to receive(:preprocess_partial_file).with(
        kind: :header, directives_only_filepath: raw_directives, fallback: false, filepath: 'src/Foo.h', test: 'a_test',
        flags: ['-Wall'], include_paths: ['src'], vendor_paths: ['build/vendor/ceedling'], defines: ['TEST']
      ).ordered
      expect(@preprocessinator).to receive(:generate_partial_expansion).ordered
      expect(@dependinator).to receive(:mark_fresh).with( target ).ordered

      preprocess_headers()
    end

    it 'fills in the record with every file the run wrote' do
      preprocess_headers()

      expect(@config).to have_attributes(
        raw_directives_only_filepath: raw_directives, fallback: false, assembled_filepath: target, includes: @includes,
        raw_expansion_filepath: raw_expansion, expansion_filepath: expanded_code
      )
    end

    # A missing or edited output then makes the next run stale
    it 'registers every file a later build trusts as an output, and the expansion\'s headers as dependencies, before marking fresh' do
      expect(@dependinator).to receive(:register).with( target, outputs: [includes_list, raw_directives, raw_expansion, expanded_code] ).ordered
      expect(@dependinator).to receive(:register).with( target, files: ['src/Foo.h', 'src/config.h'] ).ordered
      expect(@dependinator).to receive(:mark_fresh).with( target ).ordered

      preprocess_headers()
    end

    it 'assembles from the file\'s own text, without a directives-only run, when the toolchain lacks -fdirectives-only' do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to receive(:preprocess_partial_file).with( hash_including( directives_only_filepath: nil, fallback: true ) )
      expect(@dependinator).to receive(:register).with( target, outputs: [includes_list, raw_expansion, expanded_code] )

      preprocess_headers()

      expect(@config).to have_attributes( raw_directives_only_filepath: nil, fallback: true )
    end

    # A raw copy on disk then always means the file was preprocessed accurately
    it 'falls back for this file alone, and removes an earlier raw copy, when its directives-only run fails' do
      allow(@preprocessinator).to receive(:generate_directives_only_output).and_return( nil )

      expect(@file_wrapper).to receive(:rm_f).with( raw_directives )
      expect(@preprocessinator).to receive(:preprocess_partial_file).with( hash_including( directives_only_filepath: nil, fallback: true ) )

      preprocess_headers()

      expect(@config).to have_attributes( raw_directives_only_filepath: nil, fallback: true )
    end

    # A fresh record would vouch for a run that failed
    it 'leaves the target stale, so the next run tries again, when the full expansion fails' do
      allow(@preprocessinator).to receive(:generate_partial_expansion).and_return( nil )

      expect(@dependinator).to_not receive(:mark_fresh)

      preprocess_headers()

      expect(@config).to have_attributes( expansion_filepath: nil, raw_expansion_filepath: nil )
    end

    it 'logs the file it preprocesses at normal verbosity' do
      expect(@loginator).to receive(:log).with( 'Preprocessing partial header for a_test::Foo.h', Verbosity::NORMAL )

      preprocess_headers()
    end
  end

  context 'when fresh' do
    before(:each) do
      allow(@dependinator).to receive(:stale?).and_return( false )
      @on_disk.push( raw_directives, raw_expansion, expanded_code )
    end

    it 'runs nothing and rebuilds the record from the files the last run left' do
      expect(@preprocessinator).to_not receive(:generate_directives_only_output)
      expect(@preprocessinator).to_not receive(:preprocess_partial_file)
      expect(@preprocessinator).to_not receive(:generate_partial_expansion)
      expect(@dependinator).to_not receive(:mark_fresh)

      preprocess_headers()

      expect(@preprocessinator).to have_received(:load_includes_list).with( test: 'a_test', filepath: 'src/Foo.h' )
      expect(@config).to have_attributes(
        raw_directives_only_filepath: raw_directives, fallback: false, assembled_filepath: target, includes: @includes,
        raw_expansion_filepath: raw_expansion, expansion_filepath: expanded_code
      )
    end

    it 'recalls a file the last run preprocessed in fallback, which left no raw copy' do
      @on_disk.delete( raw_directives )

      preprocess_headers()

      expect(@config).to have_attributes( raw_directives_only_filepath: nil, fallback: true )
    end

    # The record describes what the last run made, not what this run's toolchain could make
    it 'recalls a file the last run preprocessed accurately when this run lacks -fdirectives-only' do
      allow(@configurator).to receive(:test_build_preprocess_directives_only_available).and_return( false )

      preprocess_headers()

      expect(@config).to have_attributes( raw_directives_only_filepath: raw_directives, fallback: false )
    end

    # Reconciliation needs the expanded code, and the target's record can predate it
    it 'reruns a target whose expanded code is missing' do
      @on_disk.delete( expanded_code )

      expect(@preprocessinator).to receive(:generate_partial_expansion)
      expect(@dependinator).to receive(:mark_fresh).with( target )

      preprocess_headers()
    end

    it 'logs the skip at obnoxious verbosity and counts it in the summary' do
      expect(@loginator).to receive(:log).with( 'Skipping partial header preprocessing for a_test::Foo.h', Verbosity::OBNOXIOUS )
      expect(@reportinator).to receive(:generate_skip_summary).with(
        task: 'partial header preprocessing', count: 1, noun: 'headers', reason: 'nothing changed'
      )

      preprocess_headers()
    end
  end

  it 'preprocesses stage 7\'s sources as sources' do
    source = Partials::ConfigFileInfo.new( filepath: 'src/Foo.c' )
    @state.partials_headers = []
    @state.partials_sources = [TestInvokerTypes::PartialWork.new( config: source, testable: @testable )]

    expect(@preprocessinator).to receive(:preprocess_partial_file).with( hash_including( kind: :source, filepath: 'src/Foo.c' ) )
    expect(@reportinator).to receive(:generate_skip_summary).with( hash_including( task: 'partial source preprocessing', noun: 'sources' ) )

    @preprocessinator_object.preprocess_sources( @state )
  end
end
