# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The head rules a declaration rarely reaches through extraction. Extraction composition, in
# spec/integration/c_extractor_composition_spec.rb, covers the shapes real modules write.

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_defined_type'

describe CExtractorDefinedType do
  describe '.split' do
    it 'splits a declaration at the type it defines' do
      split = CExtractorDefinedType.split( 'static struct s { int a; } x, y;', 7 )

      expect( split.to_h ).to eq( type: 'struct s { int a; }', tag: 's', declarators: 'static x, y;' )
    end

    # A macro spelling the tag may expand to anything
    it 'names no tag when a group follows the tag' do
      expect( CExtractorDefinedType.split( 'struct TAG_OF(x) { int a; } q;', 0 ).tag ).to be_nil
    end

    it 'reads a tag past an attribute in the head' do
      expect( CExtractorDefinedType.split( 'struct __attribute__((packed)) pk { char c; } q;', 0 ).tag ).to eq 'pk'
    end

    it 'defines no type for a declaration naming one' do
      expect( CExtractorDefinedType.split( 'struct s *p = 0;', 0 ) ).to be_nil
    end

    it 'defines no type when the keyword is not where the type would start' do
      expect( CExtractorDefinedType.split( 'int x = { 1 };', 0 ) ).to be_nil
    end
  end

  describe '.names' do
    it 'gives no name to a typedef declaring several' do
      expect( CExtractorDefinedType.names( 'typedef struct { int a; } A, *PA;' ) ).to eq( tag: nil, type_name: nil )
    end
  end
end
