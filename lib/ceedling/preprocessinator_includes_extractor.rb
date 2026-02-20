# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'ceedling/includes'
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
class PreprocessinatorSystemIncludesExtractor
  LINE_MARKER_REGEX = /^#\s+(\d+)\s+"([^"]+)"(?:\s+(\d+(?:\s+\d+)*))?$/

  # Parse preprocessor output from a file (production use)
  # @param filepath [String] Path to the preprocessor output file
  # @return [Array<UserInclude, SystemInclude>]
  def self.extract_includes_from_file(filepath, max_depth: 1)
    includes = []
    begin
      File.open(filepath, 'r') do |file|
        includes = self.extract_includes(io: file, filepath: filepath, max_depth: max_depth)
      end
    rescue StandardError => e
      raise CeedlingException.new("Failed to extract system includes from preprocessor output file '#{filepath}': #{e.message}")
    end
    return includes
  end

  # Parse preprocessor output from a string (testing use)
  # @param content [String] Preprocessor output as a string
  # @return [Array<UserInclude, SystemInclude>]
  def self.extract_includes_from_string(content, filepath, max_depth: 1)
    require 'stringio'
    io = StringIO.new(content)
    return self.extract_includes(io: io, filepath: filepath, max_depth: max_depth)
  end

  private

  # Extracts system includes up to max depth from directives-only preprocessor output
  # Returns an array of SystemInclude objects
  # @return [Array<SystemInclude>]
  def self.extract_includes(io:, filepath:, max_depth: 1)
    includes = []
    nesting_level = 0
    seen_paths = Set.new
    initial_file_seen = false
    
    # Extract just the filename from full path
    source_filename = File.basename(filepath)
    
    io.each_line do |line|
      # Match GCC line markers
      if (match = LINE_MARKER_REGEX.match(line))
        # String filename
        filepath = match[2]

        # Skip special markers like "<built-in>" and "<command-line>"
        next if filepath.start_with?('<')

        # Integer line number
        line_number = match[1].to_i
        
        # Array of flag integers
        flags = match[3] ? match[3].split.map(&:to_i) : []
        
        # Look for `# 1 "<filename>"`
        if !initial_file_seen
          if (line_number == 1) && (File.basename(filepath) == source_filename)
            initial_file_seen = true
            nesting_level = 0
          end
          next
        end
        
        # Flag 1 means entering a new file
        if flags.include?(1)
          nesting_level += 1
          
          # Only capture includes up to max depth and skip if we've already seen this path
          if nesting_level <= max_depth && !seen_paths.include?(filepath)
            seen_paths.add(filepath)
            
            # Flag 3 indicates a system header
            includes << SystemInclude.new(filepath) if flags.include?(3)
          end
        # Flag 2 means returning to a previous file
        elsif flags.include?(2)
          nesting_level -= 1 if nesting_level > 0
        end
      end
    end
    
    return includes
  end
end

##
## User Includes Preprocessor Make Rule Parsing
## ============================================
##
## Format:
##  - First line is .o file followed by colon and dependencies (on one or more lines).
##  - "Phony" make rules follow that conveniently list each #include, one per line.
##
## Notes:
##  - A file with no includes will create the first line with self-referential .h file path.
##  - Make rule formation assumes any files not found in a search path will be generated.
##    - Since we're not using search paths, the preprocessor largely assumes all #include 
##      files are generated (and include no paths).
##    - The exception is #include files that exist in the same directory as the file
##      being processed.
##
## Approach:
##  1. Disable exceptions for tool execution as errors are likely.
##    - We may still have usable output.
##    - We do not want to stop execution on fatal error; instead use a fallback method.
##  2. The only true error is no make rule present--check for this first.
##    - A make rule may be present but not depedencies if the file has no #includes.
##  3. Extract includes from "phony" make rules that follow opening rule line.
##    - These may be .h or .c files.
## 
## Example output follows
## -----------------------------------------------------------------------------------------
## os.o: ../../src/app/task/os/os.h fstd_types.h FreeRTOS.h queue.h
## fstd_types.h:
## FreeRTOS.h:
## queue.h:
## ../../src/app/task/os/os.h:72:21: error: no include path in which to search for stdbool.h
##    72 | #include <stdbool.h>
##       |                     ^
## ../../src/app/task/os/os.h:73:20: error: no include path in which to search for stdint.h
##    73 | #include <stdint.h>
##       |                    ^
##

# Parse GCC preprocessor make-rule dependencies output to extract user include directives
class PreprocessinatorBareIncludesExtractor

    # Matcher for the first line of the make rule output
    MAKE_RULE_MATCHER = /^\S+\.o:\s+.+$/  # <characters>.o: <characters>
    
    # Matcher for the “phony“ make rule output lines for each #include dependency (.h, .c, etc.)
    # Capture file name before the colon
    INCLUDE_MATCHER = /^(\S+\.\S+):\s*$/ # <characters>.<extension>:

  def self.extract_includes(make_rules)
    # Extract the #include dependencies from the "phony" make rules, one per line
    includes = make_rules.scan( INCLUDE_MATCHER )
    includes.flatten! # Regex results can be nested arrays becuase of paren captures
    includes.uniq!

    # Convert list of fileapth strings to list of bare Include objects
    return includes.map { |_include| Include.new(_include) }
  end
end

