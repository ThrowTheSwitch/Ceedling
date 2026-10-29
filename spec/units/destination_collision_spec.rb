# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/destination_collision'

describe DestinationCollision do
  describe '.find' do
    it 'gives each output more than one input maps to, with those inputs' do
      shared = DestinationCollision.find( ['a/x.c', 'b/x.c', 'c/y.c', 'a/x.c'] ) { |input| File.basename( input ) }

      expect(shared).to eq( 'x.c' => ['a/x.c', 'b/x.c'] )
    end

    it 'gives nothing when every input has an output of its own' do
      expect(DestinationCollision.find( ['a.c', 'b.c'] ) { |input| input }).to be_empty
    end
  end

  describe '.raise_for' do
    it 'names every input and the output they share, with a fix' do
      expect { DestinationCollision.raise_for( 'out/x.o', ['a/x.c', 'b/x.c'], 'would build to the same file' ) }
        .to raise_error( CeedlingException, '`a/x.c` and `b/x.c` would build to the same file `out/x.o`. Rename one, or move it to its own directory.' )
    end
  end
end
