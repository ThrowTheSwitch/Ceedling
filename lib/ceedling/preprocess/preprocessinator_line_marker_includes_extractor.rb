# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
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
  LINE_MARKER_REGEX = /^#\s+(\d+)\s+"([^"]+)"(?:\s+(\d+(?:\s+\d+)*))?$/

  SYSTEM = :system
  USER   = :user

  constructor :include_factory

  # Parse preprocessor output from a file (production use)
  # @param filepath [String] Path to the preprocessor output file
  # @return [Array<UserInclude, SystemInclude>]
  def extract_includes_from_file(filepath, type)
    validate_type_argument( type )
    includes = []
    begin
      File.open(filepath, 'r') do |file|
        includes = extract_includes(io: file, filepath: filepath, type: type)
      end
    rescue StandardError => e
      raise CeedlingException.new("Failed to extract #{type} includes from preprocessor output file '#{filepath}': #{e.message}")
    end
    return includes
  end

  # Parse preprocessor output from a string (testing use)
  # @param content [String] Preprocessor output as a string
  # @return [Array<UserInclude, SystemInclude>]
  def extract_includes_from_string(content, filepath, type)
    validate_type_argument( type )
    require 'stringio'
    io = StringIO.new(content)
    return extract_includes(io: io, filepath: filepath, type: type)
  end

  private

  def validate_type_argument(type)
    unless [SYSTEM, USER].include?(type)
      raise CeedlingException.new("Invalid type argument: #{type.inspect}. Must be :#{SYSTEM} or :#{USER}")
    end
  end

  # Extracts includes from directives-only preprocessor output
  # Returns an array of Include subclass objects
  def extract_includes(io:, filepath:, type:)
    includes = []
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
          end
          next
        end
        
        # Flag 1 means entering a new file
        if flags.include?(1)
          # Skip if we've already seen this path
          next if seen_paths.include?(filepath)

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
              includes << @include_factory.user_include_from_filepath( filepath )
            end
          end
        end
      end
    end
    
    return includes
  end
end

