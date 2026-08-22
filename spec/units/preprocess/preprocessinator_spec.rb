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

end
