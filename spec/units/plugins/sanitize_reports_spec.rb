# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'
require 'ceedling/exceptions'

$: << File.expand_path('../../../../plugins/sanitize/lib', __FILE__)
require 'sanitize_findings'
require 'sanitize_reports'

describe SanitizeReports do
  let(:finding) do
    SanitizeFindings::Finding.new(
      sanitizer: :address, kind: 'heap-buffer-overflow', file: 'src/buffer.c', line: 12, column: nil,
      message: 'heap-buffer-overflow on address 0x502000000020', text: "==13==ERROR: AddressSanitizer: heap-buffer-overflow\n"
    )
  end
  let(:records) { [{ test: 'test_buffer', finding: finding }] }

  def report(name)
    return described_class.load( [name], version: '1.2.0' ).first
  end

  describe '.load' do
    it 'loads the text report when none is configured' do
      expect(described_class.load( [], version: '1.2.0' ).map( &:extension )).to eq( ['log'] )
    end

    it 'loads each configured report once, by symbol or string in any letter case' do
      expect(described_class.load( ['JSON', :sarif, :json], version: '1.2.0' ).map( &:extension )).to eq( ['json', 'sarif'] )
    end

    it 'rejects an unknown report, listing the choices' do
      expect { described_class.load( ['html'], version: '1.2.0' ) }.to raise_error(
        CeedlingException, /:sanitize ↳ :reports entry `html` is not a report. Choose from :text, :json, :sarif./
      )
    end
  end

  it 'writes each finding\'s report as the sanitizer printed it, under its test' do
    text = report( :text ).render( :sanitize, records )

    expect(text).to include( "test_buffer: AddressSanitizer heap-buffer-overflow at src/buffer.c:12\n" )
    expect(text).to include( '==13==ERROR: AddressSanitizer: heap-buffer-overflow' )
  end

  # UBSan names every finding undefined behavior, so its message says what happened
  it 'heads a UBSan finding with its runtime error' do
    ub = SanitizeFindings::Finding.new( sanitizer: :undefined, kind: 'undefined-behavior', file: 'src/shift.c', line: 3, column: 67,
                                        message: 'left shift of 128 by 24 places cannot be represented in type \'int\'', text: '' )
    expect(described_class.headline( ub )).to eq( "UndefinedBehaviorSanitizer left shift of 128 by 24 places cannot be represented in type 'int' at src/shift.c:3" )
  end

  it 'writes each finding\'s fields as JSON, with the build context' do
    json = JSON.parse( report( :json ).render( :sanitize, records ) )

    expect(json['context']).to eq( 'sanitize' )
    expect(json['findings'].first).to include( 'test' => 'test_buffer', 'sanitizer' => 'address', 'kind' => 'heap-buffer-overflow', 'file' => 'src/buffer.c', 'line' => 12 )
  end

  it 'writes each finding as a SARIF error result, its rule the sanitizer and kind' do
    sarif  = JSON.parse( report( :sarif ).render( :sanitize, records ) )
    result = sarif['runs'].first['results'].first

    expect(sarif['version']).to eq( '2.1.0' )
    expect(result).to include( 'ruleId' => 'address/heap-buffer-overflow', 'level' => 'error' )
    expect(result['locations'].first['physicalLocation']).to eq(
      'artifactLocation' => { 'uri' => 'src/buffer.c', 'uriBaseId' => '%SRCROOT%' }, 'region' => { 'startLine' => 12 }
    )
    expect(sarif['runs'].first['tool']['driver']['rules']).to eq( [{ 'id' => 'address/heap-buffer-overflow' }] )
  end

  # A code scanning service reads an empty run as earlier findings being gone
  it 'writes the structured reports for a build without findings, and no text log' do
    expect(report( :text ).write_empty?).to eq( false )
    expect(report( :json ).write_empty?).to eq( true )
    expect(JSON.parse( report( :sarif ).render( :sanitize, [] ) )['runs'].first['results']).to eq( [] )
  end
end
