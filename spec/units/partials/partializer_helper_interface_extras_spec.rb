# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# What a mock-only Partial keeps of its real header beyond the functions the test mocks.
#
# A mocked Partial's interface header takes the real header's place wherever generated code
# includes it, so what the real header supplied besides the mocked functions has to come along
# in the extras header the interface includes. These examples state which of a module's items
# PartializerHelper#plan_interface_extras keeps, and which it withholds.

require 'spec_helper'
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_types'

EXTRAS_KEYWORDS = %w[static inline extern const __inline __inline__].freeze

describe PartializerHelper do
  before(:each) do
    @helper = described_class.new(
      {
        :partializer_utils        => double( 'PartializerUtils' ),
        :c_extractor_declarations => double( 'CExtractorDeclarations' ),
        :parsing_parcels          => double( 'ParsingParcels' ),
        :loginator                => double( 'Loginator' ).as_null_object
      }
    )
  end

  # ---- builders --------------------------------------------------------------

  def decl(signature, origin: :header)
    name = signature[/(\w+)\s*\(/, 1]
    CExtractorTypes::CFunctionDeclaration.new(
      name: name, signature: signature, decorators: signature.split( /\s+/ ).take_while { |t| EXTRAS_KEYWORDS.include?( t ) },
      signature_stripped: signature.sub( /\A(?:(?:static|inline|extern)\s+)+/, '' ), origin: origin
    )
  end

  def defn(code_block, origin: :header, expanded_body: nil)
    signature = code_block[/\A[^{]*/].strip
    CExtractorTypes::CFunctionDefinition.new(
      name: signature[/(\w+)\s*\(/, 1], signature: signature, code_block: code_block, body: code_block[/\{.*\}/m],
      decorators: signature.split( /\s+/ ).take_while { |t| EXTRAS_KEYWORDS.include?( t ) }, origin: origin, expanded_body: expanded_body
    )
  end

  def var(text, decorators: [], origin: :header, promoted_from: nil, name: nil, expanded_text: nil)
    CExtractorTypes::CVariableDeclaration.new(
      name: name || text[/(\w+)\s*(?:=|;|\[)/, 1], text: text, decorators: decorators, origin: origin, promoted_from: promoted_from,
      expanded_text: expanded_text
    )
  end

  def macro(text)
    CExtractorTypes::CStatement.new( text: text, kind: :macro, origin: :header )
  end

  def c_module(*items)
    CExtractorTypes::CModule.new(
      function_definitions:  items.grep( CExtractorTypes::CFunctionDefinition ),
      function_declarations: items.grep( CExtractorTypes::CFunctionDeclaration ),
      variable_declarations: items.grep( CExtractorTypes::CVariableDeclaration ),
      macro_definitions:     items.grep( CExtractorTypes::CStatement ),
      element_sequence:      items
    )
  end

  def mocked(*names)
    names.map { |n| Partials.manufacture_function_declaration( name: n, signature: "int #{n}(void)" ) }
  end

  def plan(mod, interface: [], fallback: false, header_guarded: true)
    @helper.plan_interface_extras( c_module: mod, interface: interface, fallback: fallback, header_guarded: header_guarded )
  end

  # ---- functions --------------------------------------------------------------

  context 'functions' do
    it 'keeps a header helper the mock leaves out, and leaves out the one it mocks' do
      twice = defn( 'static inline int twice(int x) { return 2 * x; }' )
      read  = defn( 'static inline int read(void) { return -1; }' )

      extras = plan( c_module( twice, read ), interface: mocked( 'read' ) )

      expect( extras.items ).to eq( [twice] )
    end

    it "keeps a kept helper's prototype ahead of it" do
      proto = decl( 'static inline int twice(int x);' )
      twice = defn( 'static inline int twice(int x) { return 2 * x; }' )

      expect( plan( c_module( proto, twice ) ).items ).to eq( [proto, twice] )
    end

    # A caller may need a function the mock doesn't select, defined somewhere else
    it 'keeps a plain prototype the mock leaves out' do
      init = decl( 'int init(void);' )

      expect( plan( c_module( init, decl( 'int read(void);' ) ), interface: mocked( 'read' ) ).items ).to eq( [init] )
    end

    # A static prototype with no body here promises a definition no file of the test holds
    it 'leaves out a static prototype of a function with no body' do
      expect( plan( c_module( decl( 'static int port(void);' ) ) ).items ).to eq( [] )
    end

    it "leaves out the source's functions" do
      helper = defn( 'static int adjust(int v) { return v + 1; }', origin: :source )

      expect( plan( c_module( helper ) ).items ).to eq( [] )
    end

    it 'keeps one copy of a helper fallback preprocessing found twice alike' do
      first  = defn( 'static inline int twice(int x) { return 2 * x; }' )
      second = defn( 'static inline int twice(int x) { return 2 * x; }' )

      expect( plan( c_module( first, second ), fallback: true ).items ).to eq( [first] )
    end

    it 'leaves out a helper fallback preprocessing found with two different bodies' do
      first  = defn( 'static inline int twice(int x) { return 2 * x; }' )
      second = defn( 'static inline int twice(int x) { return x + x + 1; }' )

      expect( plan( c_module( first, second ), fallback: true ).items ).to eq( [] )
    end
  end

  # ---- variables --------------------------------------------------------------

  context 'variables' do
    it 'keeps a header static variable and an extern declaration' do
      table = var( 'int table[] = { 1, 2 };', decorators: ['static', 'const'] )
      count = var( 'int count;', decorators: ['extern'] )

      expect( plan( c_module( table, count ) ).items ).to eq( [table, count] )
    end

    # Every file including the extras header would define it again
    it 'leaves out a header definition without static' do
      expect( plan( c_module( var( 'int total = 1;' ) ) ).items ).to eq( [] )
    end

    it "leaves out the source's variables" do
      expect( plan( c_module( var( 'int level;', decorators: ['static'], origin: :source ) ) ).items ).to eq( [] )
    end

    it 'keeps the promoted statics of a helper it keeps, and not those of a helper the mock selects' do
      kept_static = var( 'int partial_twice_calls;', decorators: ['static'], promoted_from: 'twice' )
      twice       = defn( 'static inline int twice(int x) { return 2 * x; }' )
      mock_static = var( 'int partial_read_calls;', decorators: ['static'], promoted_from: 'read' )
      read        = defn( 'static inline int read(void) { return -1; }' )

      extras = plan( c_module( kept_static, twice, mock_static, read ), interface: mocked( 'read' ) )

      expect( extras.items ).to eq( [kept_static, twice] )
    end
  end

  # ---- fallback preprocessing ------------------------------------------------------

  # Fallback keeps both sides of a conditional, so a name can arrive twice
  context 'fallback preprocessing' do
    # A tentative definition and the definition that initializes it are both C
    it 'keeps every declaration of a static variable outside fallback' do
      tentative = var( 'int port_x;', decorators: ['static'] )
      defined   = var( 'int port_x = 5;', decorators: ['static'] )

      expect( plan( c_module( tentative, defined ) ).items ).to eq( [tentative, defined] )
    end

    # A tentative definition is C beside the definition that initializes it
    it 'keeps a tentative definition beside the initialized one' do
      tentative = var( 'int port_x;', decorators: ['static'] )
      defined   = var( 'int port_x = 5;', decorators: ['static'] )

      expect( plan( c_module( tentative, defined ), fallback: true ).items ).to eq( [tentative, defined] )
    end

    it 'leaves out tentative definitions declared differently' do
      long  = var( 'unsigned long port_acc;', decorators: ['static'] )
      short = var( 'unsigned short port_acc;', decorators: ['static'] )

      expect( plan( c_module( long, short ), fallback: true ).items ).to eq( [] )
    end

    it 'leaves out a tentative definition declared unlike the initialized one' do
      tentative = var( 'int port_x;', decorators: ['static'] )
      defined   = var( 'int port_x = 5;', decorators: ['static', 'const'] )

      expect( plan( c_module( tentative, defined ), fallback: true ).items ).to eq( [] )
    end

    it 'keeps one copy of a static variable found twice alike' do
      first  = var( 'int gain = 1;', decorators: ['static', 'const'] )
      second = var( 'int gain = 1;', decorators: ['static', 'const'] )

      expect( plan( c_module( first, second ), fallback: true ).items ).to eq( [first] )
    end

    it 'leaves out a static variable found twice with different definitions' do
      first  = var( 'int gain = 1;', decorators: ['static', 'const'] )
      second = var( 'int gain = 2;', decorators: ['static', 'const'] )

      expect( plan( c_module( first, second ), fallback: true ).items ).to eq( [] )
    end

    it 'leaves out a plain prototype found twice with different signatures' do
      expect( plan( c_module( decl( 'int init(void);' ), decl( 'long init(void);' ) ), fallback: true ).items ).to eq( [] )
    end

    # A helper calling a function whose prototype stays behind wouldn't compile
    it 'leaves out a helper calling a function whose prototypes conflict' do
      twice = defn( 'static inline int port_twice(void) { return 2 * (int)port_mode(); }' )

      extras = plan( c_module( decl( 'unsigned long port_mode(void);' ), decl( 'unsigned short port_mode(void);' ), twice ), fallback: true )

      expect( extras.items ).to eq( [] )
    end
  end

  # ---- names a macro rewrites ------------------------------------------------------

  # The interface writes every macro ahead of the extras, so a function-like macro of the
  # same name would rewrite the prototype. Calls go through the macro anyway.
  # An object-like macro of a function's name renames the prototype into one callers still reach
  it 'keeps a prototype an object-like macro of its name renames' do
    reg = decl( 'int read_reg(void);' )

    expect( plan( c_module( reg, macro( '#define read_reg read_reg_v2' ) ) ).items ).to eq( [reg] )
  end

  it 'leaves out a prototype a function-like macro of the same name rewrites' do
    alloc = decl( 'void *port_alloc(unsigned n);' )
    dbg   = decl( 'void *port_alloc_dbg(unsigned n, int line);' )

    extras = plan( c_module( alloc, macro( '#define port_alloc(n) port_alloc_dbg((n), __LINE__)' ), dbg ) )

    expect( extras.items ).to eq( [dbg] )
  end

  # ---- what a test leaves undefined --------------------------------------------------

  # GCC emits an unused static variable or non-inline static function at -O0, so one naming a
  # function no file of the test defines fails the link. It stays behind, as it would have
  # without the extras.
  context 'a function the mock leaves undefined' do
    def port_module(*items)
      c_module( decl( 'int port_a(void);' ), decl( 'int port_read(void);' ), *items )
    end

    it 'leaves out a static variable naming it' do
      handlers = var( 'port_fn_t port_handlers[] = { port_a };', decorators: ['static', 'const'] )

      expect( plan( port_module( handlers ), interface: mocked( 'port_read' ) ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    it 'leaves out a non-inline static helper calling it, and keeps an inline one' do
      sum   = defn( 'static int port_sum(void) { return port_a() + 1; }' )
      twice = defn( 'static inline int port_twice(void) { return 2 * port_a(); }' )

      extras = plan( port_module( sum, twice ), interface: mocked( 'port_read' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a', 'port_twice'] )
    end

    # A body naming an item the extras leave out wouldn't compile, used or not
    it 'leaves out what names an item it left out' do
      sum   = defn( 'static int port_sum(void) { return port_a() + 1; }' )
      twice = defn( 'static inline int port_twice(void) { return 2 * port_sum(); }' )
      table = var( 'port_fn_t port_table[] = { port_twice };', decorators: ['static', 'const'] )

      expect( plan( port_module( sum, twice, table ), interface: mocked( 'port_read' ) ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    # A promoted static is data at file scope, which GCC emits even where the helper is unused
    it 'leaves out an inline helper whose promoted static names it' do
      promoted = var( 'int (*partial_port_h_cb)(void) = port_a;', decorators: ['static'], promoted_from: 'port_h', name: 'partial_port_h_cb' )
      helper   = defn( 'static inline int port_h(void) { return partial_port_h_cb(); }' )

      expect( plan( port_module( promoted, helper ), interface: mocked( 'port_read' ) ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    it 'leaves out what names a helper its promoted static took along' do
      promoted = var( 'int (*partial_port_h_cb)(void) = port_a;', decorators: ['static'], promoted_from: 'port_h', name: 'partial_port_h_cb' )
      helper   = defn( 'static inline int port_h(void) { return 1; }' )
      caller   = defn( 'static inline int port_g(void) { return port_h(); }' )

      expect( plan( port_module( promoted, helper, caller ), interface: mocked( 'port_read' ) ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    # A macro from another header, token pasting and stringizing show only after expansion
    it "reads an initializer's names as the expansion spells them" do
      pasted  = var( 'port_fn_t port_pasted[] = { E(a) };', decorators: ['static', 'const'], expanded_text: 'port_fn_t port_pasted[] = { port_a };' )
      strings = var( 'const char *port_names[] = { NAME(port_a) };', decorators: ['static'], expanded_text: 'const char *port_names[] = { "port_a" };' )

      extras = plan( port_module( pasted, strings ), interface: mocked( 'port_read' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a', 'port_names'] )
    end

    # Fallback may pair a variable with the other side of a conditional, or not at all, so the
    # written text counts too. A doubtful item stays behind, as without the extras.
    it 'reads names from both the written and the expanded text' do
      table = var( 'port_fn_t port_table[] = { port_a };', decorators: ['static', 'const'], expanded_text: 'port_fn_t port_table[] = { port_read };' )

      expect( plan( port_module( table ), interface: mocked( 'port_read' ), fallback: true ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    it "reads a helper's names from its expanded body" do
      helper = defn( 'static int port_h(void) { return HANDLER(); }', expanded_body: '{ return port_a(); }' )

      expect( plan( port_module( helper ), interface: mocked( 'port_read' ) ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    it 'reads a name a macro hides through another macro' do
      handlers = var( 'port_fn_t port_handlers[] = { PORT_FIRST };', decorators: ['static', 'const'] )

      extras = plan( port_module( macro( '#define PORT_FIRST PORT_A' ), macro( '#define PORT_A port_a' ), handlers ), interface: mocked( 'port_read' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a'] )
    end

    # A wrong guess at a local could hide an item left behind, which no file could then compile
    it 'reads a name a helper body uses even where it reads like a declaration' do
      table = var( 'port_fn_t port_table[] = { port_a };', decorators: ['static', 'const'] )
      first = defn( 'static inline int port_first(int i) { return port_mix(i * port_table[0](), i); }' )

      expect( plan( port_module( table, first ), interface: mocked( 'port_read' ) ).items.map( &:name ) ).to eq( ['port_a'] )
    end

    it 'reads a name a macro hides' do
      handlers = var( 'port_fn_t port_handlers[] = { PORT_HANDLER };', decorators: ['static', 'const'] )

      extras = plan( port_module( macro( '#define PORT_HANDLER port_a' ), handlers ), interface: mocked( 'port_read' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a'] )
    end

    # A string, a comment or a member access only reads like a use
    it 'keeps an item whose string, comment or member access spells the name' do
      names  = var( 'const char *port_names[] = { "port_a" };', decorators: ['static'] )
      helper = defn( 'static int port_h(struct port *p) { /* not port_a */ return p->port_a; }' )

      extras = plan( port_module( names, helper ), interface: mocked( 'port_read' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a', 'port_names', 'port_h'] )
    end

    it 'keeps an item naming a function that only starts with the name' do
      table = var( 'port_fn_t port_table[] = { port_ab };', decorators: ['static', 'const'] )

      extras = plan( port_module( decl( 'int port_ab(void);' ), table ), interface: mocked( 'port_read', 'port_ab' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a', 'port_table'] )
    end

    it 'keeps a static variable naming a mocked function or a kept helper' do
      twice = defn( 'static inline int port_twice(int x) { return 2 * x; }' )
      table = var( 'port_fn_t port_table[] = { port_read, port_twice };', decorators: ['static', 'const'] )

      extras = plan( port_module( twice, table ), interface: mocked( 'port_read' ) )

      expect( extras.items.map( &:name ) ).to eq( ['port_a', 'port_twice', 'port_table'] )
    end
  end

  # ---- a header without an include guard ---------------------------------------

  # The real header may still arrive through another include, where a second copy collides
  context 'a header without an include guard' do
    it 'withholds its helpers and static variables, and keeps its declarations' do
      twice = defn( 'static inline int twice(int x) { return 2 * x; }' )
      table = var( 'int table[] = { 1, 2 };', decorators: ['static', 'const'] )
      count = var( 'int count;', decorators: ['extern'] )
      init  = decl( 'int init(void);' )

      extras = plan( c_module( twice, table, count, init ), header_guarded: false )

      expect( extras.items ).to eq( [count, init] )
      expect( extras.withheld ).to eq( [twice, table] )
    end
  end

  it 'reads names in code, not in strings or comments' do
    expect( @helper.names_in( 'x = "port_a"; /* port_b */ port_c();' ) ).to eq( Set['x', 'port_c'] )
  end

  it 'is empty for a header holding only what the mock selects' do
    expect( plan( c_module( decl( 'int read(void);' ) ), interface: mocked( 'read' ) ) ).to be_empty
  end
end
