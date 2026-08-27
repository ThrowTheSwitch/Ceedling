# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/encodinator'

describe 'String#clean_encoding' do
  it 'leaves plain ASCII content unchanged' do
    expect( 'int x = 0;'.clean_encoding ).to eq( 'int x = 0;' )
  end

  it 'replaces a well-formed multi-byte UTF-8 character with the default (empty) replacement' do
    # U+4F60 (你), a complete, valid 3-byte UTF-8 sequence: E4 BD A0
    full = "abc" + [0xE4, 0xBD, 0xA0].pack('C*').force_encoding('BINARY') + "def"
    expect( full.clean_encoding ).to eq( 'abcdef' )
  end

  # A "half" Unicode character: a multi-byte lead byte with missing or
  # insufficient continuation bytes, as if a real multi-byte character had
  # been clipped by a fixed-size chunk read (see
  # PreprocessinatorFileAssembler's 2048-byte guard-detection reads) or a
  # truncated copy/paste. clean_encoding's job is to never raise on this --
  # only ever to produce clean, valid ASCII/UTF-8 output.
  describe 'incomplete multi-byte sequences ("half" Unicode characters)' do
    it 'replaces a lead byte missing its only continuation byte (1 of 2 bytes present)' do
      # 'Ü' (U+00DC) is 2 bytes in UTF-8: C3 9C. Only the lead byte survives.
      half = "abc" + [0xC3].pack('C*').force_encoding('BINARY') + "def"
      expect( half.clean_encoding ).to eq( 'abcdef' )
    end

    it 'replaces a lead byte missing its final continuation byte (2 of 3 bytes present)' do
      # U+4F60 (你) is 3 bytes: E4 BD A0. The final continuation byte is missing.
      half = "abc" + [0xE4, 0xBD].pack('C*').force_encoding('BINARY') + "def"
      expect( half.clean_encoding ).to eq( 'abcdef' )
    end

    it 'replaces a lead byte with no continuation bytes at all (1 of 3 bytes present)' do
      half = "abc" + [0xE4].pack('C*').force_encoding('BINARY') + "def"
      expect( half.clean_encoding ).to eq( 'abcdef' )
    end

    it 'replaces a truncated sequence sitting at the very end of the buffer, with no trailing content' do
      at_eof = "abc" + [0xE4, 0xBD].pack('C*').force_encoding('BINARY')
      expect( at_eof.clean_encoding ).to eq( 'abc' )
    end

    it 'replaces a lone continuation byte with no lead byte at all' do
      lone_continuation = "abc" + [0xBD].pack('C*').force_encoding('BINARY') + "def"
      expect( lone_continuation.clean_encoding ).to eq( 'abcdef' )
    end

    it 'never raises, regardless of how a multi-byte sequence is truncated' do
      [[0xC3], [0xE4], [0xE4, 0xBD], [0xF0], [0xF0, 0x9F], [0xF0, 0x9F, 0x98]].each do |bytes|
        truncated = "abc" + bytes.pack('C*').force_encoding('BINARY') + "def"
        expect { truncated.clean_encoding }.not_to raise_error
      end
    end

    it 'uses the given safe_char in place of the default empty-string replacement' do
      # Each invalid byte in the truncated sequence is replaced independently
      # (one safe_char per byte, not one per whole invalid run) -- two bytes
      # in, two underscores out.
      half = "abc" + [0xE4, 0xBD].pack('C*').force_encoding('BINARY') + "def"
      expect( half.clean_encoding('_') ).to eq( 'abc__def' )
    end

    it 'returns a valid, real ASCII/UTF-8 string regardless of input' do
      half = "abc" + [0xE4, 0xBD].pack('C*').force_encoding('BINARY') + "def"
      cleaned = half.clean_encoding
      expect( cleaned.valid_encoding? ).to be(true)
      expect( cleaned.encoding ).to eq( Encoding::UTF_8 )
    end
  end

  it 'normalizes CRLF and lone CR line endings to LF' do
    expect( "a\r\nb\rc\n".clean_encoding ).to eq( "a\nb\nc\n" )
  end

  it 'raises a descriptive error only when the underlying encode call itself fails' do
    # :invalid/:undef => :replace mean a real encode failure shouldn't happen
    # in practice -- this only pins down the rescue branch's own behavior as
    # a defensive backstop, scoped to a single stubbed instance so it can't
    # affect any other string operation during this example.
    str = 'abc'
    allow(str).to receive(:encode).and_raise(EncodingError)
    expect { str.clean_encoding }.to raise_error(/can't be represented in standard ASCII/)
  end
end
