# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Reads sanitizer reports out of a test executable's stderr. Each report becomes a finding,
# located at the first stack frame in the program rather than in the sanitizer's runtime.
module SanitizeFindings

  Finding = Struct.new( :sanitizer, :kind, :file, :line, :column, :message, :text, keyword_init: true )

  # The first line of each kind of report
  ASAN_ERROR = /==\d+==ERROR: AddressSanitizer: (\S+)(.*)$/
  LSAN_ERROR = /==\d+==ERROR: LeakSanitizer: detected memory leaks/
  UBSAN_ERROR = /^(.+?):(\d+):(\d+): runtime error: (.+)$/

  ASAN_SUMMARY = /^SUMMARY: AddressSanitizer: \S+ (.+?):(\d+)(?::\d+)? in /
  LEAK_LINE    = /^((?:Direct|Indirect) leak of .+?)(?: allocated from:)?\s*$/
  FRAME        = /^\s+#\d+ 0x\h+ in \S+ (.+?):(\d+)(?::\d+)?\s*$/

  # Frames in the sanitizer runtime and the C library rather than the program
  RUNTIME_FRAME = %r{libsanitizer|compiler-rt|libclang_rt|/sysdeps/|/csu/}

  def self.parse(stderr)
    return reports( stderr.to_s.lines ).map { |lines| finding( lines ) }
  end

  # Splits the lines into one group per report, each starting at its first line
  def self.reports(lines)
    groups = []
    lines.each do |line|
      groups << [] if report_start?( line )
      groups.last << line unless groups.empty?
    end
    return groups
  end

  def self.report_start?(line)
    return line.match?( ASAN_ERROR ) || line.match?( LSAN_ERROR ) || line.match?( UBSAN_ERROR )
  end

  def self.finding(lines)
    first = lines.first
    return leak( lines ) if first.match?( LSAN_ERROR )
    return address( lines, first.match( ASAN_ERROR ) ) if first.match?( ASAN_ERROR )

    return undefined( lines, first.match( UBSAN_ERROR ) )
  end

  # The summary line names the error's location. Without one, the first program frame does.
  def self.address(lines, error)
    summary = lines.lazy.filter_map { |line| line.match( ASAN_SUMMARY ) }.first
    file, line = summary ? [summary[1], summary[2].to_i] : program_frame( lines )

    return Finding.new(
      sanitizer: :address, kind: error[1], file: file, line: line, message: "#{error[1]}#{error[2]}".strip, text: lines.join
    )
  end

  # A leak is located where its first leaked object was allocated
  def self.leak(lines)
    leaked = lines.index { |line| line.match?( LEAK_LINE ) }
    file, line = program_frame( leaked ? lines.drop( leaked ) : lines )
    message = leaked ? lines[leaked].match( LEAK_LINE )[1] : 'detected memory leaks'

    return Finding.new( sanitizer: :leak, kind: 'memory-leak', file: file, line: line, message: message, text: lines.join )
  end

  def self.undefined(lines, error)
    return Finding.new(
      sanitizer: :undefined, kind: 'undefined-behavior', file: error[1], line: error[2].to_i, column: error[3].to_i,
      message: error[4].strip, text: lines.join
    )
  end

  def self.program_frame(lines)
    frame = lines.lazy.filter_map { |line| line.match( FRAME ) }.reject { |match| match[1].match?( RUNTIME_FRAME ) }.first
    return frame ? [frame[1], frame[2].to_i] : [nil, nil]
  end

  private_class_method :reports, :report_start?, :finding, :address, :leak, :undefined, :program_frame

end
