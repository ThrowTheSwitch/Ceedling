# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/module_generator/lib', __dir__ ) )

require 'module_generator_request'

describe ModuleGeneratorRequest do

  def parse(*args, patterns: true)
    return described_class.parse( args, test_prefix: 'test_', patterns: patterns )
  end

  def request(name, path_hint: nil, pattern: nil)
    return described_class.new( name: name, path_hint: path_hint, pattern: pattern )
  end

  it 'reads a bare module name' do
    expect(parse( 'MadScience' )).to eq( [request( 'MadScience' )] )
  end

  it 'reads a path hint before a colon' do
    expect(parse( 'lab:SecretLair' )).to eq( [request( 'SecretLair', path_hint: 'lab' )] )
  end

  it 'joins several ordered hints into one path' do
    expect(parse( 'lab:secret:lair' )).to eq( [request( 'lair', path_hint: 'lab/secret' )] )
  end

  it 'keeps a Windows drive letter in a hint' do
    expect(parse( 'C:/proj/lab:Foo' )).to eq( [request( 'Foo', path_hint: 'C:/proj/lab' )] )
    expect(parse( 'C:\\proj:Foo' )).to eq( [request( 'Foo', path_hint: 'C:\\proj' )] )
  end

  it 'reads an absolute Windows path without a hint as the name' do
    expect(parse( 'C:/proj/Foo' )).to eq( [request( 'C:/proj/Foo' )] )
  end

  it 'keeps a slash-separated subdirectory in the name' do
    expect(parse( 'lab:newlab/SecretLair' )).to eq( [request( 'newlab/SecretLair', path_hint: 'lab' )] )
  end

  it 'applies a pattern to every module in the call' do
    expect(parse( 'Lair', 'mch', 'Lab' )).to eq( [request( 'Lair', pattern: 'mch' ), request( 'Lab', pattern: 'mch' )] )
  end

  it 'reads a pattern in any letter case' do
    expect(parse( 'Lair', 'MCH' )).to eq( [request( 'Lair', pattern: 'mch' )] )
  end

  it 'reads the first argument as a module even when it spells a pattern' do
    expect(parse( 'src' )).to eq( [request( 'src' )] )
  end

  it 'applies each hint only to its own module' do
    expect(parse( 'lab:first', 'second' )).to eq( [request( 'first', path_hint: 'lab' ), request( 'second' )] )
  end

  it 'reads a name carrying the test prefix as a test-only module' do
    expect(parse( 'lab:test_widget' )).to eq( [request( 'widget', path_hint: 'lab', pattern: 'test' )] )
  end

  it 'reads a name that only begins with the letters of the test prefix as a module' do
    expect(parse( 'testimony' )).to eq( [request( 'testimony' )] )
  end

  it 'requires a word boundary after a test prefix that has no separator of its own' do
    requests = described_class.parse( ['TestWidget', 'Testimony'], test_prefix: 'Test' )

    expect(requests).to eq( [request( 'Widget', pattern: 'test' ), request( 'Testimony' )] )
  end

  it 'reads patterns and the test prefix as module names when patterns are off' do
    expect(parse( 'test_widget', 'mch', patterns: false )).to eq( [request( 'test_widget' ), request( 'mch' )] )
  end

  it 'returns frozen requests' do
    expect(parse( 'MadScience' ).first).to be_frozen
  end

  describe 'refusals' do
    it 'refuses a call naming no module' do
      expect { parse( nil ) }.to raise_error( CeedlingException, /names no module/ )
      expect { parse( '' ) }.to raise_error( CeedlingException, /names no module/ )
    end

    it 'refuses a hint with no module name after it' do
      expect { parse( 'lab:' ) }.to raise_error( CeedlingException, /`lab:` names no module/ )
    end

    it 'refuses a second pattern' do
      expect { parse( 'Lair', 'mch', 'mvp' ) }.to raise_error( CeedlingException, /one pattern/ )
    end

    it 'refuses a name made only of the test prefix' do
      expect { parse( 'test_' ) }.to raise_error( CeedlingException, /`test_` names no module/ )
    end
  end

end
