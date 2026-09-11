# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/path_matcher'
require 'set'

##
## System Includes Directives-only Preprocessor Output Parsing
## ===========================================================
##
## Format:
##  - File content excerpted between line markers nesting the expansion of files.
##  - Line marker: `# linenum filename flags`
##  - Flags:
##     - 1 = Start of new file
##     - 2 = Returning to a file
##     - 3 = System header
##     - 4 = Implicit extern C
##
## Notes:
##  - The initial line marker is "# 1" followed by the source file being preprocessed
##  - `# 0` at the top of the output is reserved for internal macros, command line macros
##    and other symbols not from #include directives.
##  - Because of the preprocessor's behavior around #include guards, the order of #include
##    directives can mask the header filenames. That is, in the following examples,
##    <stdint.h> is at depth two.
##
##  #include "ecmsi_bar.h"
##  #include "ecmsi_foo.h" // Includes <stdint.h>
##  #include <stdint.h>    // Does not appear in preprocessor output.
##                         // Transitive <stdint.h> from preceding user include at depth 2.
##
## Example output follows
## (Edited for length)
## -----------------------------------------------------------------------------------------
## # 0 "<command-line>" 2
## # 1 "src/external_calls_multi_static_inline/ecmsi_bar.c"
## 
## /****************************************************************************************
##  * Includes
##  ***************************************************************************************/
## # 1 "src/external_calls_multi_static_inline/ecmsi_bar.h" 1
## 
## #define ECMSI_BAR_H 
## 
## /****************************************************************************************
##  * Public function prototypes
##  ***************************************************************************************/
## extern void ecmsi_bar_init(void);
## 
## # 6 "src/external_calls_multi_static_inline/ecmsi_bar.c" 2
## # 1 "src/external_calls_multi_static_inline/ecmsi_foo.h" 1
## 
## #define ECMSI_FOO_H 
## 
## /****************************************************************************************
##  * Includes
##  ***************************************************************************************/
## # 1 "/usr/lib/gcc/x86_64-linux-gnu/12/include/stdint.h" 1 3 4
## 
## 
## # 1 "/usr/include/stdint.h" 1 3 4
## /* Copyright (C) 1997-2022 Free Software Foundation, Inc.
##    This file is part of the GNU C Library.
## */
## 
## #define _STDINT_H 1
## 
## #define __GLIBC_INTERNAL_STARTING_HEADER_IMPLEMENTATION 
## 
## # 318 "/usr/include/stdint.h" 3 4
## 
## # 10 "/usr/lib/gcc/x86_64-linux-gnu/12/include/stdint.h" 2 3 4
## 
## #define _GCC_WRAP_STDINT_H 
## # 9 "src/external_calls_multi_static_inline/ecmsi_foo.h" 2
##

