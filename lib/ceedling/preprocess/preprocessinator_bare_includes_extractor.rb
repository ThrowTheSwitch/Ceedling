# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes'

##
## Bare Includes Preprocessor Make Rule Parsing
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

