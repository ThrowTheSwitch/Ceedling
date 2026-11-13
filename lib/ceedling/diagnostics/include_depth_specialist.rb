# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/diagnostics/build_step_doctor'
require 'ceedling/diagnostics/toolchain_output'

# Explains #include directives nested deeper than a compiler allows.
#
# The nesting is almost always a loop. A forwarding header that includes its own
# filename, meaning to reach a header of that name elsewhere, finds itself again when
# its own directory comes first in the search paths. Headers that include each other
# without include guards loop the same way. The compiler stops at a fixed depth and
# reports the loop only as nesting too deep.
#
# The guidance always explains both loops. When the header the error names includes
# its own filename and the search paths lead back to it, the guidance also names the
# header, the path that loops, and any header of that name later in the search paths.
class IncludeDepthSpecialist

  # Each family's wording for nesting too deep, ending in a generic net. Newer GCC quotes
  # the directive, with curly quotes in a UTF-8 locale, so a few non-word characters may
  # follow it.
  INCLUDE_DEPTH_SYMPTOMS = [
    # GCC 10 and later
    /#include\W{1,4}nested depth \d+ exceeds maximum/i,
    # Clang, armclang, and GCC before 10
    /#include\W{1,4}nested too deeply/i,
    # MSVC
    /\bC1014\b|too many include files/i,
    # EDG front ends: IAR, Arm armcc, TI, and Green Hills
    /includes itself|include file nesting/i,
    # Other compilers
    /\binclude\w* (?:depth|nesting)|nested (?:#?include|too deep)|too many (?:nested )?include/i
  ].freeze

  INCLUDE_DIRECTIVE = /^[ \t]*#[ \t]*include[ \t]*([<"])([^>"\n]+)[>"]/

  GUIDANCE = <<~GUIDANCE.freeze
    HOW THIS HAPPENS:
    • A compiler searches the include paths in order and uses the first file with the requested name.
    • A forwarding header that #includes its own filename, to reach a header of that name elsewhere, finds itself again when its directory comes first.
    • Two headers that #include each other without include guards repeat in the same way.
    • The compiler stops at a fixed nesting limit and reports the loop as nesting too deep.

    OPTIONS:
    1. Order :paths ↳ :include (or TEST_INCLUDE_PATH()) so the directory holding the intended header comes before the forwarding header's directory.
    2. List the forwarding header's parent directory instead, and #include it by its subdirectory, such as "freertos/timers.h".
    3. Give headers that include each other include guards or #pragma once.
  GUIDANCE

  constructor :file_wrapper

  def diagnoses()
    return [
      BuildStepDoctor::Diagnosis.new(
        name:        :include_nested_too_deeply,
        steps:       [:preprocess, :compile],
        symptoms:    INCLUDE_DEPTH_SYMPTOMS,
        examination: method( :examine )
      )
    ]
  end

  ### Private ###

  private

  def examine(kase)
    lead    = 'The compiler output appears to report #include directives nested too deeply, which usually means a header includes itself.'
    finding = self_inclusion( error_header( kase.symptoms ), kase.inputs[:search_paths] || [] )
    lead   += "\n#{finding}" if finding

    return "#{lead}\n\n#{GUIDANCE}"
  end

  # The header on the line that reports the error, or nil
  def error_header(match)
    line = match.pre_match[/[^\n]*\z/] + match[0] + match.post_match[/\A[^\n]*/]
    return ToolchainOutput.headers( line ).first
  end

  # Explains the first #include in `header` that the search reaches it through again, or nil.
  # The explanation names the header as the search found it. The output may spell it
  # another way, such as Clang on Windows joining a search path and a name with '\'.
  def self_inclusion(header, search_paths)
    return nil if header.nil? || !@file_wrapper.exist?( header )

    @file_wrapper.read( header ).scrub.scan( INCLUDE_DIRECTIVE ).each do |delimiter, name|
      found = search( header, delimiter, name, search_paths )
      next unless same_file?( found.first, header )

      return looping_explanation( found.first, delimiter, name, found )
    end

    return nil
  end

  # Every file an #include of `name` in `header` can reach, in the order the compiler searches.
  # A quoted #include searches its own file's directory before the search paths.
  def search(header, delimiter, name, search_paths)
    directories = (delimiter == '"' ? [File.dirname( header )] : []) + search_paths

    return directories.map { |directory| File.join( directory, name ) }.select { |path| @file_wrapper.exist?( path ) }
  end

  # A quoted #include loops whatever the search path order, so only an angled one is
  # blamed on that order
  def looping_explanation(header, delimiter, name, found)
    intended = found.find { |path| !same_file?( path, header ) }

    if delimiter == '"'
      explanation = "'#{header}' includes \"#{name}\". A quoted #include searches the header's own directory before any search path, " \
                    'so it includes itself whatever their order.'
      return intended ? "#{explanation} '#{intended}' is in the search paths, and #include <#{name}> would let their order reach it." : explanation
    end

    explanation = "'#{header}' includes <#{name}>, and the search paths find that name in the header's own directory first " \
                  "('#{File.dirname( found.first )}'), so it includes itself."
    return intended ? "#{explanation} '#{intended}' is later in the search paths." : explanation
  end

  # A symlink or a difference in case can name one file two ways
  def same_file?(path, other)
    return false if path.nil?

    return File.expand_path( path ) == File.expand_path( other ) || File.identical?( path, other )
  end
end
