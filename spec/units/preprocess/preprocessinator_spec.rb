# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/preprocess/preprocessinator'
require 'ceedling/includes/includes'

RSpec.describe Preprocessinator do

  before :each do
    @includes_handler  = double('preprocessinator_includes_handler')
    @comment_stripper  = double('preprocessinator_comment_stripper')
    @file_assembler    = double('preprocessinator_file_assembler')
    @reconstructor     = double('preprocessinator_reconstructor')
    @file_path_utils   = double('file_path_utils')
    @tool_executor     = double('tool_executor')
    @plugin_manager    = double('plugin_manager')
    @configurator      = double('configurator')
    @loginator         = double('loginator')
    @reportinator      = double('reportinator')

    allow(@loginator).to receive(:log)
    allow(@loginator).to receive(:log_list)
    allow(@reportinator).to receive(:generate_module_progress).and_return('')
    allow(@configurator).to receive(:cmock_mock_prefix).and_return('Mock')
  end

  subject do
    Preprocessinator.new(
      preprocessinator_includes_handler: @includes_handler,
      preprocessinator_comment_stripper: @comment_stripper,
      preprocessinator_file_assembler:   @file_assembler,
      preprocessinator_reconstructor:    @reconstructor,
      file_path_utils:                   @file_path_utils,
      tool_executor:                     @tool_executor,
      plugin_manager:                    @plugin_manager,
      configurator:                      @configurator,
      loginator:                         @loginator,
      reportinator:                      @reportinator
    )
  end

  # ===========================================================================
  describe '#preprocess_file_includes_common' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    def call_it(defines: [])
      subject.send(
        :preprocess_file_includes_common,
        test:                      'test',
        filepath:                  filepath,
        directives_only_filepath:  '/build/directives_only/module.c',
        fallback:                  false,
        flags:                     [],
        include_paths:             [],
        vendor_paths:              [],
        defines:                   defines
      )
    end

    before do
      # preprocess_file_includes_common is only ever called once a caller has
      # already determined, via its own DependencyTracker target, that this
      # file/test pair is stale -- no internal freshness check to route around,
      # so extraction runs for real on every call here.
      allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return('/build/includes/module.c.yml')
      allow(@includes_handler).to receive(:write_includes_list)

      allow(@includes_handler).to receive(:extract_system_includes_preprocess).and_return([])
    end

    # Regression coverage for #1223: the gcc-based bare pass runs against an
    # isolated copy that can never open another header, so a conditional
    # #include guarded by a macro defined by an earlier #include in the same
    # file evaluates false there and is silently dropped from that pass's own
    # result. extract_bare_includes_from_text (a plain literal-text scan, no
    # conditional evaluation at all) still sees it. Reconciliation should keep
    # it once the accurate pass (user_includes here) also confirms it's real.
    it "keeps an entry the gcc bare pass missed but the text-scan bare pass and the accurate pass both found" do
      allow(@includes_handler).to receive(:extract_bare_includes).and_return(
        [ Include.new('Types.h') ]
      )
      allow(@includes_handler).to receive(:extract_bare_includes_from_text).and_return(
        [ Include.new('Types.h'), Include.new('types2.h') ]
      )
      allow(@includes_handler).to receive(:extract_user_includes_preprocess).and_return(
        [ UserInclude.new('Types.h'), UserInclude.new('types2.h') ]
      )

      result = call_it()

      expect(result.map(&:filename)).to include('types2.h')
    end

    # The union only ever adds candidates for reconcile to match against the
    # accurate pass -- it must never single-handedly promote an entry neither
    # gcc's bare pass nor the accurate pass itself ever reported.
    it "does not introduce an entry the text-scan bare pass found but the accurate pass never confirms" do
      allow(@includes_handler).to receive(:extract_bare_includes).and_return([])
      allow(@includes_handler).to receive(:extract_bare_includes_from_text).and_return(
        [ Include.new('phantom.h') ]
      )
      allow(@includes_handler).to receive(:extract_user_includes_preprocess).and_return([])

      result = call_it()

      expect(result.map(&:filename)).not_to include('phantom.h')
    end

    # Both bare sources finding the same entry must not produce a duplicate
    # (the union is deduplicated by filename before being handed to reconcile).
    it "does not duplicate an entry both bare passes agree on" do
      allow(@includes_handler).to receive(:extract_bare_includes).and_return(
        [ Include.new('Types.h') ]
      )
      allow(@includes_handler).to receive(:extract_bare_includes_from_text).and_return(
        [ Include.new('Types.h') ]
      )
      allow(@includes_handler).to receive(:extract_user_includes_preprocess).and_return(
        [ UserInclude.new('Types.h') ]
      )

      result = call_it()

      expect(result.map(&:filename)).to eq(['Types.h'])
    end

  end

  # ===========================================================================
  describe '#preprocess_partial_header_expand_macros / #preprocess_partial_source_expand_macros' do
  # ===========================================================================
  # Both public methods funnel through the same private _preprocess_partial_expand_macros.

    let(:filepath) { '/src/module.c' }

    def call_it(method: :preprocess_partial_header_expand_macros)
      subject.send(
        method,
        filepath:      filepath,
        test:          'test',
        flags:         [],
        include_paths: [],
        vendor_paths:  [],
        defines:       []
      )
    end

    before do
      allow(@file_path_utils).to receive(:form_preprocessed_file_full_expansion_filepath).and_return('/build/full_expansion/module.c')
      allow(@configurator).to receive(:tools_test_file_full_preprocessor).and_return({})
      allow(@tool_executor).to receive(:build_command_line).and_return({ options: {} })
    end

    # This is the actual bug: without boom: false, the real ToolExecutor#exec
    # (not this double) raises ShellException on a nonzero exit code before
    # the "if result[:exit_code] != 0 ... return nil" fallback below it ever
    # runs, crashing the build instead of gracefully degrading as documented.
    it "sets boom: false on the command before invoking the full preprocessor" do
      captured_command = nil
      allow(@tool_executor).to receive(:exec) do |command|
        captured_command = command
        { exit_code: 0 }
      end
      allow(@file_assembler).to receive(:collect_file_contents_from_full_expansion).and_return([])
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file)

      call_it()

      expect(captured_command[:options][:boom]).to eq(false)
    end

    it "returns nil without raising when the full preprocessor invocation fails" do
      allow(@tool_executor).to receive(:exec).and_return({ exit_code: 1 })

      result = nil
      expect { result = call_it() }.to_not raise_error
      expect(result).to be_nil
    end

    it "returns nil without raising via preprocess_partial_source_expand_macros too" do
      allow(@tool_executor).to receive(:exec).and_return({ exit_code: 1 })

      result = nil
      expect { result = call_it(method: :preprocess_partial_source_expand_macros) }.to_not raise_error
      expect(result).to be_nil
    end

    it "returns the full expansion filepath and assembles the code file on success" do
      allow(@tool_executor).to receive(:exec).and_return({ exit_code: 0 })
      allow(@file_assembler).to receive(:collect_file_contents_from_full_expansion).and_return(['expanded line'])

      captured = nil
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file) { |**kwargs| captured = kwargs }

      result = call_it()

      expect(result).to eq('/build/full_expansion/module.c')
      expect(captured[:contents]).to eq(['expanded line'])
      expect(captured[:includes]).to eq([])
      expect(captured[:extras]).to eq([])
    end

    it "reaches the same success behavior via preprocess_partial_source_expand_macros too" do
      allow(@tool_executor).to receive(:exec).and_return({ exit_code: 0 })
      allow(@file_assembler).to receive(:collect_file_contents_from_full_expansion).and_return(['expanded line'])
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file)

      result = call_it(method: :preprocess_partial_source_expand_macros)

      expect(result).to eq('/build/full_expansion/module.c')
    end

  end

  # ===========================================================================
  describe '#generate_directives_only_output' do
  # ===========================================================================

    let(:filepath) { '/src/module.c' }

    def call_it
      subject.generate_directives_only_output(
        filepath:      filepath,
        test:          'test',
        flags:         [],
        include_paths: [],
        vendor_paths:  [],
        defines:       []
      )
    end

    before do
      allow(@file_path_utils).to receive(:form_preprocessed_file_raw_directives_only_filepath).and_return('/build/directives_only/module.c')
      allow(@file_path_utils).to receive(:form_preprocessed_file_compacted_directives_only_filepath).and_return('/build/directives_only/module_compacted.c')
      allow(@configurator).to receive(:tools_test_file_directives_only_preprocessor).and_return({})
      allow(@tool_executor).to receive(:build_command_line).and_return({ options: {} })
      allow(@comment_stripper).to receive(:strip_file)
      allow(@reconstructor).to receive(:compact_file_from_expansion)
    end

    it "sets boom: false on the command before invoking the directives-only preprocessor" do
      captured_command = nil
      allow(@tool_executor).to receive(:exec) do |command|
        captured_command = command
        { exit_code: 0 }
      end

      call_it()

      expect(captured_command[:options][:boom]).to eq(false)
    end

    it "on success, strips comments, compacts the expansion, and returns the raw filepath" do
      allow(@tool_executor).to receive(:exec).and_return({ exit_code: 0 })

      result = call_it()

      expect(@comment_stripper).to have_received(:strip_file).with('/build/directives_only/module.c')
      expect(@reconstructor).to have_received(:compact_file_from_expansion).with(
        input_filepath:  '/build/directives_only/module.c',
        source_filepath: filepath,
        output_filepath: '/build/directives_only/module_compacted.c'
      )
      expect(result).to eq('/build/directives_only/module.c')
    end

    it "returns nil without stripping or compacting when the preprocessor fails" do
      allow(@tool_executor).to receive(:exec).and_return({ exit_code: 1 })

      result = call_it()

      expect(@comment_stripper).to_not have_received(:strip_file)
      expect(@reconstructor).to_not have_received(:compact_file_from_expansion)
      expect(result).to be_nil
    end

  end

  # ===========================================================================
  describe '#store_includes_list / #load_includes_list' do
  # ===========================================================================

    let(:filepath) { '/src/module.h' }

    before do
      allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return('/build/includes/module.h.yml')
    end

    it "writes includes to the path computed from filepath/test" do
      captured = nil
      allow(@includes_handler).to receive(:write_includes_list) { |path, includes| captured = [path, includes] }

      subject.store_includes_list( test: 'test', filepath: filepath, includes: [ UserInclude.new('a.h') ] )

      expect(captured[0]).to eq('/build/includes/module.h.yml')
      expect(captured[1].map(&:filename)).to eq(['a.h'])
    end

    it "loads includes from the same computed path" do
      loaded = [ UserInclude.new('a.h') ]
      allow(@includes_handler).to receive(:load_includes_list).with('/build/includes/module.h.yml').and_return(loaded)

      result = subject.load_includes_list( test: 'test', filepath: filepath )

      expect(result).to eq(loaded)
    end

  end

  # ===========================================================================
  describe '#preprocess_mockable_header_file' do
  # ===========================================================================

    let(:filepath) { '/src/module.h' }

    def call_it(extras: false)
      subject.preprocess_mockable_header_file(
        test:                      'test',
        filepath:                  filepath,
        directives_only_filepath:  '/build/directives_only/module.h',
        fallback:                  false,
        flags:                     [],
        include_paths:             [],
        vendor_paths:              [],
        defines:                   [],
        extras:                    extras
      )
    end

    before do
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return('/build/preprocessed/module.h')
      allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return('/build/includes/module.h.yml')
      allow(@includes_handler).to receive(:extract_bare_includes).and_return([])
      allow(@includes_handler).to receive(:extract_bare_includes_from_text).and_return([])
      allow(@includes_handler).to receive(:extract_user_includes_preprocess).and_return([])
      allow(@includes_handler).to receive(:extract_system_includes_preprocess).and_return([])
      allow(@includes_handler).to receive(:write_includes_list)
      allow(@file_assembler).to receive(:collect_mockable_header_file_contents).and_return([['content'], [], nil])
      allow(@file_assembler).to receive(:assemble_preprocessed_header_file)
      allow(@plugin_manager).to receive(:pre_mock_preprocess)
      allow(@plugin_manager).to receive(:post_mock_preprocess)
    end

    it "returns the preprocessed filepath" do
      expect(call_it()).to eq('/build/preprocessed/module.h')
    end

    it "fires pre_mock_preprocess before assembling and post_mock_preprocess after" do
      order = []
      allow(@plugin_manager).to receive(:pre_mock_preprocess) { order << :pre }
      allow(@file_assembler).to receive(:assemble_preprocessed_header_file) { order << :assemble }
      allow(@plugin_manager).to receive(:post_mock_preprocess) { order << :post }

      call_it()

      expect(order).to eq([:pre, :assemble, :post])
    end

    it "passes extracted contents, extras, and include guard through to assemble_preprocessed_header_file" do
      allow(@file_assembler).to receive(:collect_mockable_header_file_contents).and_return([['line1'], ['extra1'], 'MODULE_H'])

      captured = nil
      allow(@file_assembler).to receive(:assemble_preprocessed_header_file) { |**kwargs| captured = kwargs }

      call_it()

      expect(captured[:contents]).to eq(['line1'])
      expect(captured[:extras]).to eq(['extra1'])
      expect(captured[:include_guard]).to eq('MODULE_H')
      expect(captured[:filename]).to eq('module.h')
    end

  end

  # ===========================================================================
  describe '#preprocess_partial_header_file_preserve_macros / #preprocess_partial_source_file_preserve_macros' do
  # ===========================================================================

    let(:filepath) { '/src/module.h' }

    def call_it(method:, fallback:)
      subject.send(
        method,
        test:                      'test',
        filepath:                  filepath,
        directives_only_filepath:  '/build/directives_only/module.h',
        fallback:                  fallback,
        flags:                     [],
        include_paths:             [],
        vendor_paths:              [],
        defines:                   []
      )
    end

    before do
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return('/build/preprocessed/module.h')
      allow(@file_path_utils).to receive(:form_preprocessed_includes_list_filepath).and_return('/build/includes/module.h.yml')
      allow(@includes_handler).to receive(:extract_bare_includes).and_return([])
      allow(@includes_handler).to receive(:extract_bare_includes_from_text).and_return([])
      allow(@includes_handler).to receive(:extract_user_includes_preprocess).and_return([])
      allow(@includes_handler).to receive(:extract_user_includes_from_text).and_return([])
      allow(@includes_handler).to receive(:extract_system_includes_preprocess).and_return([])
      allow(@includes_handler).to receive(:extract_system_includes_from_text).and_return([])
      allow(@includes_handler).to receive(:write_includes_list)
      allow(@file_assembler).to receive(:collect_file_contents_fallback).and_return(['fallback content'])
      allow(@file_assembler).to receive(:collect_file_contents_from_directives_only_preprocessing).and_return(['directives content'])
      allow(@file_assembler).to receive(:collect_macros_and_pragmas_fallback).and_return(['macro'])
      allow(@file_assembler).to receive(:assemble_preprocessed_header_file)
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file)
    end

    it "uses the fallback content-source and re-extracts macros/pragmas when fallback: true (header)" do
      captured = nil
      allow(@file_assembler).to receive(:assemble_preprocessed_header_file) { |**kwargs| captured = kwargs }

      call_it(method: :preprocess_partial_header_file_preserve_macros, fallback: true)

      expect(@file_assembler).to have_received(:collect_file_contents_fallback)
      expect(@file_assembler).to_not have_received(:collect_file_contents_from_directives_only_preprocessing)
      expect(captured[:contents]).to eq(['fallback content'])
      expect(captured[:extras]).to eq(['macro'])
    end

    it "uses directives-only content and empty extras when fallback: false (header)" do
      captured = nil
      allow(@file_assembler).to receive(:assemble_preprocessed_header_file) { |**kwargs| captured = kwargs }

      call_it(method: :preprocess_partial_header_file_preserve_macros, fallback: false)

      expect(@file_assembler).to have_received(:collect_file_contents_from_directives_only_preprocessing)
      expect(@file_assembler).to_not have_received(:collect_file_contents_fallback)
      expect(captured[:contents]).to eq(['directives content'])
      expect(captured[:extras]).to eq([])
    end

    it "uses the fallback content-source for the source-file variant too" do
      captured = nil
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file) { |**kwargs| captured = kwargs }

      call_it(method: :preprocess_partial_source_file_preserve_macros, fallback: true)

      expect(captured[:contents]).to eq(['fallback content'])
      expect(captured[:extras]).to eq(['macro'])
    end

    it "returns the preprocessed filepath and the discovered includes" do
      preprocessed_filepath, includes = call_it(method: :preprocess_partial_header_file_preserve_macros, fallback: false)

      expect(preprocessed_filepath).to eq('/build/preprocessed/module.h')
      expect(includes).to eq([])
    end

  end

  # ===========================================================================
  describe '#preprocess_test_file' do
  # ===========================================================================

    let(:filepath) { '/test/test_module.c' }

    def call_it
      subject.preprocess_test_file(
        test:                      'test',
        filepath:                  filepath,
        directives_only_filepath:  '/build/directives_only/test_module.c',
        fallback:                  false,
        includes:                  [],
        flags:                     [],
        include_paths:             [],
        vendor_paths:              [],
        defines:                   []
      )
    end

    before do
      allow(@file_path_utils).to receive(:form_preprocessed_file_filepath).and_return('/build/preprocessed/test_module.c')
      allow(@file_assembler).to receive(:collect_test_file_contents).and_return([['content'], ['extra']])
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file)
      allow(@plugin_manager).to receive(:pre_test_preprocess)
      allow(@plugin_manager).to receive(:post_test_preprocess)
    end

    it "returns the preprocessed filepath" do
      expect(call_it()).to eq('/build/preprocessed/test_module.c')
    end

    it "fires pre_test_preprocess before assembling and post_test_preprocess after" do
      order = []
      allow(@plugin_manager).to receive(:pre_test_preprocess) { order << :pre }
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file) { order << :assemble }
      allow(@plugin_manager).to receive(:post_test_preprocess) { order << :post }

      call_it()

      expect(order).to eq([:pre, :assemble, :post])
    end

    it "does not extract includes again -- the caller already supplied them" do
      expect(@includes_handler).to_not receive(:extract_bare_includes)

      call_it()
    end

    it "passes the given includes straight through to assemble_preprocessed_code_file" do
      given_includes = [ UserInclude.new('a.h') ]

      captured = nil
      allow(@file_assembler).to receive(:assemble_preprocessed_code_file) { |**kwargs| captured = kwargs }

      subject.preprocess_test_file(
        test:                      'test',
        filepath:                  filepath,
        directives_only_filepath:  '/build/directives_only/test_module.c',
        fallback:                  false,
        includes:                  given_includes,
        flags:                     [],
        include_paths:             [],
        vendor_paths:              [],
        defines:                   []
      )

      expect(captured[:includes]).to eq(given_includes)
    end

  end

end
