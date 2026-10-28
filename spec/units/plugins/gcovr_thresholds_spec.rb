# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$: << File.expand_path('../../../../plugins/gcov/lib', __FILE__)

require 'gcovr_thresholds'

# GH #1366: every violated threshold took stderr's first (ERROR) line, so two violations
# reported the line-coverage message twice and lost the other
describe GcovrThresholds do
  # gcovr 8.8, :mcdc on, --fail-under-line 100 --fail-under-decision 100 (exit 10 = 2 | 8).
  # From 8.7, --fail-under-decision also checks condition coverage, so bit 8 carries two lines.
  STDERR_8_8 = <<~STDERR
    (ERROR) Failed minimum line coverage (got 50.0%, minimum 100.0%)
    (ERROR) Failed minimum condition coverage (got 50.0%, minimum 100.0%)
    (ERROR) Failed minimum decision coverage (got 0.0%, minimum 100.0%)
  STDERR

  def decode(opts, exitcode, stderr)
    GcovrThresholds.decode( opts: opts, exitcode: exitcode, stderr: stderr )
  end

  it 'reports each violated threshold with its own gcovr message, once' do
    violations, unexplained = decode( {fail_under_line: 100, fail_under_decision: 100}, 10, STDERR_8_8 )

    expect(violations).to eq( [
      'Gcovr ⏩️ Failed minimum line coverage (got 50.0%, minimum 100.0%)',
      'Gcovr ⏩️ Failed minimum condition coverage (got 50.0%, minimum 100.0%)',
      'Gcovr ⏩️ Failed minimum decision coverage (got 0.0%, minimum 100.0%)'
    ] )
    expect(unexplained).to eq( 0 )
  end

  it 'reports a decision message alone, as gcovr before 8.7 writes it' do
    stderr = "(ERROR) Failed minimum decision coverage (got 40.0%, minimum 90.0%)\n"

    violations, _ = decode( {fail_under_decision: 90}, 8, stderr )

    expect(violations).to eq( ['Gcovr ⏩️ Failed minimum decision coverage (got 40.0%, minimum 90.0%)'] )
  end

  it 'keeps gcovr\'s capitalization' do
    stderr = "(ERROR) Failed minimum branch coverage (got 1.0%, minimum MC/DC 2.0%)\n"

    violations, _ = decode( {fail_under_branch: 2}, 4, stderr )

    expect(violations.first).to end_with( 'Failed minimum branch coverage (got 1.0%, minimum MC/DC 2.0%)' )
  end

  it 'capitalizes the message an older gcovr writes in lowercase' do
    stderr = "(ERROR) failed minimum line coverage (got 50.0%, minimum 90.0%)\n"

    violations, _ = decode( {fail_under_line: 90}, 2, stderr )

    expect(violations).to eq( ['Gcovr ⏩️ Failed minimum line coverage (got 50.0%, minimum 90.0%)'] )
  end

  it 'falls back to a description of each violated threshold that gcovr gave no message for' do
    violations, _ = decode( {fail_under_line: 90, fail_under_decision: 80, fail_under_function: 70}, 2 | 8 | 16, '' )

    expect(violations).to eq( [
      'Gcovr ⏩️ Line coverage is less than the configured minimum of 90%',
      'Gcovr ⏩️ Condition or decision coverage is less than the configured minimum of 80%',
      'Gcovr ⏩️ Function coverage is less than the configured minimum of 70%'
    ] )
  end

  it 'leaves unexplained every bit without a configured threshold' do
    violations, unexplained = decode( {fail_under_line: 90}, 2 | 4 | 64, '' )

    expect(violations.length).to eq( 1 )
    expect(unexplained).to eq( 4 | 64 )
  end

  it 'reports nothing for a zero exit code, and accepts a nil stderr' do
    expect( decode( {fail_under_line: 90}, 0, nil ) ).to eq( [[], 0] )
  end
end

describe GcovrThresholdError do
  it 'carries each violation, and joins them as its message' do
    error = GcovrThresholdError.new( ['one', 'two'] )

    expect(error).to be_a( CeedlingException )
    expect(error.violations).to eq( ['one', 'two'] )
    expect(error.message).to eq( "one\ntwo" )
  end
end
