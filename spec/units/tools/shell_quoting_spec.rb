# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/tools/shell_quoting'

describe ShellQuoting do
  describe '.unclosed' do
    # The last case is two mistakes that balance once joined, which is why a tool's entries
    # are each read on their own
    {
      'no quotes'                             => '-g',
      'a closed double-quoted span'           => '-I"${5}"',
      'a closed single-quoted span'           => "-DNAME='a b'",
      'an escaped quote inside double quotes' => '-D"GREETING=\"hi\""',
      'an escaped quote outside quotes'       => '-DQ=\"',
      'a single quote inside double quotes'   => %q{-I"o'neil"},
      'a double quote inside single quotes'   => %q{-D'Q="'},
      'an escaped replacement operator'       => '"\${1}"',
      "a Ruby expansion's own quotes"         => %q{#{ENV['CC_FLAGS']} -c},
      'an even count of mismatched quotes'    => "-I\"a\u201d -I\"b\u201d"
    }.each do |description, text|
      it "finds nothing open in #{description}" do
        expect( ShellQuoting.unclosed( text, windows: false ) ).to be_nil
      end
    end

    {
      'an unclosed double quote'  => ['-I"src', '"'],
      'an unclosed single quote'  => ["-DNAME='a", "'"],
      'a backslash before the closing quote' => ['-I"C:\\inc\\"', '"'],
      "a straight quote closed by a typographic one" => ["-I\"${5}\u201d", '"']
    }.each do |description, (text, open)|
      it "finds #{open} open in #{description}" do
        expect( ShellQuoting.unclosed( text, windows: false ) ).to eq( open )
      end
    end

    # cmd.exe reads a single quote as an ordinary character
    it 'ignores a single quote on Windows' do
      expect( ShellQuoting.unclosed( "C:/Users/O'Brien/cc", windows: true ) ).to be_nil
    end

    it 'still finds an unclosed double quote on Windows' do
      expect( ShellQuoting.unclosed( %q{-I"o'neil}, windows: true ) ).to eq( '"' )
    end

    it 'reads text holding invalid bytes' do
      expect( ShellQuoting.unclosed( "-I\"\xFF", windows: false ) ).to eq( '"' )
    end
  end

  describe '.typographic' do
    ShellQuoting::TYPOGRAPHIC.each do |quote|
      it "finds #{quote}" do
        expect( ShellQuoting.typographic( "-I#{quote}src#{quote}" ) ).to eq( [quote] )
      end
    end

    it 'lists each distinct quote once, in order of appearance' do
      expect( ShellQuoting.typographic( "\u201ca\u201d \u201cb\u201d" ) ).to eq( ["\u201c", "\u201d"] )
    end

    it 'finds none in straight quoting' do
      expect( ShellQuoting.typographic( %q{-I"a" -D'b'} ) ).to eq( [] )
    end

    it 'reads text holding invalid bytes' do
      expect( ShellQuoting.typographic( "\xFF\u201d" ) ).to eq( ["\u201d"] )
    end
  end
end
