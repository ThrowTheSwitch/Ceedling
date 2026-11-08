# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# What a Partial carries forward beyond the functions a test selected.
#
# A Partial's implementation source holds the selected functions. The module's code also
# relied on declarations of functions defined elsewhere and on small header helpers. These
# examples state which of those PartializerHelper#plan_carry keeps, and why. Each builds the
# module from real extractor structs, so origin and decorators read as production sets them.

require 'spec_helper'
require 'ceedling/partials/partializer_helper'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_types'

describe PartializerHelper do
  before(:each) do
    @helper = described_class.new(
      {
        :partializer_utils        => double( 'PartializerUtils' ),
        :c_extractor              => double( 'CExtractor' ),
        :c_extractor_declarations => double( 'CExtractorDeclarations' ),
        :file_path_utils          => double( 'FilePathUtils' ),
        :parsing_parcels          => double( 'ParsingParcels' ),
        :loginator                => double( 'Loginator' ).as_null_object
      }
    )
  end

  # ---- builders --------------------------------------------------------------

  def decl(signature, origin: :source, decorators: nil)
    name = signature[/(\w+)\s*\(/, 1]
    decorators ||= signature.split( /\s+/ ).take_while { |t| %w[static inline extern __inline __inline__].include?( t ) }
    CExtractorTypes::CFunctionDeclaration.new(
      name: name, signature: signature, decorators: decorators,
      signature_stripped: signature.sub( /\A(?:(?:static|inline|extern)\s+)+/, '' ), origin: origin
    )
  end

  def defn(code_block, origin: :source, expanded_body: nil, line_num: 1, source_filepath: nil)
    signature  = code_block[/\A[^{]*/].strip
    name       = signature[/(\w+)\s*\(/, 1]
    decorators = signature.split( /\s+/ ).take_while { |t| %w[static inline extern __inline __inline__].include?( t ) }
    CExtractorTypes::CFunctionDefinition.new(
      name: name, signature: signature, decorators: decorators, code_block: code_block,
      body: code_block[/\{.*\}/m], expanded_body: expanded_body, origin: origin,
      line_num: line_num, source_filepath: source_filepath || (origin == :header ? 'src/engine.h' : 'src/engine.c')
    )
  end

  def var(text, decorators: [])
    CExtractorTypes::CVariableDeclaration.new( name: text[/(\w+)\s*(?:=|;|\[)/, 1], text: text, decorators: decorators )
  end

  def invocation(text)
    CExtractorTypes::CStatement.new( text: text )
  end

  def macro(text)
    CExtractorTypes::CStatement.new( text: text )
  end

  def c_module(*items)
    CExtractorTypes::CModule.new(
      function_definitions:  items.grep( CExtractorTypes::CFunctionDefinition ),
      function_declarations: items.grep( CExtractorTypes::CFunctionDeclaration ),
      variable_declarations: items.grep( CExtractorTypes::CVariableDeclaration ),
      element_sequence:      items
    )
  end

  # Selected testable functions arrive transformed, as extract_implementation_functions returns them
  def selected(*definitions)
    definitions.map { |d| Partials.manufacture_function_definition( name: d.name, signature: d.signature_stripped, code_block: d.code_block ) }
  end

  def mocked(*names)
    names.map { |n| Partials.manufacture_function_declaration( name: n, signature: "void #{n}(void)" ) }
  end

  def plan(mod, impl: [], interface: [], fallback: false, header_guarded: true)
    @helper.plan_carry( c_module: mod, impl: impl, interface: interface, fallback: fallback, header_guarded: header_guarded )
  end

  def carried_prototypes(result)
    result.prototypes.map { |c| c.item.signature }
  end

  def carried_helpers(result)
    result.helpers.keys
  end

  # ---- externals: a module declares a function it doesn't define -------------

  context 'external functions' do
    it 'carries a prototype for a function defined elsewhere' do
      get  = defn( 'int engine_get(void) { return board_tick(); }' )
      tick = decl( 'int board_tick(void);', origin: :header )

      result = plan( c_module( tick, get ), impl: selected( get ) )

      expect( carried_prototypes( result ) ).to eq( ['int board_tick(void);'] )
      expect( result.prototypes.first.reason ).to eq( 'external: no body in module' )
    end

    # The prototype's whole job is to make this file hold the external definition, so a
    # carried prototype can't depend on a call
    it 'carries an extern inline prototype that nothing calls' do
      get   = defn( 'int engine_get(void) { return 1; }' )
      twice = decl( 'extern inline int engine_get_twice(void);' )

      result = plan( c_module( twice, get ), impl: selected( get ) )

      expect( carried_prototypes( result ) ).to eq( ['extern inline int engine_get_twice(void);'] )
    end

    it 'carries no prototype that nothing kept calls' do
      get    = defn( 'int engine_get(void) { return 1; }' )
      unused = decl( 'int board_reset(void);', origin: :header )

      expect( carried_prototypes( plan( c_module( unused, get ), impl: selected( get ) ) ) ).to be_empty
    end

    # The expanded body shows what the compiler calls. A macro that renames the call leaves no
    # reference, and a carried prototype would only meet that macro again and break.
    it 'carries no prototype whose call a macro replaced' do
      get   = defn( 'void *engine_buf(void) { return pool_alloc(4); }', expanded_body: '{ return pool_alloc_dbg((4),12); }' )
      alloc = decl( 'void *pool_alloc(unsigned n);', origin: :header )

      expect( carried_prototypes( plan( c_module( alloc, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'counts a function whose address a body takes' do
      get  = defn( 'int engine_get(void) { return register_cb(&board_tick); }' )
      tick = decl( 'int board_tick(void);', origin: :header )

      expect( carried_prototypes( plan( c_module( tick, get ), impl: selected( get ) ) ) ).to eq( ['int board_tick(void);'] )
    end

    it 'never carries a static prototype without a body' do
      get    = defn( 'int engine_get(void) { return 1; }' )
      orphan = decl( 'static int orphan(void);' )

      expect( carried_prototypes( plan( c_module( orphan, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries identical prototypes once' do
      get = defn( 'int engine_get(void) { return board_tick(); }' )
      in_header = decl( 'int board_tick(void);', origin: :header )
      in_source = decl( 'int board_tick(void);', origin: :source )

      result = plan( c_module( in_header, in_source, get ), impl: selected( get ) )

      expect( result.prototypes.map( &:item ) ).to eq( [in_header] )
    end

    it 'carries compatible prototypes written differently, each as written' do
      get = defn( 'int engine_get(void) { return board_tick(); }' )
      plain  = decl( 'int board_tick(void);', origin: :header )
      extern = decl( 'extern int board_tick(void);', origin: :source )

      expect( carried_prototypes( plan( c_module( plain, extern, get ), impl: selected( get ) ) ) )
        .to eq( ['int board_tick(void);', 'extern int board_tick(void);'] )
    end
  end

  # ---- selected functions are handled as they always were --------------------

  context 'selected functions' do
    it 'carries no prototype of a function selected to test' do
      get   = defn( 'int engine_get(void) { return 1; }' )
      proto = decl( 'int engine_get(void);', origin: :header )

      expect( carried_prototypes( plan( c_module( proto, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries no prototype of a function selected to mock' do
      get  = defn( 'int engine_get(void) { engine_log(); return 1; }' )
      log  = defn( 'void engine_log(void) { }' )
      prot = decl( 'void engine_log(void);', origin: :header )

      result = plan( c_module( prot, log, get ), impl: selected( get ), interface: mocked( 'engine_log' ) )

      expect( carried_prototypes( result ) ).to be_empty
    end

    it 'carries nothing for a selected static forward declaration' do
      helper = defn( 'static int helper(void) { return 41; }' )
      get    = defn( 'int engine_get(void) { return helper() + 1; }' )
      fwd    = decl( 'static int helper(void);' )

      result = plan( c_module( fwd, get, helper ), impl: selected( get, helper ) )

      expect( carried_prototypes( result ) ).to be_empty
      expect( carried_helpers( result ) ).to be_empty
    end
  end

  # ---- left out: the module defines it, but the test didn't select it --------

  context 'left-out functions' do
    it 'carries the prototype of a subtracted function so a test stub links' do
      poll   = defn( 'int engine_poll(void) { return 1; }' )
      report = defn( 'int engine_report(void) { return engine_poll() + 1; }' )
      proto  = decl( 'int engine_poll(void);', origin: :header )

      result = plan( c_module( proto, poll, report ), impl: selected( report ) )

      expect( carried_prototypes( result ) ).to eq( ['int engine_poll(void);'] )
      expect( result.prototypes.first.reason ).to eq( 'left out: body not selected' )
    end

    it 'carries no prototype of a left-out function nothing kept calls' do
      poll  = defn( 'int engine_poll(void) { return 1; }' )
      get   = defn( 'int engine_get(void) { return 1; }' )
      proto = decl( 'int engine_poll(void);', origin: :header )

      expect( carried_prototypes( plan( c_module( proto, poll, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries no static prototype of an unselected source function' do
      raw   = defn( 'static void raw_write(void) { }' )
      get   = defn( 'int engine_get(void) { return 1; }' )
      proto = decl( 'static void raw_write(void);', origin: :header )

      expect( carried_prototypes( plan( c_module( proto, raw, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries no inline prototype whose body was left out' do
      fast  = defn( 'int fast(void) { return 1; }' )
      get   = defn( 'int engine_get(void) { return 1; }' )
      proto = decl( 'extern inline int fast(void);' )

      expect( carried_prototypes( plan( c_module( proto, fast, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries the prototype but not the body of a plain function defined in the header' do
      plain = defn( 'int plain(void) { return 1; }', origin: :header )
      proto = decl( 'int plain(void);', origin: :header )
      get   = defn( 'int engine_get(void) { return plain(); }' )

      result = plan( c_module( proto, plain, get ), impl: selected( get ) )

      expect( carried_prototypes( result ) ).to eq( ['int plain(void);'] )
      expect( carried_helpers( result ) ).to be_empty
    end
  end

  # ---- helpers: static or inline bodies in the header --------------------------

  context 'header helpers' do
    let(:clamp) { defn( 'static inline int clamp(int v) { return v > 9 ? 9 : v; }', origin: :header, line_num: 7 ) }

    it 'carries a helper a selected body calls, with its reason' do
      get = defn( 'int engine_get(void) { return clamp(12); }' )

      result = plan( c_module( clamp, get ), impl: selected( get ) )

      expect( carried_helpers( result ) ).to eq( ['clamp'] )
      expect( result.helpers['clamp'].reason ).to eq( 'helper: referenced by `engine_get`' )
    end

    # A carried helper stays static inline and private to the implementation source
    it 'carries the helper as written, with its location' do
      get = defn( 'int engine_get(void) { return clamp(12); }' )

      helper = plan( c_module( clamp, get ), impl: selected( get ) ).helper( 'clamp' )

      expect( helper.code_block ).to eq( 'static inline int clamp(int v) { return v > 9 ? 9 : v; }' )
      expect( helper.line_num ).to eq( 7 )
      expect( helper.source_filepath ).to eq( 'src/engine.h' )
    end

    it 'carries no helper that nothing kept references' do
      get = defn( 'int engine_get(void) { return 1; }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries no prototype of a helper it does not carry' do
      fwd = decl( 'static inline int clamp(int v);', origin: :header )
      get = defn( 'int engine_get(void) { return 1; }' )

      expect( carried_prototypes( plan( c_module( fwd, clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'carries a carried helper\'s prototypes, static ones included' do
      fwd = decl( 'static inline int clamp(int v);', origin: :header )
      get = defn( 'int engine_get(void) { return clamp(12); }' )

      expect( carried_prototypes( plan( c_module( fwd, clamp, get ), impl: selected( get ) ) ) )
        .to eq( ['static inline int clamp(int v);'] )
    end

    # C99 gives a plain inline function its external definition through an extern inline
    # prototype, so that prototype travels with the helper
    it 'carries the source extern inline prototype of a plain inline helper' do
      twice = defn( 'inline int engine_get_twice(void) { return 42; }', origin: :header )
      proto = decl( 'extern inline int engine_get_twice(void);', origin: :source )
      get   = defn( 'int engine_get(void) { return engine_get_twice(); }' )

      result = plan( c_module( twice, proto, get ), impl: selected( get ) )

      expect( carried_helpers( result ) ).to eq( ['engine_get_twice'] )
      expect( carried_prototypes( result ) ).to eq( ['extern inline int engine_get_twice(void);'] )
    end

    it 'ignores a helper name inside a string literal' do
      get = defn( 'const char *engine_name(void) { return "clamp"; }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'ignores a helper name inside a character literal' do
      get = defn( "int engine_mark(void) { return 'c' + 'l'; }" )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    # A member or a local that shares a helper's name is not a use of the helper
    it 'ignores a member access with a helper\'s name' do
      size = defn( 'static inline int size(const buf_t *b) { return b->len; }', origin: :header )
      get  = defn( 'int engine_len(const buf_t *b) { return b->size + b . size; }' )

      expect( carried_helpers( plan( c_module( size, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'ignores a local variable that shares a helper\'s name' do
      get = defn( 'int engine_get(void) { int clamp = 3; return clamp; }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'does not read a logical and as taking an address' do
      get = defn( 'int engine_get(int clamp) { return 1 && clamp; }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'counts a helper whose address a body takes' do
      get = defn( 'int engine_get(void) { return apply(&clamp, 12); }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to eq( ['clamp'] )
    end

    it 'matches a helper name only as a whole word' do
      get = defn( 'int engine_get(void) { return clamp_count; }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to be_empty
    end

    it 'finds a call that a macro hides, through the expanded body' do
      get = defn( 'int engine_get(int v) { return CLAMP(v); }', expanded_body: '{ return clamp(v); }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ) ) ) ).to eq( ['clamp'] )
    end

    it 'follows helpers that call helpers' do
      bound = defn( 'static inline int bound(int v) { return clamp(v); }', origin: :header )
      get   = defn( 'int engine_get(void) { return bound(12); }' )

      result = plan( c_module( clamp, bound, get ), impl: selected( get ) )

      expect( carried_helpers( result ) ).to contain_exactly( 'bound', 'clamp' )
      expect( result.helpers['clamp'].reason ).to eq( 'helper: referenced by `bound`' )
    end

    it 'counts a reference from a variable written into the implementation source' do
      table = var( 'int (*filters[1])(int) = { clamp };' )
      get   = defn( 'int engine_get(void) { return 1; }' )

      expect( carried_helpers( plan( c_module( clamp, table, get ), impl: selected( get ) ) ) ).to eq( ['clamp'] )
    end

    it 'counts a reference from a bare macro invocation' do
      call = invocation( 'REGISTER(clamp)' )
      get  = defn( 'int engine_get(void) { return 1; }' )
      mod  = c_module( clamp, call, get )
      mod.macro_invocations << call

      expect( carried_helpers( plan( mod, impl: selected( get ) ) ) ).to eq( ['clamp'] )
    end

    it 'carries no helper selected for mocking' do
      get = defn( 'int engine_get(void) { return clamp(12); }' )

      expect( carried_helpers( plan( c_module( clamp, get ), impl: selected( get ), interface: mocked( 'clamp' ) ) ) ).to be_empty
    end

    it 'treats a static body in the source as left out, not as a helper' do
      local = defn( 'static int local(void) { return 1; }', origin: :source )
      get   = defn( 'int engine_get(void) { return local(); }' )

      expect( carried_helpers( plan( c_module( local, get ), impl: selected( get ) ) ) ).to be_empty
    end
  end

  # ---- a module header without a guard ------------------------------------------

  context 'a module header without an include guard' do
    let(:clamp) { defn( 'static inline int clamp(int v) { return v; }', origin: :header ) }

    # Another include may pull in the real header, whose helpers would then collide
    it 'carries no referenced helper and names it as skipped' do
      get = defn( 'int engine_get(void) { return clamp(1); }' )

      result = plan( c_module( clamp, get ), impl: selected( get ), header_guarded: false )

      expect( carried_helpers( result ) ).to be_empty
      expect( result.skipped.map { |s| [s.item, s.kind] } ).to eq( [['clamp', :unguarded_helper]] )
    end

    it 'names no unreferenced helper' do
      get = defn( 'int engine_get(void) { return 1; }' )

      expect( plan( c_module( clamp, get ), impl: selected( get ), header_guarded: false ).skipped ).to be_empty
    end

    it 'still carries external prototypes' do
      tick = decl( 'int board_tick(void);', origin: :header )
      get  = defn( 'int engine_get(void) { return board_tick(); }' )

      expect( carried_prototypes( plan( c_module( tick, get ), impl: selected( get ), header_guarded: false ) ) )
        .to eq( ['int board_tick(void);'] )
    end
  end

  # ---- fallback preprocessing may leave alternatives behind ---------------------

  context 'under fallback preprocessing' do
    it 'carries neither of two conflicting prototypes and names the function' do
      a   = decl( 'int board_tick(int);', origin: :header )
      b   = decl( 'long board_tick(int);', origin: :header )
      get = defn( 'int engine_get(void) { return (int)board_tick(1); }' )

      result = plan( c_module( a, b, get ), impl: selected( get ), fallback: true )

      expect( carried_prototypes( result ) ).to be_empty
      expect( result.skipped.map { |s| [s.item, s.kind] } ).to eq( [['board_tick', :prototype_conflict]] )
    end

    it 'carries compatible prototypes' do
      a   = decl( 'int board_tick(void);', origin: :header )
      b   = decl( 'extern int board_tick(void);', origin: :source )
      get = defn( 'int engine_get(void) { return board_tick(); }' )

      expect( carried_prototypes( plan( c_module( a, b, get ), impl: selected( get ), fallback: true ) ).size ).to eq( 2 )
    end

    it 'carries neither of two different bodies for a referenced helper and names it' do
      one = defn( 'static inline int clamp(int v) { return v > 9 ? 9 : v; }', origin: :header )
      two = defn( 'static inline int clamp(int v) { return v > 5 ? 5 : v; }', origin: :header )
      get = defn( 'int engine_get(void) { return clamp(12); }' )

      result = plan( c_module( one, two, get ), impl: selected( get ), fallback: true )

      expect( carried_helpers( result ) ).to be_empty
      expect( result.skipped.map { |s| [s.item, s.kind] } ).to eq( [['clamp', :helper_conflict]] )
    end

    it 'names no conflicting helper that nothing references' do
      one = defn( 'static inline int clamp(int v) { return 9; }', origin: :header )
      two = defn( 'static inline int clamp(int v) { return 5; }', origin: :header )
      get = defn( 'int engine_get(void) { return 1; }' )

      expect( plan( c_module( one, two, get ), impl: selected( get ), fallback: true ).skipped ).to be_empty
    end

    # Expansion is unreliable under fallback, so a macro definition's text counts as kept code
    it 'finds a helper named only in a macro definition' do
      clamp = defn( 'static inline int clamp(int v) { return v; }', origin: :header )
      get   = defn( 'int engine_get(int v) { return CLAMP(v); }' )
      mod   = c_module( clamp, get )
      mod.macro_definitions << macro( '#define CLAMP(x) clamp(x)' )

      expect( carried_helpers( plan( mod, impl: selected( get ), fallback: true ) ) ).to eq( ['clamp'] )
      expect( carried_helpers( plan( mod, impl: selected( get ), fallback: false ) ) ).to be_empty
    end
  end

  # ---- the running example from the design ---------------------------------------

  it 'plans the running example' do
    board_count = var( 'int board_count;', decorators: ['extern'] )
    tick        = decl( 'int board_tick(void);', origin: :header )
    raw_proto   = decl( 'static void raw_write(void);', origin: :header )
    clamp       = defn( 'static inline int clamp(int v) { return v > 9 ? 9 : v; }', origin: :header )
    log_raw     = defn( 'static inline void log_raw(void) { raw_write(); }', origin: :header )
    get_proto   = decl( 'int engine_get(void);', origin: :header )
    poll_proto  = decl( 'int engine_poll(void);', origin: :header )
    twice       = decl( 'extern inline int engine_get_twice(void);' )
    raw         = defn( 'static void raw_write(void) { }' )
    get         = defn( 'int engine_get(void) { return clamp(board_tick()); }' )
    poll        = defn( 'int engine_poll(void) { return engine_get(); }' )

    mod = c_module( board_count, tick, raw_proto, clamp, log_raw, get_proto, poll_proto, twice, raw, get, poll )
    result = plan( mod, impl: selected( get ) )

    expect( carried_prototypes( result ) ).to contain_exactly(
      'int board_tick(void);', 'extern inline int engine_get_twice(void);'
    )
    expect( carried_helpers( result ) ).to eq( ['clamp'] )
    expect( result.skipped ).to be_empty
  end
end

describe Partials::CarryPlan do
  let(:proto) { CExtractorTypes::CFunctionDeclaration.new( name: 'tick', signature: 'int tick(void);' ) }

  # The generator walks element_sequence, which holds the very objects the plan chose
  it 'recognizes a carried prototype by identity, not by equal content' do
    plan = described_class.new
    plan.add_prototype( proto, 'external: no body in module' )

    expect( plan.prototype?( proto ) ).to be( true )
    expect( plan.prototype?( proto.dup ) ).to be( false )
  end

  it 'finds a prototype among many without comparing content' do
    plan   = described_class.new
    protos = Array.new( 500 ) { |i| CExtractorTypes::CFunctionDeclaration.new( name: "f#{i}", signature: "int f#{i}(void);" ) }
    protos.each { |d| plan.add_prototype( d, 'external: no body in module' ) }

    expect( protos.all? { |d| plan.prototype?( d ) } ).to be( true )
    expect( plan.prototype?( protos.first.dup ) ).to be( false )
  end

  it 'records a prototype once' do
    plan = described_class.new
    2.times { plan.add_prototype( proto, 'external: no body in module' ) }

    expect( plan.prototypes.size ).to eq( 1 )
  end

  it 'keeps the first reason for a helper' do
    plan   = described_class.new
    helper = Partials.manufacture_function_definition( name: 'clamp', signature: 'int clamp(int v)', code_block: '' )
    plan.add_helper( helper, 'helper: referenced by `a`' )
    plan.add_helper( helper, 'helper: referenced by `b`' )

    expect( plan.helpers['clamp'].reason ).to eq( 'helper: referenced by `a`' )
    expect( plan.helper( 'clamp' ) ).to equal( helper )
    expect( plan.helper( 'other' ) ).to be_nil
  end

  it 'records a skipped name once per kind' do
    plan = described_class.new
    2.times { plan.skip( 'clamp', :unguarded_helper ) }

    expect( plan.skipped.map { |s| [s.item, s.kind] } ).to eq( [['clamp', :unguarded_helper]] )
  end
end
