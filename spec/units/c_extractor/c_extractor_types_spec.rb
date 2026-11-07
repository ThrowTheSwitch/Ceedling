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
    it "stamps every function and variable with the given origin" do
      module_of( definition, declaration, variable ).stamp_origin!( :header )

      expect( [definition, declaration, variable].map( &:origin ) ).to all( eq( :header ) )
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

    it "leaves statements without an origin" do
      expect { module_of( statement ).stamp_origin!( :header ) }.not_to raise_error
      expect( statement ).not_to respond_to( :origin )
    end
  end

  context "#+" do
    it "keeps the first module's items ahead of the second's" do
      header = module_of( declaration ).stamp_origin!( :header )
      source = module_of( definition ).stamp_origin!( :source )

      expect( (header + source).element_sequence.map( &:origin ) ).to eq( [:header, :source] )
    end
  end
end

describe 'C extractor item origins' do
  it "defaults every function and variable origin to nil" do
    expect( CExtractorTypes::CFunctionDefinition.new.origin ).to be_nil
    expect( CExtractorTypes::CFunctionDeclaration.new.origin ).to be_nil
    expect( CExtractorTypes::CVariableDeclaration.new.origin ).to be_nil
  end

  it "gives a declaration a source filepath field" do
    expect( CExtractorTypes::CFunctionDeclaration.new( source_filepath: 'src/a.c' ).source_filepath ).to eq( 'src/a.c' )
  end

  it "gives a definition an expanded body field" do
    expect( CExtractorTypes::CFunctionDefinition.new( expanded_body: '{ }' ).expanded_body ).to eq( '{ }' )
  end
end