# Parse GCC preprocessor output (from -fdirectives-only) to extract system include directives
class PreprocessinatorLineMarkerIncludesExtractor
  # Leading whitespace is tolerated (`^\s*`, not just `^`): GCC's -fdirectives-only output
  # replaces a top-level #include with a line marker that inherits that #include's own
  # original indentation (GH #1268) -- an indented `#include "x.h"` produces an indented
  # `    # 1 "x.h" 1`, not the flush-left marker every OTHER marker GCC generates uses.
  # Without this, such an include is silently missing from the extracted list entirely.
  LINE_MARKER_REGEX = /^\s*#\s+(\d+)\s+"([^"]+)"(?:\s+(\d+(?:\s+\d+)*))?$/ unless const_defined?(:LINE_MARKER_REGEX)

  SYSTEM = :system  unless const_defined?(:SYSTEM)
  USER   = :user    unless const_defined?(:USER)

  constructor :include_factory, :file_wrapper

  # Parse preprocessor output from a file (production use)
  # @param filepath [String] Path to the preprocessor output file
  # @param test [String, nil] Current test's identity, needed to correctly strip its
  #   own mock subdirectory from a resolved mock include's filepath
  # @return [Array<UserInclude, SystemInclude>]
  def extract_includes_from_file(filepath, type, max_depth=nil, test: nil)
    validate_type_argument( type )
    includes = []
    begin
      # Open in binary mode: GCC output under a non-C locale contains non-ASCII bytes
      # (e.g. <組み込み> for <built-in> under ja_JP). Text mode would interpret those
      # bytes using the locale-dependent external encoding (e.g. Windows-31J on ja_JP
      # Windows), raising an encoding error on read. Binary mode bypasses that translation.
      # LINE_MARKER_REGEX uses only ASCII delimiters and is safe in binary mode.
      # The filepath.start_with?('<') guard correctly skips localized markers because
      # their first byte is 0x3C — ASCII '<' — regardless of the surrounding encoding.
      # NOTE: binary mode means \r\n line endings are NOT translated on Windows; the
      # extract_includes method calls line.chomp! before regex matching to handle this.
      @file_wrapper.open(filepath, 'rb') do |file|
        includes = extract_includes(io: file, filepath: filepath, type: type, max_depth: max_depth, test: test)
      end
    rescue StandardError => e
      raise CeedlingException.new("Failed to extract #{type} includes from preprocessor output file '#{filepath}' ⏩️ #{e.message}")
    end
    return includes
  end

  # Parse preprocessor output from a string (testing use)
  # @param content [String] Preprocessor output as a string
  # @return [Array<UserInclude, SystemInclude>]
  def extract_includes_from_string(content, filepath, type, max_depth=nil, test: nil)
    validate_type_argument( type )
    require 'stringio'
    io = StringIO.new(content)
    return extract_includes(io: io, filepath: filepath, type: type, max_depth: max_depth, test: test)
  end

  # Correlate `-fdirectives-only` entering line markers back to the raw source lines
  # that produced them, for a set of lines of interest. Used to recover GCC's own
  # resolution of an `#include` whose target is a macro invocation: the directive
  # carries no literal filename to scan for, but the accurate directives-only pass
  # still resolves it and emits an ordinary entering marker for the header.
  #
  # @param preprocessed_filepath [String] raw directives-only output (line markers
  #   intact, comments stripped or not -- physical line count is 1:1 with the source
  #   either way, which is all this walk needs)
  # @param source_basename [String] basename of the original source file, used to
  #   recognize its own line markers in the stream
  # @param source_lines [Enumerable<Integer>] 1-indexed source line numbers to report
  #   a resolution for (the lines carrying a non-literal `#include`)
  # @return [Hash{Integer => String}] source line number => path GCC resolved that
  #   line's `#include` to; only lines that actually produced an entering marker appear
  def resolve_computed_includes(preprocessed_filepath:, source_basename:, source_lines:)
    wanted = source_lines.to_a
    return {} if wanted.empty?

    begin
      # Binary mode for the same reason extract_includes_from_file uses it: GCC output
      # under a non-C locale carries non-ASCII bytes, and \r\n must survive untranslated
      # for the per-line chomp! below to normalize.
      @file_wrapper.open( preprocessed_filepath, 'rb' ) do |file|
        return correlate_computed_includes( io: file, source_basename: source_basename, wanted: Set.new( wanted ) )
      end
    rescue StandardError => e
      raise CeedlingException.new("Failed to correlate computed #includes from preprocessor output file '#{preprocessed_filepath}' ⏩️ #{e.message}")
    end
  end

  private

  # Walk the directives-only stream tracking which source line of the file of interest
  # the current physical line maps to, and report the resolved path for every entering
  # marker attributed to a `wanted` source line.
  #
  # `src_line` names the source line the NEXT non-marker physical line will be. A
  # `# n "<file of interest>"` marker sets it to `n`; each subsequent body line of that
  # file bumps it by one. The macro-target `#include` directive is REPLACED by the
  # entering marker for the header it pulled in, so it never shows up as a body line --
  # `src_line` therefore still reads that directive's own line number when its entering
  # marker appears. Body lines and markers of any OTHER file are skipped entirely, so
  # a header's own nesting can't drift the count.
  def correlate_computed_includes(io:, source_basename:, wanted:)
    resolved = {}
    in_file_of_interest = false
    src_line = 0

    io.each_line do |line|
      line.chomp!

      match = LINE_MARKER_REGEX.match(line)

      # A non-marker line advances the counter only while inside the file of interest.
      unless match
        src_line += 1 if in_file_of_interest
        next
      end

      marker_path = match[2]
      next if marker_path.start_with?('<')  # <built-in>, <command-line>

      marker_path = canonicalize_marker_path( marker_path )
      flags = match[3] ? match[3].split.map(&:to_i) : []

      if File.basename(marker_path) == source_basename
        # Entering or resuming the file of interest: its own markers carry the
        # authoritative line number for whatever comes next.
        src_line = match[1].to_i
        in_file_of_interest = true
      elsif in_file_of_interest && flags.include?(1)
        # An entering marker for another file, standing in for a directive on the
        # file-of-interest line the counter currently names.
        resolved[src_line] = marker_path if wanted.include?(src_line)
        in_file_of_interest = false
      else
        # Any other marker (returning to an intermediate header, a nested entry):
        # we're no longer tracking file-of-interest body lines until its own marker
        # brings us back.
        in_file_of_interest = false
      end
    end

    resolved
  end

  # GCC's own marker text is real and complete but sometimes left uncanonicalized:
  # PathMatcher.resolve_relative deliberately leaves an ABSOLUTE query's own `..`
  # untouched (its own documented contract defers that case to a File.expand_path-
  # based comparison elsewhere) -- reachable whenever the file actually being
  # preprocessed has an absolute path of its own, which makes GCC's marker for a
  # directory-relative include absolute too. Collapsed here with a plain segment
  # walk rather than File.expand_path, which is CWD- and drive-dependent on Windows
  # and would silently inject the current process's own drive letter into an
  # already-absolute Unix-style path instead of leaving it alone. Only reached when
  # the result is still absolute AND still carries a literal `..` segment -- a no-op
  # for the ordinary, already-clean case.
  def canonicalize_marker_path(path)
    resolved = PathMatcher.resolve_relative( path, anchor: '' )
    segments = resolved.split(%r{[\\/]}).reject(&:empty?)
    return resolved unless segments.include?('..')

    # Absolute forms this can see: a leading "/" (Unix), or a drive letter
    # ("C:\..." / "C:/..."). Either way, remember the prefix so the collapsed
    # result stays just as absolute as it started -- neither form's own marker is
    # ever a bare relative path once resolve_relative has already left it untouched.
    drive_match = resolved.match(/\A([A-Za-z]:)[\\\/]/)
    prefix = drive_match ? "#{drive_match[1]}/" : '/'
    segments.shift if drive_match

    collapsed = []
    segments.each { |segment| segment == '..' ? collapsed.pop : collapsed << segment }

    "#{prefix}#{collapsed.join('/')}"
  end

  def validate_type_argument(type)
    unless [SYSTEM, USER].include?(type)
      raise CeedlingException.new("Invalid type argument: #{type.inspect}. Must be :#{SYSTEM} or :#{USER}")
    end
  end

  # Extracts includes from directives-only preprocessor output
  # Returns an array of Include-derived objects
  def extract_includes(io:, filepath:, type:, max_depth:, test: nil)
    includes = []
    seen_paths = Set.new
    initial_file_seen = false
    depth = 0

    # Extract just the filename from full path
    source_filename = File.basename(filepath)
    
    io.each_line do |line|
      # Binary mode ('rb') yields raw bytes without platform newline translation.
      # On Windows (MinGW/MSYS2), GCC writes \r\n line endings in preprocessor output.
      # IO#each_line splits on \n and preserves the preceding \r in the yielded string.
      # LINE_MARKER_REGEX ends with $ which anchors before \n but does NOT match when
      # \r immediately precedes it — the optional flags group (?:\s+(\d+...))? cannot
      # consume the stray \r, so every line marker match fails on Windows, producing
      # an empty include list and cascading test build failures.
      # String#chomp! (no-arg) removes \r\n, \r, or \n — safe on all platforms.
      line.chomp!

      # Match GCC line markers
      if (match = LINE_MARKER_REGEX.match(line))
        # String filename
        filepath = match[2]

        # Skip special markers like "<built-in>" and "<command-line>"
        next if filepath.start_with?('<')

        # GCC forms a directory-relative quoted include's own line marker by
        # concatenating the including file's directory onto the literal include
        # text -- real and complete, but left uncanonicalized. Collapsing any ..
        # here, once, means this path can correspond to the project's own real,
        # ..-free file list the same way any other candidate already does.
        filepath = canonicalize_marker_path( filepath )

        # Integer line number
        line_number = match[1].to_i
        
        # Array of flag integers
        flags = match[3] ? match[3].split.map(&:to_i) : []
        
        # Look for `# 1 "<filename>"`
        if !initial_file_seen
          if (line_number == 1) && (File.basename(filepath) == source_filename)
            initial_file_seen = true
            depth = 1
          end
          next
        end
        
        # Flag 1 means entering a new file
        if flags.include?(1)
          depth += 1

          # Skip if we've already seen this path
          next if seen_paths.include?( filepath )

          # Skip if max depth is defined and we've exceeded it.
          # If max depth is not defined, do not limit the depth.
          next if (max_depth && (depth > max_depth))

          seen_paths.add(filepath)

          # Extract system includes
          if type == SYSTEM
            # Flag 3 indicates a system header
            if flags.include?(3)
              includes << @include_factory.system_include_from_filepath( filepath )
            end
          # Extract user includes
          elsif type == USER
            unless flags.include?(3)
              includes << @include_factory.user_include_from_filepath( filepath, test: test )
            end
          end
        # Flag 2 means returning to a previous file
        elsif flags.include?(2)
          depth -= 1 if depth > 0
        end
      end
    end
    
    return includes
  end
end

