# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_types'

describe CExtractorTypes::CModule do
  let(:definition)  { CExtractorTypes::CFunctionDefinition.new( name: 'clamp' ) }
  let(:declaration) { CExtractorTypes::CFunctionDeclaration.new( name: 'tick' ) }
  let(:variable)    { CExtractorTypes::CVariableDeclaration.new( name: 'count' ) }
  let(:statement)   { CExtractorTypes::CStatement.new( text: '#define LIMIT 9' ) }

  def module_of(*items)
    CExtractorTypes::CModule.new(
      function_definitions:  items.grep( CExtractorTypes::CFunctionDefinition ),
      function_declarations: items.grep( CExtractorTypes::CFunctionDeclaration ),
      variable_declarations: items.grep( CExtractorTypes::CVariableDeclaration ),
      macro_definitions:     items.grep( CExtractorTypes::CStatement ),
      element_sequence:      items
    )
  end

  context "#stamp_origin!" do
    it "stamps every function with the given origin" do
      module_of( definition, declaration, variable ).stamp_origin!( :header )

      expect( [definition, declaration].map( &:origin ) ).to all( eq( :header ) )
    end

    # element_sequence references the same objects, so the generator sees the stamp in order
    it "is visible through element_sequence" do
      c_module = module_of( declaration, definition ).stamp_origin!( :source )

      expect( c_module.element_sequence.map( &:origin ) ).to eq( [:source, :source] )
    end

    it "returns the module so a merge can follow it" do
      c_module = module_of( definition )

      expect( c_module.stamp_origin!( :header ) ).to equal( c_module )
    end

    # A generated header places the source's later includes where the header's items end
    it "stamps variables and statements too" do
      module_of( variable, statement ).stamp_origin!( :header )

      expect( [variable, statement].map( &:origin ) ).to all( eq( :header ) )
    end

    it "stamps a statement that only element_sequence holds" do
      c_module = CExtractorTypes::CModule.new( type_definitions: [statement], element_sequence: [statement] )

      c_module.stamp_origin!( :source )

      expect( statement.origin ).to eq( :source )
    end
  end

  context "#+" do
    it "keeps the first module's items ahead of the second's" do
      header = module_of( declaration ).stamp_origin!( :header )
      source = module_of( definition ).stamp_origin!( :source )

      expect( (header + source).element_sequence.map( &:origin ) ).to eq( [:header, :source] )
    end
  end

  context "#remove!" do
    it "takes items out of their lists and out of element_sequence" do
      c_module = module_of( statement, definition, variable )

      c_module.remove!( [statement, variable] )

      expect( c_module.macro_definitions ).to be_empty
      expect( c_module.variable_declarations ).to be_empty
      expect( c_module.element_sequence ).to eq( [definition] )
    end

    # Two equal statements can sit in different places, and only the one given goes
    it "matches items by identity, not by equality" do
      twin     = CExtractorTypes::CStatement.new( text: '#define LIMIT 9' )
      c_module = module_of( statement, twin )

      c_module.remove!( [twin] )

      expect( c_module.element_sequence ).to contain_exactly( be( statement ) )
      expect( c_module.macro_definitions ).to contain_exactly( be( statement ) )
    end

    it "removes every one of several equal items it is given" do
      twin     = CExtractorTypes::CStatement.new( text: '#define LIMIT 9' )
      c_module = module_of( statement, twin )

      c_module.remove!( [statement, twin] )

      expect( c_module.element_sequence ).to be_empty
      expect( c_module.macro_definitions ).to be_empty
    end
  end

  context "#insert_before!" do
    it "adds items to the lists their kinds name and places them just ahead of the anchor" do
      type     = CExtractorTypes::CStatement.new( text: 'struct last { int n; };', kind: :aggregate )
      c_module = module_of( statement, definition )

      c_module.insert_before!( definition, [type, variable] )

      expect( c_module.aggregate_definitions ).to eq( [type] )
      expect( c_module.variable_declarations ).to eq( [variable] )
      expect( c_module.element_sequence ).to eq( [statement, type, variable, definition] )
    end

    it "places a statement in the list its kind names" do
      typedef  = CExtractorTypes::CStatement.new( text: 'typedef int count_t;', kind: :typedef )
      c_module = module_of( definition )

      c_module.insert_before!( definition, [typedef] )

      expect( c_module.type_definitions ).to eq( [typedef] )
      expect( c_module.aggregate_definitions ).to be_empty
    end

    it "refuses a statement whose kind names no list" do
      loose = CExtractorTypes::CStatement.new( text: 'struct s;' )

      expect { module_of.insert_before!( definition, [loose] ) }.to raise_error( ArgumentError, /CStatement of kind nil/ )
    end

    it "places items at the end when the anchor isn't in the module" do
      c_module = module_of( statement )

      c_module.insert_before!( definition, [variable] )

      expect( c_module.element_sequence ).to eq( [statement, variable] )
    end
  end
end

describe 'C extractor item origins' do
  it "defaults every origin to nil" do
    expect( CExtractorTypes::CFunctionDefinition.new.origin ).to be_nil
    expect( CExtractorTypes::CFunctionDeclaration.new.origin ).to be_nil
    expect( CExtractorTypes::CVariableDeclaration.new.origin ).to be_nil
    expect( CExtractorTypes::CStatement.new.origin ).to be_nil
  end

  it "tells a variable declared extern from one defined here" do
    expect( CExtractorTypes::CVariableDeclaration.new( decorators: ['extern', 'const'] ).extern? ).to be( true )
    expect( CExtractorTypes::CVariableDeclaration.new( decorators: ['static'] ).extern? ).to be( false )
  end

  it "gives a declaration a source filepath field" do
    expect( CExtractorTypes::CFunctionDeclaration.new( source_filepath: 'src/a.c' ).source_filepath ).to eq( 'src/a.c' )
  end

  it "gives a definition an expanded body field" do
    expect( CExtractorTypes::CFunctionDefinition.new( expanded_body: '{ }' ).expanded_body ).to eq( '{ }' )
  end
end
