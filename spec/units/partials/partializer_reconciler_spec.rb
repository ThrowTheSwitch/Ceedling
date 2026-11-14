# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partializer_reconciler'
require 'ceedling/c_extractor/c_extractor_types'

describe PartializerReconciler do
  before(:each) do
    @c_extractor = double("CExtractor")
    @loginator   = double("Loginator").as_null_object

    @reconciler = described_class.new( c_extractor: @c_extractor, loginator: @loginator )
  end

  # Reconciles one file's module, which holds these definitions and declarations
  def reconcile(funcs:, expansion_filepath:, name:, module_name:, file_type:, decls: [])
    @reconciler.reconcile(
      c_module: CExtractorTypes::CModule.new( function_definitions: funcs, function_declarations: decls ),
      expansion_filepath: expansion_filepath, name: name, module_name: module_name, file_type: file_type
    )
  end

  context "#reconcile" do
    def make_expanded_func(name:, signature:, decorators:, signature_stripped:, body: nil)
      CExtractorTypes::CFunctionDefinition.new(
        name:               name,
        signature:          signature,
        decorators:         decorators,
        signature_stripped: signature_stripped,
        body:               body
      )
    end

    def make_decl(name:, signature:, decorators:, signature_stripped:)
      CExtractorTypes::CFunctionDeclaration.new(
        name:               name,
        signature:          signature,
        decorators:         decorators,
        signature_stripped: signature_stripped
      )
    end

    it "replaces signature fields from expanded function when name matches" do
      func = double('func',
        name:               'helper',
        signature:          'MY_STATIC int helper(void)',
        decorators:         [],
        signature_stripped: 'int helper(void)'
      )
      allow(func).to receive(:signature=)
      allow(func).to receive(:hidden_decorators=)
      allow(func).to receive(:decorators=)
      allow(func).to receive(:signature_stripped=)
      allow(func).to receive(:expanded_body=)

      expanded_func = make_expanded_func(
        name:               'helper',
        signature:          'static int helper(void)',
        decorators:         ['static'],
        signature_stripped: 'int helper(void)'
      )
      expanded_module = CExtractorTypes::CModule.new(function_definitions: [expanded_func])

      allow(@c_extractor).to receive(:from_file)
        .with('/build/full_expansion/mod.c')
        .and_return(expanded_module)

      expect(func).to receive(:signature=).with('static int helper(void)')
      expect(func).to receive(:decorators=).with(['static'])
      expect(func).to receive(:signature_stripped=).with('int helper(void)')

      reconcile(
        funcs:                   [func],
        expansion_filepath:      '/build/full_expansion/mod.c',
        name:                    'TestMod',
        module_name:             'mod',
        file_type:               'source'
      )
    end

    it "leaves function unchanged when name is not found in expanded module" do
      func = double('func',
        name:               'missing',
        signature:          'MACRO int missing(void)',
        decorators:         [],
        signature_stripped: 'int missing(void)'
      )

      expanded_module = CExtractorTypes::CModule.new(function_definitions: [])

      allow(@c_extractor).to receive(:from_file).and_return(expanded_module)

      expect(func).not_to receive(:signature=)
      expect(func).not_to receive(:decorators=)
      expect(func).not_to receive(:signature_stripped=)

      reconcile(
        funcs:                   [func],
        expansion_filepath:      '/build/full_expansion/mod.c',
        name:                    'TestMod',
        module_name:             'mod',
        file_type:               'source'
      )
    end

    it "updates only matched functions and skips unmatched ones" do
      func_match = double('matched',
        name:               'private_func',
        signature:          'MY_STATIC void private_func(void)',
        decorators:         [],
        signature_stripped: 'void private_func(void)'
      )
      allow(func_match).to receive(:signature=)
      allow(func_match).to receive(:hidden_decorators=)
      allow(func_match).to receive(:decorators=)
      allow(func_match).to receive(:signature_stripped=)
      allow(func_match).to receive(:expanded_body=)

      func_no_match = double('unmatched', name: 'orphan')

      expanded_func = make_expanded_func(
        name:               'private_func',
        signature:          'static void private_func(void)',
        decorators:         ['static'],
        signature_stripped: 'void private_func(void)'
      )
      expanded_module = CExtractorTypes::CModule.new(function_definitions: [expanded_func])

      allow(@c_extractor).to receive(:from_file).and_return(expanded_module)

      expect(func_match).to receive(:signature=).with('static void private_func(void)')
      expect(func_match).to receive(:decorators=).with(['static'])
      expect(func_match).to receive(:signature_stripped=).with('void private_func(void)')
      expect(func_no_match).not_to receive(:signature=)
      expect(func_no_match).not_to receive(:decorators=)
      expect(func_no_match).not_to receive(:signature_stripped=)

      reconcile(
        funcs:                   [func_match, func_no_match],
        expansion_filepath:      '/build/full_expansion/mod.c',
        name:                    'TestMod',
        module_name:             'mod',
        file_type:               'source'
      )
    end

    it "handles an empty funcs list without error" do
      expanded_module = CExtractorTypes::CModule.new(function_definitions: [])
      allow(@c_extractor).to receive(:from_file).and_return(expanded_module)

      expect {
        reconcile(
          funcs:                   [],
          expansion_filepath:      '/build/full_expansion/mod.c',
          name:                    'TestMod',
          module_name:             'mod',
          file_type:               'source'
        )
      }.not_to raise_error
    end

    # The helper scan reads calls a macro hid, so it needs the body as the compiler sees it
    it "keeps each matched definition's expanded body" do
      func = CExtractorTypes::CFunctionDefinition.new(name: 'get', signature: 'int get(int v)', body: '{ return CLAMP(v); }')
      expanded = make_expanded_func(
        name: 'get', signature: 'int get(int v)', decorators: [], signature_stripped: 'int get(int v)',
        body: '{ return clamp(v); }'
      )
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_definitions: [expanded]))

      reconcile(
        funcs: [func], expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(func.expanded_body).to eq('{ return clamp(v); }')
      expect(func.body).to eq('{ return CLAMP(v); }')
    end

    # The written head can't be stripped of a decorator it doesn't spell
    it "notes the decorators the expansion finds that the written head doesn't spell" do
      hidden  = CExtractorTypes::CFunctionDefinition.new(name: 'helper', signature: 'PRIVATE int helper(void)', decorators: [])
      written = CExtractorTypes::CFunctionDefinition.new(name: 'tick', signature: 'static int tick(void)', decorators: ['static'])
      expanded = [
        make_expanded_func( name: 'helper', signature: 'static int helper(void)', decorators: ['static'], signature_stripped: 'int helper(void)' ),
        make_expanded_func( name: 'tick', signature: 'static int tick(void)', decorators: ['static'], signature_stripped: 'int tick(void)' )
      ]
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_definitions: expanded))

      reconcile(
        funcs: [hidden, written], expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(hidden.hidden_decorators).to eq(['static'])
      expect(written.hidden_decorators).to eq([])
    end

    it "notes only the decorators the written head lacks" do
      func = CExtractorTypes::CFunctionDefinition.new(name: 'tick', signature: 'static INLINE int tick(void)', decorators: ['static'])
      expanded = make_expanded_func( name: 'tick', signature: 'static inline int tick(void)', decorators: ['static', 'inline'], signature_stripped: 'int tick(void)' )
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_definitions: [expanded]))

      reconcile( funcs: [func], expansion_filepath: '/build/full_expansion/mod.c', name: 'TestMod', module_name: 'mod', file_type: 'source' )

      expect(func.hidden_decorators).to eq(['inline'])
    end

    # A carried prototype is written as the user spelled it, so only what the rules read changes
    it "reconciles a declaration's decorators and stripped signature but keeps its written signature" do
      decl = make_decl(name: 'hidden', signature: 'PRIVATE int hidden(void);', decorators: [], signature_stripped: 'PRIVATE int hidden(void);')
      expanded = make_decl(name: 'hidden', signature: 'static int hidden(void);', decorators: ['static'], signature_stripped: 'int hidden(void);')
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: [expanded]))

      reconcile(
        funcs: [], decls: [decl], expansion_filepath: '/build/full_expansion/mod.h',
        name: 'TestMod', module_name: 'mod', file_type: 'header'
      )

      expect(decl.decorators).to eq(['static'])
      expect(decl.signature_stripped).to eq('int hidden(void);')
      expect(decl.signature).to eq('PRIVATE int hidden(void);')
    end

    it "matches declarations that share a name in the order they appear" do
      first  = make_decl(name: 'tick', signature: 'API int tick(void);', decorators: [], signature_stripped: 'API int tick(void);')
      second = make_decl(name: 'tick', signature: 'LOCAL int tick(void);', decorators: [], signature_stripped: 'LOCAL int tick(void);')
      expanded = [
        make_decl(name: 'tick', signature: 'extern int tick(void);', decorators: ['extern'], signature_stripped: 'int tick(void);'),
        make_decl(name: 'tick', signature: 'static int tick(void);', decorators: ['static'], signature_stripped: 'int tick(void);')
      ]
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: expanded))

      reconcile(
        funcs: [], decls: [first, second], expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(first.decorators).to eq(['extern'])
      expect(second.decorators).to eq(['static'])
    end

    it "leaves a declaration unchanged when the expanded copy lacks it" do
      decl = make_decl(name: 'gone', signature: 'int gone(void);', decorators: [], signature_stripped: 'int gone(void);')
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new)

      reconcile(
        funcs: [], decls: [decl], expansion_filepath: '/build/full_expansion/mod.c',
        name: 'TestMod', module_name: 'mod', file_type: 'source'
      )

      expect(decl.decorators).to eq([])
      expect(decl.signature_stripped).to eq('int gone(void);')
    end

    it "lists a declaration whose decorators changed, marked as a declaration" do
      decl = make_decl(name: 'hidden', signature: 'PRIVATE int hidden(void);', decorators: [], signature_stripped: 'PRIVATE int hidden(void);')
      same = make_decl(name: 'plain', signature: 'int plain(void);', decorators: [], signature_stripped: 'int plain(void);')
      expanded = [
        make_decl(name: 'hidden', signature: 'static int hidden(void);', decorators: ['static'], signature_stripped: 'int hidden(void);'),
        make_decl(name: 'plain', signature: 'int plain(void);', decorators: [], signature_stripped: 'int plain(void);')
      ]
      allow(@c_extractor).to receive(:from_file).and_return(CExtractorTypes::CModule.new(function_declarations: expanded))

      expect(@loginator).to receive(:log_list).with(
        ['`hidden` (declaration)'],
        'Updated signatures from full expansion for Partial TestMod::mod header:',
        Verbosity::DEBUG
      )

      reconcile(
        funcs: [], decls: [decl, same], expansion_filepath: '/build/full_expansion/mod.h',
        name: 'TestMod', module_name: 'mod', file_type: 'header'
      )
    end
  end
end
