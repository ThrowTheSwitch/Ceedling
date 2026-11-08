# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/partial_source_writer'
require 'ceedling/partials/partials'
require 'ceedling/c_extractor/c_extractor_types'
require 'stringio'

describe PartialSourceWriter do
  let(:buf)      { StringIO.new }
  let(:filepath) { 'build/partials/engine_impl.c' }

  def writer(suppress_redundant_decls: true, path: filepath)
    PartialSourceWriter.new( io: buf, filepath: path, suppress_redundant_decls: suppress_redundant_decls )
  end

  def decl(signature, line_num: nil, source_filepath: nil)
    CExtractorTypes::CFunctionDeclaration.new(
      name: signature[/(\w+)\s*\(/, 1], signature: signature, line_num: line_num, source_filepath: source_filepath
    )
  end

  def func(code_block, line_num: nil, source_filepath: nil)
    Partials.manufacture_function_definition(
      name: code_block[/(\w+)\s*\(/, 1], signature: code_block[/\A[^{]*/].strip, code_block: code_block,
      line_num: line_num, source_filepath: source_filepath
    )
  end

  # The marker names the line after itself, so the line it lands on is one less
  def expect_hand_back(text)
    lines = buf.string.lines
    index = lines.index { |l| l.include?( "\"#{filepath}\"" ) }
    expect( index ).not_to be_nil
    expect( lines[index] ).to eq( "#line #{index + 2} \"#{filepath}\"\n" )
    expect( lines[index + 1] ).to eq( text )
  end

  it "writes the preamble with each include on its own line" do
    writer.preamble( ['#include "a.h"', '#include "b.h"'] )

    expect( buf.string ).to eq( "// Ceedling generated file\n#include \"a.h\"\n#include \"b.h\"\n\n" )
  end

  it "hands attribution back to this file after a located function" do
    w = writer
    w.preamble( [] )
    w.function( func( "int get(void) { return 1; }", line_num: 9, source_filepath: 'src/engine.c' ) )
    w.text( "int mode = 3;\n" )
    w.finish

    expect_hand_back( "int mode = 3;\n" )
  end

  it "hands attribution back before an unlocated function" do
    w = writer
    w.preamble( [] )
    w.function( func( "int get(void) { return 1; }", line_num: 9, source_filepath: 'src/engine.c' ) )
    w.function( func( "int put(void) { return 2; }" ) )
    w.finish

    expect_hand_back( "int put(void) { return 2; }\n" )
  end

  it "writes no hand-back without its own file path" do
    w = writer( path: nil )
    w.prototype( decl( 'int board_tick(void);', line_num: 5, source_filepath: 'src/engine.h' ) )
    w.text( "int mode = 3;\n" )
    w.finish

    expect( buf.string.scan( '#line' ).size ).to eq( 1 )
  end

  # A backslash in a #line string starts an escape sequence
  it "writes forward slashes in every line marker" do
    w = writer( path: 'build\\partials\\engine_impl.c' )
    w.prototype( decl( 'int board_tick(void);', line_num: 5, source_filepath: 'src\\engine.h' ) )
    w.text( "int mode = 3;\n" )
    w.finish

    expect( buf.string ).to include( "#line 5 \"src/engine.h\"\n" )
    expect( buf.string ).to include( "\"build/partials/engine_impl.c\"\n" )
    expect( buf.string ).not_to include( '\\' )
  end

  it "writes a function once however often it is offered" do
    w = writer
    get = func( "int get(void) { return 1; }" )
    w.function( get )
    w.function( get )

    expect( buf.string.scan( 'int get(void)' ).size ).to eq( 1 )
  end

  it "ignores a function that is not there" do
    w = writer
    w.function( nil )

    expect( buf.string ).to eq( '' )
  end

  it "separates a function from the item before it with a blank line" do
    w = writer
    w.text( "int mode = 3;\n" )
    w.function( func( "int get(void) { return 1; }" ) )

    expect( buf.string ).to eq( "int mode = 3;\n\nint get(void) { return 1; }\n\n" )
  end

  it "writes a prototype without its surrounding whitespace" do
    w = writer( suppress_redundant_decls: false )
    w.prototype( decl( "  int board_tick(void);\n" ) )

    expect( buf.string ).to eq( "int board_tick(void);\n" )
  end

  it "closes the pragma run before a function" do
    w = writer
    w.prototype( decl( 'int board_tick(void);' ) )
    w.function( func( "int get(void) { return 1; }" ) )

    expect( buf.string ).to start_with( PartialSourceWriter::REDUNDANT_DECLS_PUSH + "int board_tick(void);\n" + PartialSourceWriter::REDUNDANT_DECLS_POP )
  end
end
