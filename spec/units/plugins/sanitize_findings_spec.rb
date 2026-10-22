# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

$: << File.expand_path('../../../../plugins/sanitize/lib', __FILE__)
require 'sanitize_findings'

# The reports are real output: GCC 14 on Linux and Apple Clang 15 on macOS
describe SanitizeFindings do
  def report(name)
    File.read( File.expand_path( "../../../support/fixtures/sanitizer_reports/#{name}.txt", __FILE__ ) )
  end

  def finding(name)
    findings = described_class.parse( report( name ) )
    expect(findings.length).to eq( 1 )
    return findings.first
  end

  it 'finds nothing in output without a sanitizer report' do
    expect(described_class.parse( "test_a.c:4:test_x:PASS\n1 Tests 0 Failures 0 Ignored\n" )).to eq( [] )
  end

  it 'reads an ASan error and its location from GCC' do
    found = finding( 'gcc_heap' )

    expect(found.to_h.slice( :sanitizer, :kind, :file, :line )).to eq( sanitizer: :address, kind: 'heap-buffer-overflow', file: '/x/heap.c', line: 3 )
    expect(found.message).to start_with( 'heap-buffer-overflow on address' )
    expect(found.text).to include( 'SUMMARY: AddressSanitizer: heap-buffer-overflow' )
  end

  it 'reads an ASan error and its location from Clang' do
    found = finding( 'clang_asan_heap' )
    expect(found.to_h.slice( :sanitizer, :kind, :file, :line )).to eq( sanitizer: :address, kind: 'heap-buffer-overflow', file: 'heap.c', line: 3 )
  end

  # A leak's location is the first frame in the program, past the sanitizer's own malloc
  it 'reads a leak and where it was allocated' do
    found = finding( 'gcc_leak' )

    expect(found.to_h.slice( :sanitizer, :kind, :file, :line )).to eq( sanitizer: :leak, kind: 'memory-leak', file: '/x/leak.c', line: 4 )
    expect(found.message).to eq( 'Direct leak of 32 byte(s) in 1 object(s)' )
  end

  it 'reads a UBSan runtime error and its location from GCC and from Clang' do
    [ 'gcc_ubsan_shift', 'clang_ubsan_shift' ].each do |name|
      found = finding( name )
      expect(found.to_h.slice( :sanitizer, :kind, :file, :line, :column )).to eq( sanitizer: :undefined, kind: 'undefined-behavior', file: 'ub.c', line: 3, column: 67 )
      expect(found.message).to eq( "left shift of 128 by 24 places cannot be represented in type 'int'" )
    end
  end

  # ASan and UBSan together catch a null dereference as UBSan's null load
  it 'reads a null pointer load as a UBSan runtime error' do
    found = finding( 'gcc_segv' )
    expect(found.to_h.slice( :sanitizer, :file, :line, :message )).to eq( sanitizer: :undefined, file: 'segv.c', line: 2, message: "load of null pointer of type 'uint32_t'" )
  end

  # Recover mode keeps running after each finding
  it 'reads each of several reports' do
    findings = described_class.parse( report( 'gcc_ubsan_shift' ) + report( 'gcc_leak' ) )
    expect(findings.map( &:sanitizer )).to eq( [:undefined, :leak] )
  end
end
