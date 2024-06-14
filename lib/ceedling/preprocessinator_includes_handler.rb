# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class PreprocessinatorIncludesHandler

  constructor :configurator, :tool_executor, :test_context_extractor, :yaml_wrapper, :loginator, :reportinator

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

  def extract_includes(filepath:, test:, flags:, include_paths:, defines:)
    msg = @reportinator.generate_module_progress(
      operation: "Extracting #include statements via preprocessor from",
      module_name: test,
      filename: File.basename(filepath)
      )
    @loginator.log(msg, Verbosity::NORMAL)

    # Extract shallow includes with preprocessor and fallback regex
    shallow = extract_shallow_includes(
      test:     test,
      filepath: filepath,
      flags:    flags,
      defines:  defines
      )

    # Extract nested includes but optionally act in fallback mode
    nested = extract_nested_includes(
      filepath:      filepath,
      include_paths: include_paths,
      flags:         flags,
      defines:       defines,
      # If no shallow results, fall back to only depth 1 results of nested discovery
      shallow:       shallow.empty?
      )

    # Combine shallow and nested include knowledge of mocks
    mocks = combine_mocks(shallow, nested)

    # Redefine shallow and nested results without any mocks
    shallow = remove_mocks( shallow )
    nested  = remove_mocks( nested )

    # Return
    #  - Includes common to shallow and nested results, with paths from nested
    #  - Add mocks back in (may be empty if mocking not enabled)
    return common_includes(shallow:shallow, nested:nested) + mocks
  end

  # Write to disk a yaml representation of a list of includes
  def write_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, list)
  end

  ### Private ###
  private

  def extract_shallow_includes(test:, filepath:, flags:, defines:)
    # Shallow includes extraction, first attempt with preprocessor
    success, shallow = 
      extract_shallow_includes_preprocessor(
        test:     test,
        filepath: filepath,
        flags:    flags,
        defines:  defines
        )

    # Shallow includes extraction, second attempt with file read + regex
    if not success
      shallow = extract_shallow_includes_regex(
        test:     test,
        filepath: filepath,
        flags:    flags,
        defines:  defines
        )
    end

    return shallow
  end

  def extract_shallow_includes_preprocessor(test:, filepath:, flags:, defines:)
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
        @configurator.tools_test_shallow_includes_preprocessor,
        flags,
        filepath,
        defines
        )

    # Assume possible errors so we have best shot at extracting results from preprocessing.
    # Full code compilation will catch any breaking code errors
    command[:options][:boom] = false
    shell_result = @tool_executor.exec( command )

    make_rules = shell_result[:output]

    # Do not check exit code for success. In some error conditions we still get usable output.
    # Look for the first line of the make rule output.
    if not make_rules =~ make_rule_matcher
      msg = "Preprocessor #include extraction failed: #{shell_result[:output]}"
      @loginator.log(msg, Verbosity::DEBUG)

      return false, []
    end

    includes = []

    # Extract the #include dependencies from the "phony" make rules, one per line
    includes = make_rules.scan( include_matcher )
    includes.flatten! # Regex results can be nested arrays becuase of paren captures

    return true, includes.uniq
  end

  def extract_shallow_includes_regex(test:, filepath:, flags:, defines:)
    msg = @reportinator.generate_module_progress(
      operation: "Using fallback regex #include extraction for",
      module_name: test,
      filename: File.basename( filepath )
      )
    @loginator.log(msg, Verbosity::NORMAL)

    # Use abilities of @test_context_extractor to extract the #includes via regex on the file
    return @test_context_extractor.extract_includes( filepath )
  end

  def extract_nested_includes(filepath:, include_paths:, flags:, defines:, shallow:false)
    ##
    ## Preprocessor Header File Listing Handling
    ## =========================================
    ##
    ## Creation:
    ##  - This output is created with the -MM -MG -H command line options.
    ##    - -MM -MG generates unused make rule that significantly reduces overall output.
    ##    - -H creates the header file output listing we actually want.
    ##  - Search paths are provided towards fully preprocessing all macros / conditionals and
    ##    symbols. (This produces a rich list of #includes far greater than we need.)
    ##
    ## Format (ignoring throwaway make rule):
    ##  - Each included filepath is listed per line.
    ##  - The depth of the #include nesting is signified by precending '.'s.
    ##  - Files directly #include'd in the file being preprocessed are at depth 1 ('.')
    ##
    ## Notes:
    ##  - Because search paths and defines are provided, error-free execution is assumed.
    ##    If the preprocessor fails, issues exist that will cause full compilation to fail.
    ##  - Unfortuantely, because of ordering and nesting effects, a file directly #include'd may
    ##    not be listed at depth 1 ('.'). Instead, it may end up listed at greater depth beneath 
    ##    another #include'd file if both files reference it. That is, there is no way
    ##    to give the preprocessor full context and ask for only the files directly 
    ##    #include'd in the file being processed.
    ##  - The preprocessor outputs the -H #include listing to STDERR. ToolExecutor does this
    ##    by default in creating the shell result output.
    ##  - Since we're using search paths, all #included files will include paths. Depending on
    ##    circumstances, this could yield a list with generated mocks with full build paths.
    ##
    ## Approach:
    ##  - Match on each listing line a filepath preceeded by its depth
    ##  - One mode of using this preprocessor approach is as a fallback / double-check method 
    ##    if the simpler, earler shallow preprocessing produces no #include results. When used
    ##    this way we match only #include'd files at depth 1 ('.'), hoping we extract an
    ##    appropriate, usable list of #includes.
    ## 
    ## Example output follows
    ## -----------------------------------------------------------------------------------------
    ## . build/vendor/unity/src/unity.h
    ## .. build/vendor/unity/src/unity_internals.h
    ## . src/Types.h
    ## . src/Model.h
    ## . src/TimerModel.h
    ## .. src/Testing.h
    ## TestModel.o: test/TestModel.c build/vendor/unity/src/unity.h \
    ##   build/vendor/unity/src/unity_internals.h setjmp.h math.h stddef.h \
    ##   stdint.h limits.h stdio.h src/Types.h src/Model.h src/TimerModel.h \
    ##   src/Testing.h MockTaskScheduler.h MockTemperatureFilter.h
    ##

    command = 
      @tool_executor.build_command_line(
        @configurator.tools_test_nested_includes_preprocessor,
        flags,
        filepath,
        include_paths,
        defines
      )

    # Let the preprocessor do as much as possible
    # We'll extract nothing if a catastrophic error, but we'll see it in debug logging
    # Any real problems will be flagged by actual compilation step
    command[:options][:boom] = false

    shell_result = @tool_executor.exec( command )

    list = shell_result[:output]

    includes = []

    # Extract entries from #include listing
    if shallow
      # First level of includes in preprocessor output
      includes = list.scan(/^\. (.+$)\s*$/)  # . <filepath>
    else
      # All levels of includes in preprocessor output
      includes = list.scan(/^\.+ (.+$)\s*$/) # ... <filepath>
    end

    includes.flatten! # Regex results can be nested arrays becuase of paren captures

    return includes.uniq
  end

  def combine_mocks(*lists)
    # Handle mocks
    #  - Ensure no build filepaths in mock listings
    #  - Do not return mocks if mocking is disabled
    mocks = []

    if @configurator.project_use_mocks
      # Use some greediness to ensure we get all possible mocks
      lists.each { |list| mocks |= extract_mocks( list ) }      
    end

    return mocks
  end

  # Return a list of mock .h files with no paths
  def extract_mocks(includes)
    return includes.select { |include| File.basename(include).start_with?( @configurator.cmock_mock_prefix ) }
  end

  # Return list of includes with any mocks removed
  def remove_mocks(includes)
    return includes.reject { |include| File.basename(include).start_with?( @configurator.cmock_mock_prefix ) }
  end

  # Return includes common in both lists with the full paths of the nested list
  def common_includes(shallow:, nested:)
    return shallow if nested.empty?
    return nested if shallow.empty?

    # Notes:
    #  - We want to preserve filepaths whenever possible. Other areas of Ceedling use or discard the 
    #    filepath as needed.
    #  - We generally do not have filepaths in the shallow list--except when the #include is in the 
    #    same directory as the file being processed

    # Approach
    #  1. Create hashed lists of shallow and nested for easier matching / deletion
    #  2. Iterate through nested hash list and extract to common[] any filepath also in shallow
    #  3. For each filepath extracted
    #    a. Delete it from the nested hash list
    #    b. Delete the corresponding entry in the shallow hash list
    #  4. Iterate remaining nested hash list and extract to common[] and filepath whose base
    #     filename matches a remaining entry in the shallow hash list

    common = []

    # Hash list
    _shallow = {}
    shallow.each { |item| _shallow[item] = nil }

    # Hash list
    _nested = {}
    nested.each { |item| _nested[item] = nil }

    # Iterate each _nested entry and extract filepaths with matching filepath in _shallow list
    _nested.each_key do |filepath|
      if _shallow.has_key?( filepath )
        common << filepath         # Copy to common
        _shallow.delete(filepath)  # Remove matching filepath from _shallow list
      end
    end

    # For each mached filepath, remove it from _nested list
    common.each { |item| _nested.delete(item) }

    # Find any reamining filepaths whose baseneame matches an entry in _shallow
    _nested.each_key do |filepath|
      common << filepath if _shallow.has_key?( File.basename(filepath) )
    end

    return common
  end

end
