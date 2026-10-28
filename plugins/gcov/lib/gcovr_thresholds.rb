# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# Coverage thresholds a gcovr run violated, one message each
class GcovrThresholdError < CeedlingException

  attr_reader :violations

  def initialize(violations)
    @violations = violations
    super( violations.join( "\n" ) )
  end

end

# Decodes gcovr's exit status and stderr into the :fail_under_* thresholds a run violated.
# Each violated threshold sets a bit of the exit status and writes a line of its own to
# stderr. Bit 8 covers both condition and decision coverage, which from gcovr 8.7 may
# each write a line.
module GcovrThresholds

  BITS = {
    2  => { option: :fail_under_line,     label: 'Line',                  kinds: ['line'] },
    4  => { option: :fail_under_branch,   label: 'Branch',                kinds: ['branch'] },
    8  => { option: :fail_under_decision, label: 'Condition or decision', kinds: ['condition', 'decision'] },
    16 => { option: :fail_under_function, label: 'Function',              kinds: ['function'] },
  }.freeze

  MESSAGE_PATTERN = /^\(?error\)?:?\s+(failed minimum (\w+) coverage.*?)\s*$/i

  # Returns the violation messages, and the exit status bits no configured threshold explains
  def self.decode(opts:, exitcode:, stderr:)
    messages = messages_by_kind( stderr )
    violations = []

    BITS.each do |bit, threshold|
      next unless (exitcode & bit) == bit && !opts[threshold[:option]].nil?

      violations.concat( violations_for( threshold, opts, messages ) )
      exitcode &= ~bit
    end

    return violations, exitcode
  end

  # gcovr's own messages, grouped by the coverage kind each names
  def self.messages_by_kind(stderr)
    messages = Hash.new { |hash, kind| hash[kind] = [] }

    stderr.to_s.each_line do |line|
      match = line.match( MESSAGE_PATTERN )
      messages[match[2].downcase] << match[1] if match
    end

    return messages
  end

  def self.violations_for(threshold, opts, messages)
    found = threshold[:kinds].flat_map { |kind| messages[kind] }
    found = ["#{threshold[:label]} coverage is less than the configured minimum of #{opts[threshold[:option]]}%"] if found.empty?

    return found.map { |message| "Gcovr ⏩️ #{message}" }
  end

  private_class_method :messages_by_kind, :violations_for

end
