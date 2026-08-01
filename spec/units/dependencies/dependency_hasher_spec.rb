# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'digest'
require 'ceedling/file_wrapper'
require 'ceedling/dependencies/dependency_hasher'

describe DependencyHasher do

  before(:each) do
    @file_wrapper = instance_double('FileWrapper')
    @hasher = described_class.new( { :file_wrapper => @file_wrapper } )
  end

  describe '#hash_of_file' do
    it 'returns the SHA-256 hex digest of the file content read via FileWrapper' do
      allow( @file_wrapper ).to receive(:read).with('foo.c').and_return('int main(void) {}')

      expect( @hasher.hash_of_file('foo.c') ).to eq( Digest::SHA256.hexdigest('int main(void) {}') )
    end

    it 'never touches the real filesystem -- only the injected FileWrapper' do
      expect( @file_wrapper ).to receive(:read).with('foo.c').and_return('content')
      @hasher.hash_of_file('foo.c')
    end

    it 'produces different hashes for different content' do
      allow( @file_wrapper ).to receive(:read).with('a.c').and_return('aaa')
      allow( @file_wrapper ).to receive(:read).with('b.c').and_return('bbb')

      expect( @hasher.hash_of_file('a.c') ).not_to eq( @hasher.hash_of_file('b.c') )
    end
  end

  describe '#hash_of_meta' do
    it 'returns nil for nil meta' do
      expect( @hasher.hash_of_meta( nil ) ).to be_nil
    end

    it 'returns nil for an empty Hash' do
      expect( @hasher.hash_of_meta( {} ) ).to be_nil
    end

    it 'returns a stable hash for equivalent meta regardless of key insertion order' do
      a = @hasher.hash_of_meta( { flags: ['-O2'], defines: ['FOO'] } )
      b = @hasher.hash_of_meta( { defines: ['FOO'], flags: ['-O2'] } )

      expect( a ).to eq( b )
    end

    it 'treats equivalent Symbol and String keys identically' do
      a = @hasher.hash_of_meta( { flags: ['-O2'] } )
      b = @hasher.hash_of_meta( { 'flags' => ['-O2'] } )

      expect( a ).to eq( b )
    end

    it 'is sensitive to array element order (unlike hash key order)' do
      a = @hasher.hash_of_meta( { flags: ['-O2', '-Wall'] } )
      b = @hasher.hash_of_meta( { flags: ['-Wall', '-O2'] } )

      expect( a ).not_to eq( b )
    end

    it 'distinguishes different values for the same key' do
      a = @hasher.hash_of_meta( { coverage: true } )
      b = @hasher.hash_of_meta( { coverage: false } )

      expect( a ).not_to eq( b )
    end

    it 'canonicalizes nested hashes and arrays alike' do
      a = @hasher.hash_of_meta( { toolchain: { name: 'gcc', version: '14' }, defines: ['A', 'B'] } )
      b = @hasher.hash_of_meta( { defines: ['A', 'B'], toolchain: { version: '14', name: 'gcc' } } )

      expect( a ).to eq( b )
    end

    it 'returns a valid SHA-256 hex digest' do
      expect( @hasher.hash_of_meta( { a: 1 } ) ).to match( DependencyHasher::DIGEST_RE )
    end
  end

  describe '#canonicalize' do
    it 'sorts hash keys and stringifies Symbol keys' do
      expect( @hasher.canonicalize( { b: 2, a: 1 } ) ).to eq( { 'a' => 1, 'b' => 2 } )
    end

    it 'recurses into nested hashes and arrays' do
      input = { outer: [ { z: 1, a: 2 }, 'plain' ] }
      expect( @hasher.canonicalize( input ) ).to eq(
        'outer' => [ { 'a' => 2, 'z' => 1 }, 'plain' ]
      )
    end

    it 'passes through non-collection values unchanged' do
      expect( @hasher.canonicalize( 42 ) ).to eq( 42 )
      expect( @hasher.canonicalize( 'text' ) ).to eq( 'text' )
      expect( @hasher.canonicalize( true ) ).to eq( true )
      expect( @hasher.canonicalize( nil ) ).to be_nil
    end
  end

end
