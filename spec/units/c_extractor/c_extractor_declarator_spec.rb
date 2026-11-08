# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'timeout'
require 'ceedling/c_extractor/c_extractor_declarator'

describe CExtractorDeclarator do

  context ".parenthesized" do
    def read(text)
      reading = described_class.parenthesized( text )
      reading && reading.to_h
    end

    it "reads a pointer to a function" do
      expect( read( 'int (*s_hook)(int)' ) ).to eq( name: 's_hook', follows: nil, base_type: 'int', declarator: '(*s_hook)(int)' )
    end

    it "reads an array of pointers to functions" do
      expect( read( 'int (*s_table[2])(int)' ) ).to eq( name: 's_table', follows: '[', base_type: 'int', declarator: '(*s_table[2])(int)' )
    end

    it "reads a pointer to an array" do
      expect( read( 'int (*g_row)[4]' ) ).to eq( name: 'g_row', follows: nil, base_type: 'int', declarator: '(*g_row)[4]' )
    end

    # A parameter list right after the name makes the declaration a function's
    it "reads a function returning a pointer to a function" do
      expect( read( 'int (*ticker_get(void))(int)' ) ).to eq( name: 'ticker_get', follows: '(', base_type: 'int', declarator: '(*ticker_get(void))(int)' )
    end

    it "reads a function taking and returning function pointers" do
      expect( read( 'void (*signal(int sig, void (*func)(int)))(int)' ) ).to include( name: 'signal', follows: '(' )
    end

    it "reads past qualifiers and further stars" do
      expect( read( 'int (*const k_hook)(int)' ) ).to include( name: 'k_hook', follows: nil )
      expect( read( 'int (** volatile pp)(int)' ) ).to include( name: 'pp', follows: nil )
    end

    it "reads through a nested group" do
      expect( read( 'char (*(*fpp)(int))(long)' ) ).to include( name: 'fpp', follows: nil, base_type: 'char' )
      expect( read( 'char (* const (*fpp)(int))(long)' ) ).to include( name: 'fpp', follows: nil, base_type: 'char' )
    end

    # A compiler may add its own qualifiers, and the name is the last word ahead of what ends it
    it "reads past a qualifier a compiler adds" do
      expect( read( 'int (* _Nullable np)(int)' ) ).to include( name: 'np', follows: nil )
      expect( read( 'void (* __far fp)(void)' ) ).to include( name: 'fp', follows: nil )
      expect( read( 'void (* _Nullable sigset(int, void (* _Nullable)(int)))(int)' ) ).to include( name: 'sigset', follows: '(' )
    end

    # A name in a declarator ends at the group's ')', a parameter list or an array size
    it "finds nothing in a macro's arguments that open with a pointer" do
      expect( read( 'DECLARE_THING(*p, b)' ) ).to be_nil
    end

    it "reads past a calling convention" do
      expect( read( 'void (__cdecl *on_tick)(int)' ) ).to include( name: 'on_tick', follows: nil, base_type: 'void' )
      expect( read( 'void (__stdcall*on_tock)(int)' ) ).to include( name: 'on_tock', follows: nil )
    end

    it "reads through redundant parentheses" do
      expect( read( 'int ((*p))(int)' ) ).to include( name: 'p', follows: nil, base_type: 'int' )
    end

    # A struct's body may declare function-pointer members, which belong to the struct
    it "passes over a struct body to the declarator after it" do
      expect( read( 'struct ops { int (*open)(void); } s_ops' ) ).to be_nil
      expect( read( 'struct ops { int (*open)(void); } (*make_ops)(void)' ) ).to include( name: 'make_ops' )
    end

    it "keeps pointer stars ahead of the group in the base type" do
      expect( read( 'char *(*name_of)(int)' ) ).to include( name: 'name_of', base_type: 'char *' )
    end

    it "drops a trailing semicolon" do
      expect( read( 'int (*s_hook)(int);' ) ).to include( declarator: '(*s_hook)(int)' )
    end

    # A group that doesn't open with a pointer is a parameter list or a macro's arguments
    it "skips a group that doesn't open with a pointer to find the declarator after it" do
      expect( read( '__ALIGNED(8) int (*s_hook)(int)' ) ).to include( name: 's_hook', base_type: '__ALIGNED(8) int' )
    end

    it "finds nothing in a plain declaration" do
      expect( read( 'int x' ) ).to be_nil
      expect( read( 'uint8_t buf[16]' ) ).to be_nil
      expect( read( '__ALIGNED(8) uint32_t x' ) ).to be_nil
    end

    # The parameter list is the function's own, and a pointer inside it declares a parameter
    it "finds nothing in a function declaring a function-pointer parameter" do
      expect( read( 'void ticker_register(int (*cb)(int))' ) ).to be_nil
    end

    it "finds no name in a group holding none" do
      expect( read( 'int (*)(int)' ) ).to include( name: nil )
    end
  end

  context ".without_initializer" do
    it "cuts a declaration at its initializer" do
      expect( described_class.without_initializer( 'int (*g_hook)(int) = 0;' ) ).to eq( 'int (*g_hook)(int)' )
    end

    it "leaves a declaration without an initializer whole, less its semicolon" do
      expect( described_class.without_initializer( 'int (*g_row)[4];' ) ).to eq( 'int (*g_row)[4]' )
    end

    # An array size may compare, and only a top-level '=' starts an initializer
    it "ignores an equals sign inside brackets or parentheses" do
      expect( described_class.without_initializer( 'int a[sizeof(int) == 4 ? 1 : 2] = { 0 };' ) ).to eq( 'int a[sizeof(int) == 4 ? 1 : 2]' )
    end

    # A large lookup table is common, and only its declarator need be read
    it "stops at the initializer of a large table" do
      text = 'static const uint8_t table[] = { ' + ('0x5A, ' * 200_000) + '0 };'

      result = nil
      Timeout.timeout( 2 ) { result = described_class.without_initializer( text ) }

      expect( result ).to eq( 'static const uint8_t table[]' )
    end
  end

end
