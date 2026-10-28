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
    # No file status by default, so every read below hashes afresh
    allow( @file_wrapper ).to receive(:stat).and_return( nil )
    @hasher = described_class.new( { :file_wrapper => @file_wrapper } )
  end

  # GH #1368: every test link hashes the libraries it links, so a large library was read
  # once per test executable on every build
  describe '#hash_of_file memo' do
    def status(size, mtime)
      return double( %q(File::Stat), size: size, mtime: mtime )
    end

    before(:each) do
      allow( @file_wrapper ).to receive(:read_binary).with('libx.a').and_return('library')
    end

    it 'hashes a file left unchanged since before the build began only once' do
      allow( @file_wrapper ).to receive(:stat).with('libx.a').and_return( status( 7, Time.now - 60 ) )

      2.times { expect( @hasher.hash_of_file('libx.a') ).to eq( Digest::SHA256.hexdigest('library') ) }

      expect( @file_wrapper ).to have_received(:read_binary).once
    end

    it 'hashes again a file whose size or modification time changed' do
      allow( @file_wrapper ).to receive(:stat).with('libx.a').and_return(
        status( 7, Time.now - 60 ), status( 8, Time.now - 60 ), status( 8, Time.now - 50 )
      )

      3.times { @hasher.hash_of_file('libx.a') }

      expect( @file_wrapper ).to have_received(:read_binary).exactly(3).times
    end

    # A file the build writes can change within one timestamp tick, unseen by its status
    it 'hashes afresh, every time, a file modified as the build began or since' do
      allow( @file_wrapper ).to receive(:stat).with('libx.a').and_return( status( 7, Time.now ) )

      2.times { @hasher.hash_of_file('libx.a') }

      expect( @file_wrapper ).to have_received(:read_binary).twice
    end
  end

  describe '#hash_of_file' do
    it 'returns the SHA-256 hex digest of the file content read via FileWrapper' do
      allow( @file_wrapper ).to receive(:read_binary).with('foo.c').and_return('int main(void) {}')

      expect( @hasher.hash_of_file('foo.c') ).to eq( Digest::SHA256.hexdigest('int main(void) {}') )
    end

    it 'never touches the real filesystem -- only the injected FileWrapper' do
      expect( @file_wrapper ).to receive(:read_binary).with('foo.c').and_return('content')
      @hasher.hash_of_file('foo.c')
    end

    it 'produces different hashes for different content' do
      allow( @file_wrapper ).to receive(:read_binary).with('a.c').and_return('aaa')
      allow( @file_wrapper ).to receive(:read_binary).with('b.c').and_return('bbb')

      expect( @hasher.hash_of_file('a.c') ).not_to eq( @hasher.hash_of_file('b.c') )
    end

    # Reads go through FileWrapper#read_binary rather than #read specifically so
    # line endings are never silently translated -- see the comment on
    # #hash_of_file. These cases pin that behavior down directly.
    describe 'line ending handling' do
      it 'reads via read_binary, not read, so no platform-dependent text-mode translation can occur' do
        expect( @file_wrapper ).to_not receive(:read)
        allow( @file_wrapper ).to receive(:read_binary).with('foo.c').and_return("a\r\nb")

        @hasher.hash_of_file('foo.c')
      end

      it 'hashes CRLF bytes exactly as read, without normalizing them to LF' do
        allow( @file_wrapper ).to receive(:read_binary).with('foo.c').and_return("a\r\nb")

        expect( @hasher.hash_of_file('foo.c') ).to eq( Digest::SHA256.hexdigest("a\r\nb") )
      end

      it 'treats CRLF and LF versions of otherwise-identical content as different files' do
        allow( @file_wrapper ).to receive(:read_binary).with('crlf.c').and_return("a\r\nb")
        allow( @file_wrapper ).to receive(:read_binary).with('lf.c').and_return("a\nb")

        expect( @hasher.hash_of_file('crlf.c') ).to_not eq( @hasher.hash_of_file('lf.c') )
      end

      it 'hashes binary content with embedded CR/LF-like bytes exactly as read' do
        binary_content = (+"\x00\x01\r\n\xFF\xFE").force_encoding( Encoding::BINARY )
        allow( @file_wrapper ).to receive(:read_binary).with('foo.bin').and_return( binary_content )

        expect( @hasher.hash_of_file('foo.bin') ).to eq( Digest::SHA256.hexdigest( binary_content ) )
      end
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
