# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes'

class PreprocessinatorIncludesHandler

  constructor :configurator, :tool_executor, :file_path_utils, :yaml_wrapper, :loginator, :reportinator

  # TODO: Refactor to clean up common parts with `full_extract_includes()``
  def simple_extract_includes(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting #includes via simple preprocessing from",
      module_name: test,
      filename: filename
    )
    @loginator.log(msg, Verbosity::OBNOXIOUS)

    success, includes = 
      extract_simple_includes_preprocessor(
        test:         test,
        filepath:     filepath,
        flags:        flags,
        defines:      defines,
        search_paths: include_paths + vendor_paths
        )

    if success
      msg = "Preprocessor simple includes extraction succeeded."
      @loginator.log(msg, Verbosity::DEBUG)
    else
      msg = "Preprocessor simple includes extraction failed."
      @loginator.log(msg, Verbosity::DEBUG)
      return []
    end

    # Remove any filepath in the common list that is identical to the filepath being processed
    # We want to prevent an includes list containing an unnecessary self-reference
    # Normalize paths for comparison to handle variations (relative vs absolute, different separators, etc.)
    normalized_filepath = File.expand_path(filepath)
    includes.reject! do |include|
      normalized_include = File.expand_path(include.filepath)
      normalized_include == normalized_filepath
    end
    
    return includes
  end

  ##
  ## Includes Extraction Overview
  ## ============================
  ##
  ## BACKGROUND
  ## --------
  ## #include extraction is hard to do. In simple cases a regex approach suffices, but nested header files,
  ## clever macros, and conditional preprocessing statements easily introduce high complexity.
  ##
  ## Unfortunately, there's no readily available cross-platform C parsing tool that provides a simple means 
  ## to extract the #include statements directly embedded in a given file. Even the gcc preprocessor itself 
  ## only comes close to providing this information externally.
  ##
  ## APPROACH
  ## --------
  ## (Full details including fallback options are in the extensive code comments among the methods below.)
  ## 
  ## Sadly, we can't preprocess a file with full search paths and defines and ask for the #include statements
  ## embedded in a file. We get far more #includes than we want with no way to discern which are at the depth
  ## of the file being processed.
  ##
  ## Instead, we try our best to use some educated guessing to get as close as possible to the desired list.
  ##
  ##   I. Try to extract shallow defines with no crawling out into other header files. This conservative approach
  ##      gives us a reference point on possible directly included files. The results may be incomplete, though. 
  ##      They also may mistakenly list #includes that should not be in the list--because of #ifndef defaults or
  ##      because of system headers or #include <...> statements and differences among gcc implementations.
  ##
  ##  II. Extract a full list of #includes by spidering out into nested headers and processing all macros, etc.
  ##      This is the greedy approach.
  ##
  ## III. Find #includes common to (I) and (II). The results of (I) should limit the potentially lengthy
  ##      results of (II). The complete and accurate list of (II) should cut out any mistaken entries in (I).
  ##
  ##  IV. I–III are not foolproof. A purely greedy approach or a purely conservative approach will cause symbol 
  ##      conflicts, missing symbols, etc. The blended and balanced approach should come quite close to an 
  ##      accurate list of shallow includes. Edge cases and gaps will cause trouble. Other Ceedling features 
  ##      should provide the tools to intervene. 
  ##

  # TODO: Refactor to clean up common parts with `simple_extract_includes()``
  def full_extract_includes(filepath:, test:, flags:, include_paths:, vendor_paths:, defines:)
    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting #includes via full preprocessing from",
      module_name: test,
      filename: filename
    )
    @loginator.log(msg, Verbosity::OBNOXIOUS)

    success, includes = 
      extract_full_includes_preprocessor(
        test:         test,
        filepath:     filepath,
        flags:        flags,
        defines:      defines,
        search_paths: include_paths + vendor_paths
        )

    if success
      msg = "Preprocessor full includes extraction succeeded."
      @loginator.log(msg, Verbosity::DEBUG)
    else
      msg = "Preprocessor full includes extraction failed."
      @loginator.log(msg, Verbosity::DEBUG)
      return []
    end

    # Remove any filepath in the common list that is identical to the filepath being processed
    # We want to prevent an includes list containing an unnecessary self-reference
    # Normalize paths for comparison to handle variations (relative vs absolute, different separators, etc.)
    normalized_filepath = File.expand_path(filepath)
    includes.reject! do |include|
      normalized_include = File.expand_path(include.filepath)
      normalized_include == normalized_filepath
    end
    
    return includes
  end

  # Write to disk a yaml representation of a list of includes
  def write_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, Includes.to_hashes(list))
  end

  def load_includes_list(filepath)
    # Note: It's possible empty YAML content returns nil
    return Includes.from_hashes(
      @yaml_wrapper.load( filepath ) || []
    )
  end

  ### Private ###
  private

  require 'ceedling/preprocessinator_includes_handler_new'

  def extract_full_includes_preprocessor(test:, filepath:, flags:, defines:, search_paths:)
    preprocessed_filepath = @file_path_utils.form_preprocessed_file_directives_only_filepath( filepath, test )

    # Run GCC with directives-only preprocessor expansion
    command = 
      @tool_executor.build_command_line(
        @configurator.tools_test_file_directives_only_preprocessor,
        # Additional arguments
        flags,
        # Argument replacement
        filepath,
        preprocessed_filepath,
        defines,
        search_paths
      )    

    # Allow quiet failure. We will process the execution result.
    command[:options][:boom] = false
    shell_result = @tool_executor.exec( command )

    if shell_result[:exit_code] != 0
      return false, []
    end

    # make_rules = shell_result[:output]

    # # Do not check exit code for success. In some error conditions we still get usable output.
    # # Look for the first line of the make rule output.
    # if not make_rules =~ make_rule_matcher
    #   @loginator.lazy( Verbosity::DEBUG ) do
    #     "Preprocessor #include extraction failed: #{shell_result[:output]}"
    #   end

    #   return false, []
    # end

    return true, PreprocessorIncludesParser.parse_file(preprocessed_filepath, max_depth: 2)
  end

  def extract_simple_includes_preprocessor(test:, filepath:, flags:, defines:, search_paths:)
    ##
    ## Preprocessor Make Rule Handling
    ## ===============================
    ##
    ## Creation:
    ##  - This output is created with the -MM -MG -MP command line options.
    ##  - No search paths are used towards extracting only the #include statements of the file.
    ##    The intent is to minimize the list of .h -> .c module matches to, in turn, minimize
    ##    unnecessary compilation when extracting includes from a test file.
    ##  - Note: This approach can have gaps with complex macros / conditional statements.
    ##          Gaps can be minimized with proper defines in the project file.
    ##          However, needed / complex macros located in other header files can still gum 
    ##          up the works.
    ##
    ## Format:
    ##  - First line is .o file followed by colon and dependencies (on one or more lines).
    ##  - "Phony" make rules follow that conveniently list each #include, one per line.
    ##
    ## Notes:
    ##  - Many errors can occur but may not necessarily prevent usable results.
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

    # Matcher for the first line of the make rule output
    make_rule_matcher = /^\S+\.o:\s+.+$/  # <characters>.o: <characters>
    
    # Matcher for the “phony“ make rule output lines for each #include dependency (.h, .c, etc.)
    # Capture file name before the colon
    include_matcher   = /^(\S+\.\S+):\s*$/ # <characters>.<extension>:

    command = 
      @tool_executor.build_command_line(
        @configurator.tools_test_simple_includes_preprocessor,
        # No additional arguments
        [],
        # Argument replacement
        filepath,
        defines,
        flags,
        search_paths
      )

    # Assume possible errors so we have best shot at extracting results from preprocessing.
    # Full code compilation will catch any breaking code errors
    command[:options][:boom] = false
    shell_result = @tool_executor.exec( command )

    make_rules = shell_result[:output]

    # Do not check exit code for success. In some error conditions we still get usable output.
    # Look for the first line of the make rule output.
    if not make_rules =~ make_rule_matcher
      @loginator.lazy( Verbosity::DEBUG ) do
        "Preprocessor #include extraction failed: #{shell_result[:output]}"
      end

      return false, []
    end

    includes = []

    # Extract the #include dependencies from the "phony" make rules, one per line
    includes = make_rules.scan( include_matcher )
    includes.flatten! # Regex results can be nested arrays becuase of paren captures
    includes.uniq!

    # Convert list of fileapth strings to list of UserInclude objects
    includes.map! { |_include| UserInclude.new(_include) }

    return true, includes
  end

  # # Extract mocks from each list of includes:
  # #  - Ensure no mock generation build directory paths in mock listings.
  # #  - But, preserve subdirectory paths of include directives (e.g. `#include "subdir/mock_file.h"`)
  # def extract_mocks(*lists)
  #   mocks = []

  #   # Bail out early if mocks are not enabled
  #   return [] if !@configurator.project_use_mocks

  #   # Process each list of includes
  #   lists.each do |list| 
  #     list.each do |include|
  #       # Only process a mock include
  #       next if !include.filename.start_with?( @configurator.cmock_mock_prefix )
        
  #       # Omit mock generation build path from the include directive
  #       if include.filepath.include?( @configurator.cmock_mock_path )
  #         mocks << UserInclude.new(include.filename) 
  #       # Otherwise, preserve the subdirectory path of the include directive
  #       else
  #         mocks << include
  #       end
  #     end
  #   end

  #   return mocks.uniq()
  # end

  # # Return list of includes with any mocks removed
  # def remove_mocks(includes)
  #   return includes.reject { |include| include.filename.start_with?( @configurator.cmock_mock_prefix ) }
  # end

  # # Return includes common in both lists with the full paths of the nested list
  # def common_includes(shallow:, nested:, explicit:)
  #   return shallow if nested.empty?
  #   return nested if shallow.empty?

  #   # Notes:
  #   #  - We want to preserve filepaths whenever possible. Other areas of Ceedling use or discard the 
  #   #    filepath as needed.
  #   #  - We generally do not have filepaths in the shallow list--except when the #include is in the 
  #   #    same directory as the file being processed

  #   # Approach
  #   #  1. Create hashed lists of shallow and nested for easier matching 
  #   #  2. Perform appropriate mix of paths
  #   #    a. A union if performing a deep include list
  #   #    b. An intersection if performing a shallow include list
  #   #  3. Pick the "fullest" path from the lists (assumes nested list has deeper paths)

  #   # Hash list for Shallow Search
  #   _shallow = {}
  #   shallow.each { |item| _shallow[ File.basename(item) ] = item }

  #   # Hash list for Nested Search
  #   _nested = {}
  #   nested.each {|item|  _nested[ File.basename(item) ] = item }

  #   # Determine the filenames to include in our list
  #   basenames = if deep
  #     ( _nested.keys.to_set.union( _shallow.keys.to_set ) )
  #   else
  #     # Intersection of both arrays plus filtering against explicit includes.
  #     # This removes any includes unearthed from deep in the code (e.g. system or host includes)
  #     ( _nested.keys.to_set.intersection( _shallow.keys.to_set ) ).intersection( explicit )
  #   end

  #   # Iterate through the basenames and return the fullest version of each
  #   return basenames.map {|v| _nested[v] || _shallow[v] }
  # end

end
