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
        'Reconciled with full expansion for Partial TestMod::mod header:',
        Verbosity::DEBUG
      )

      reconcile(
        funcs: [], decls: [decl, same], expansion_filepath: '/build/full_expansion/mod.h',
        name: 'TestMod', module_name: 'mod', file_type: 'header'
      )
    end
  end

  context "#reconcile with file-scope variables" do
    def var(name:, type:, text:, decorators: [], **fields)
      CExtractorTypes::CVariableDeclaration.new( name: name, type: type, text: text, decorators: decorators, original: "orig #{name}", line_num: 7, **fields )
    end

    def reconcile_vars(written, expanded)
      c_module = CExtractorTypes::CModule.new( variable_declarations: written, element_sequence: written.dup )
      allow(@c_extractor).to receive(:from_file).and_return( CExtractorTypes::CModule.new( variable_declarations: expanded ) )
      @reconciler.reconcile( c_module: c_module, expansion_filepath: "/build/expanded_code/mod.c", name: "TestMod", module_name: "mod", file_type: "source" )
      return c_module
    end

    it "takes every parsed field from the twin when a macro supplies the storage class" do
      written = var( name: "counter", type: "PRIVATE int", text: "PRIVATE int counter[DEPTH];", array_suffix: "[DEPTH]", origin: :source )
      twin    = var(
        name: "counter", type: "int", text: "int (*counter[4])(int) = { 0 };", decorators: ["static"], array_suffix: "",
        declarator: "(*counter[4])(int)", asm_label: "__asm__(\"c\")", line_num: 2
      )

      reconcile_vars( [written], [twin] )

      expect( written ).to have_attributes(
        decorators: ["static"], type: "int", text: "int (*counter[4])(int) = { 0 };", array_suffix: "",
        declarator: "(*counter[4])(int)", asm_label: "__asm__(\"c\")"
      )
      expect( written ).to have_attributes( original: "orig counter", line_num: 7, name: "counter", origin: :source )
    end

    it "takes an extern a macro spells" do
      written = var( name: "shared", type: "EXTERN int", text: "EXTERN int shared;" )
      twin    = var( name: "shared", type: "int", text: "int shared;", decorators: ["extern"] )

      reconcile_vars( [written], [twin] )

      expect( written.extern? ).to be( true )
    end

    # A name may be declared and then defined, and each pairs with its own twin
    it "pairs a repeated name with its twins in order" do
      written = [var( name: "g", type: "EXTERN int", text: "EXTERN int g;" ), var( name: "g", type: "int", text: "int g = 1;" )]
      twins   = [var( name: "g", type: "int", text: "int g;", decorators: ["extern"] ), var( name: "g", type: "int", text: "int g = 1;" )]

      reconcile_vars( written, twins )

      expect( written.map( &:decorators ) ).to eq( [["extern"], []] )
      expect( written.map( &:text ) ).to eq( ["int g;", "int g = 1;"] )
    end

    # A token-pasted name and a file-scope asm statement both read as nameless
    it "never pairs variables it can read no name for" do
      written = var( name: nil, type: "extern int", text: "extern int CAT(buf, 1)[4];", decorators: ["extern"] )
      twin    = var( name: nil, type: "", text: "__asm__(\".text\");" )

      reconcile_vars( [written], [twin] )

      expect( written ).to have_attributes( text: "extern int CAT(buf, 1)[4];", decorators: ["extern"] )
    end

    it "leaves alone a name the expansion holds more often" do
      written = var( name: "mode", type: "PRIVATE int", text: "PRIVATE int mode;" )
      twins   = [var( name: "mode", type: "int", text: "int mode;", decorators: ["static"] ), var( name: "mode", type: "int", text: "int mode;", decorators: ["static"] )]

      reconcile_vars( [written], twins )

      expect( written.type ).to eq( "PRIVATE int" )
    end

    it "keeps a type the written declaration already defines" do
      held    = CExtractorTypes::CStatement.new( text: "struct { int a; };", kind: :aggregate )
      other   = CExtractorTypes::CStatement.new( text: "struct { int a; };", kind: :aggregate )
      written = var( name: "s", type: "", text: "s;", defined_type: held )
      twin    = var( name: "s", type: "", text: "s;", decorators: ["static"], defined_type: other )

      c_module = reconcile_vars( [written], [twin] )

      expect( written.defined_type ).to be( held )
      expect( c_module.aggregate_definitions ).to be_empty
    end

    it "reconciles each variable of a compound declaration with its own twin, in order" do
      written = [var( name: "a", type: "PRIVATE int", text: "PRIVATE int a;" ), var( name: "b", type: "PRIVATE int", text: "PRIVATE int b;" )]
      twins   = [var( name: "a", type: "int", text: "int a;", decorators: ["static"] ), var( name: "b", type: "int", text: "int b;", decorators: ["static"] )]

      reconcile_vars( written, twins )

      expect( written.map( &:text ) ).to eq( ["int a;", "int b;"] )
    end

    # A qualifier compiles as written, so the written declaration stays
    it "leaves alone a variable whose storage class agrees, as a qualifier-only macro leaves it" do
      written = var( name: "table", type: "ROM int", text: "ROM int table;", decorators: ["static"] )
      twin    = var( name: "table", type: "int", text: "int table;", decorators: ["static", "const"] )

      reconcile_vars( [written], [twin] )

      expect( written ).to have_attributes( type: "ROM int", text: "ROM int table;", decorators: ["static"] )
    end

    # Fallback can keep both branches of a conditional, which leaves no sure pairing
    it "leaves alone a name the two copies hold a different number of times" do
      written = [var( name: "mode", type: "PRIVATE int", text: "PRIVATE int mode;" ), var( name: "mode", type: "PRIVATE long", text: "PRIVATE long mode;" )]
      twin    = var( name: "mode", type: "int", text: "int mode;", decorators: ["static"] )

      reconcile_vars( written, [twin] )

      expect( written.map( &:type ) ).to eq( ["PRIVATE int", "PRIVATE long"] )
    end

    # A macro ahead of the type hid it from the written declaration
    it "places a type the twin defines ahead of the variable, once for all its variables" do
      type    = CExtractorTypes::CStatement.new( text: "struct { int a; };", kind: :aggregate )
      written = [var( name: "s", type: "PRIVATE struct { int a; }", text: "PRIVATE struct { int a; } s, t;" ), var( name: "t", type: "PRIVATE struct { int a; }", text: "PRIVATE struct { int a; } s, t;" )]
      twins   = [var( name: "s", type: "", text: "s;", decorators: ["static"], defined_type: type ), var( name: "t", type: "", text: "t;", decorators: ["static"], defined_type: type )]

      c_module = reconcile_vars( written, twins )

      expect( c_module.aggregate_definitions ).to contain_exactly( be( type ) )
      expect( c_module.element_sequence ).to eq( [type, *written] )
      expect( written.map( &:defined_type ) ).to all( be( type ) )
    end

    it "lists each variable it reconciles" do
      written = var( name: "counter", type: "PRIVATE int", text: "PRIVATE int counter;" )
      reconcile_vars( [written], [var( name: "counter", type: "int", text: "int counter;", decorators: ["static"] )] )

      expect(@loginator).to have_received(:log_list).with( ["`counter` (variable)"], anything, Verbosity::DEBUG )
    end
  end

  context "#reconcile with a type a macro ends" do
    def type(text, tag:)
      CExtractorTypes::CStatement.new( text: text, kind: :aggregate, tag: tag )
    end

    def variable(name, defined_type, text: "#{name};")
      CExtractorTypes::CVariableDeclaration.new( name: name, type: "", text: text, defined_type: defined_type )
    end

    # The written module, whose types and variables both sit in element_sequence
    def written(types, vars)
      CExtractorTypes::CModule.new( aggregate_definitions: types, variable_declarations: vars, element_sequence: types + vars )
    end

    def reconcile_with(c_module, expanded)
      allow(@c_extractor).to receive(:from_file).and_return( expanded )
      @reconciler.reconcile( c_module: c_module, expansion_filepath: "/build/expanded_code/mod.h", name: "TestMod", module_name: "mod", file_type: "header" )
    end

    it "gives a tagged type back the macro the written text read as its variable" do
      pk       = type( "struct pk { char c; int i; };", tag: "pk" )
      macro    = variable( "PACKED", pk, text: "PACKED;" )
      c_module = written( [pk], [macro] )

      reconcile_with( c_module, CExtractorTypes::CModule.new( aggregate_definitions: [type( "struct pk { char c; int i; } __attribute__((packed));", tag: "pk" )] ) )

      expect( pk.text ).to eq( "struct pk { char c; int i; } PACKED;" )
      expect( c_module.variable_declarations ).to be_empty
      expect( c_module.element_sequence ).to eq( [pk] )
    end

    # The expansion holds the variable, and defines the type only through it
    it "keeps a variable a macro names" do
      pt       = type( "struct pt { int a; };", tag: "pt" )
      named    = variable( "MY_VAR", pt )
      c_module = written( [pt], [named] )
      twin_pt  = type( "struct pt { int a; };", tag: "pt" )

      reconcile_with( c_module, CExtractorTypes::CModule.new( aggregate_definitions: [twin_pt], variable_declarations: [variable( "g_var", twin_pt )] ) )

      expect( c_module.variable_declarations ).to eq( [named] )
      expect( pt.text ).to eq( "struct pt { int a; };" )
    end

    it "leaves an anonymous type alone" do
      anonymous = type( "struct { int a; };", tag: nil )
      c_module  = written( [anonymous], [variable( "PACKED", anonymous, text: "PACKED;" )] )

      reconcile_with( c_module, CExtractorTypes::CModule.new( aggregate_definitions: [type( "struct { int a; } __attribute__((packed));", tag: nil )] ) )

      expect( c_module.variable_declarations.size ).to eq( 1 )
    end

    it "leaves a type alone that defines more than one variable" do
      pk       = type( "struct pk { int a; };", tag: "pk" )
      c_module = written( [pk], [variable( "PACKED", pk, text: "PACKED;" ), variable( "other", pk )] )

      reconcile_with( c_module, CExtractorTypes::CModule.new( aggregate_definitions: [type( "struct pk { int a; };", tag: "pk" )] ) )

      expect( c_module.variable_declarations.size ).to eq( 2 )
      expect( pk.text ).to eq( "struct pk { int a; };" )
    end

    # The expansion holding the name settles it, whatever it defines
    it "keeps a variable the expansion also holds by name" do
      pk       = type( "struct pk { int a; };", tag: "pk" )
      c_module = written( [pk], [variable( "current", pk )] )

      reconcile_with( c_module, CExtractorTypes::CModule.new(
        aggregate_definitions: [type( "struct pk { int a; };", tag: "pk" )], variable_declarations: [variable( "current", nil )]
      ) )

      expect( c_module.variable_declarations.size ).to eq( 1 )
    end

    # A forward declaration defines nothing, so it never shows the tag defined alone
    it "keeps a variable whose tag the expansion only declares ahead" do
      pk       = type( "struct pk { int a; };", tag: "pk" )
      named    = variable( "MY_VAR", pk )
      c_module = written( [pk], [named] )
      twin_pk  = type( "struct pk { int a; };", tag: "pk" )

      reconcile_with( c_module, CExtractorTypes::CModule.new(
        aggregate_definitions: [type( "struct pk;", tag: "pk" ), twin_pk], variable_declarations: [variable( "g_var", twin_pk )]
      ) )

      expect( c_module.variable_declarations ).to eq( [named] )
    end

    # A function-like macro, as `ALIGNED(8)`, reads as a variable with no name
    it "rejoins a nameless macro while the expansion holds a nameless declaration of its own" do
      al       = type( "struct al { char c; };", tag: "al" )
      c_module = written( [al], [variable( nil, al, text: "ALIGNED(8);" )] )

      reconcile_with( c_module, CExtractorTypes::CModule.new(
        aggregate_definitions: [type( "struct al { char c; } __attribute__((aligned(8)));", tag: "al" )],
        variable_declarations: [variable( nil, nil, text: "__asm__(\".globl x\");" )]
      ) )

      expect( al.text ).to eq( "struct al { char c; } ALIGNED(8);" )
      expect( c_module.variable_declarations ).to be_empty
    end

    # `static struct pk { … } __attribute__((packed));` expands to a declaration with no variable name
    it "rejoins a macro whose expanded type a nameless declaration defines" do
      pk       = type( "struct pk { char c; int i; };", tag: "pk" )
      c_module = written( [pk], [variable( "PACKED", pk, text: "PACKED;" )] )
      twin_pk  = type( "struct pk { char c; int i; };", tag: "pk" )

      reconcile_with( c_module, CExtractorTypes::CModule.new( aggregate_definitions: [twin_pk], variable_declarations: [variable( nil, twin_pk, text: ";" )] ) )

      expect( pk.text ).to eq( "struct pk { char c; int i; } PACKED;" )
    end

    it "lists the macro it gives back to a type" do
      pk = type( "struct pk { char c; int i; };", tag: "pk" )

      reconcile_with( written( [pk], [variable( "PACKED", pk, text: "PACKED;" )] ), CExtractorTypes::CModule.new( aggregate_definitions: [type( "struct pk { char c; int i; } __attribute__((packed));", tag: "pk" )] ) )

      expect(@loginator).to have_received(:log_list).with( ["`PACKED` (type attribute of `pk`)"], anything, Verbosity::DEBUG )
    end

    # Variables after the macro read it as the start of their type. Their twins' types lack it.
    context "and variables follow" do
      def typed(name, type_text, defined_type, text:)
        CExtractorTypes::CVariableDeclaration.new( name: name, type: type_text, text: text, defined_type: defined_type )
      end

      def expanded_with(*vars, type_text: "struct pk { char c; int i; } __attribute__((packed))", decorators: [])
        twin_pk = type( type_text, tag: "pk" )
        twins   = vars.map { |name, rest| typed( name, rest, twin_pk, text: "#{name};" ).tap { |twin| twin.decorators = decorators } }
        return CExtractorTypes::CModule.new( aggregate_definitions: [twin_pk], variable_declarations: twins )
      end

      it "gives the type the macro once, and takes it from every variable" do
        pk       = type( "struct pk { char c; int i; }", tag: "pk" )
        vars     = [typed( "i1", "PACKED", pk, text: "PACKED i1;" ), typed( "i2", "PACKED", pk, text: "PACKED i2;" )]
        c_module = written( [pk], vars )

        reconcile_with( c_module, expanded_with( ["i1", ""], ["i2", ""] ) )

        expect( pk.text ).to eq( "struct pk { char c; int i; } PACKED" )
        expect( vars.map( &:type ) ).to eq( ["", ""] )
        expect( vars.map( &:text ) ).to eq( ["i1;", "i2;"] )
      end

      it "lists the macro once for a type its variables share" do
        pk   = type( "struct pk { char c; int i; }", tag: "pk" )
        vars = [typed( "i1", "PACKED", pk, text: "PACKED i1;" ), typed( "i2", "PACKED", pk, text: "PACKED i2;" )]

        reconcile_with( written( [pk], vars ), expanded_with( ["i1", ""], ["i2", ""] ) )

        expect(@loginator).to have_received(:log_list).with( ["`PACKED` (type attribute of `pk`)"], anything, Verbosity::DEBUG )
      end

      it "names a type without a tag by its first variable" do
        anonymous = type( "struct { char c; int i; }", tag: nil )
        twin      = type( "struct { char c; int i; } __attribute__((packed))", tag: nil )
        vars      = [typed( "a", "PACKED", anonymous, text: "PACKED a;" ), typed( "b", "PACKED", anonymous, text: "PACKED b;" )]

        reconcile_with( written( [anonymous], vars ), CExtractorTypes::CModule.new(
          aggregate_definitions: [twin], variable_declarations: [typed( "a", "", twin, text: "a;" ), typed( "b", "", twin, text: "b;" )]
        ) )

        expect( anonymous.text ).to eq( "struct { char c; int i; } PACKED" )
        expect(@loginator).to have_received(:log_list).with( ["`PACKED` (type attribute of the type of `a`)"], anything, Verbosity::DEBUG )
      end

      it "keeps what follows the macro in the variable's type" do
        pk  = type( "struct pk { char c; int i; }", tag: "pk" )
        gp  = typed( "gp", "PACKED *", pk, text: "PACKED *gp;" )

        reconcile_with( written( [pk], [gp] ), expanded_with( ["gp", "*"] ) )

        expect( pk.text ).to eq( "struct pk { char c; int i; } PACKED" )
        expect( [gp.type, gp.text] ).to eq( ["*", "*gp;"] )
      end

      it "ends a type its statement ends before the semicolon" do
        pk = type( "struct pk { char c; int i; };", tag: "pk" )

        reconcile_with( written( [pk], [typed( "inst", "PACKED", pk, text: "PACKED inst;" )] ), expanded_with( ["inst", ""] ) )

        expect( pk.text ).to eq( "struct pk { char c; int i; } PACKED;" )
      end

      # A macro that stands for part of the declarator, as `#define PTR *`, is not the type's
      it "leaves a variable alone whose written type doesn't end in its twin's" do
        pk = type( "struct pk { char c; int i; }", tag: "pk" )
        gp = typed( "gp", "PTR", pk, text: "PTR gp;" )

        reconcile_with( written( [pk], [gp] ), expanded_with( ["gp", "*"] ) )

        expect( [pk.text, gp.type, gp.text] ).to eq( ["struct pk { char c; int i; }", "PTR", "PTR gp;"] )
      end

      # A storage class after the brace, as `struct pk { … } PRIVATE inst;`, stays the variable's
      it "leaves a macro alone that gives the variable a decorator" do
        pk   = type( "struct pk { char c; int i; }", tag: "pk" )
        inst = typed( "inst", "PRIVATE", pk, text: "PRIVATE inst;" )

        reconcile_with( written( [pk], [inst] ), expanded_with( ["inst", ""], type_text: "struct pk { char c; int i; }", decorators: ['static'] ) )

        expect( pk.text ).to eq( "struct pk { char c; int i; }" )
      end

      # A qualifier the compiler reads ahead of an attribute leaves the expanded type as written
      it "leaves a macro alone that adds nothing after the twin's brace" do
        pk   = type( "struct pk { char c; int i; }", tag: "pk" )
        inst = typed( "inst", "VOLATILE_PACKED", pk, text: "VOLATILE_PACKED inst;" )

        reconcile_with( written( [pk], [inst] ), expanded_with( ["inst", "__attribute__((packed))"], type_text: "struct pk { char c; int i; }" ) )

        expect( [pk.text, inst.type] ).to eq( ["struct pk { char c; int i; }", "VOLATILE_PACKED"] )
      end

      it "leaves a variable alone whose written type matches its twin's" do
        pk = type( "struct pk { char c; int i; }", tag: "pk" )
        gp = typed( "gp", "*", pk, text: "*gp;" )

        reconcile_with( written( [pk], [gp] ), expanded_with( ["gp", "*"] ) )

        expect( [pk.text, gp.type] ).to eq( ["struct pk { char c; int i; }", "*"] )
      end
    end
  end
end
