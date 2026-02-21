# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/includes'
require 'ceedling/preprocess/preprocessinator_bare_includes_extractor'

class PreprocessinatorIncludesHandler

  constructor(
    :configurator,
    :preprocessinator_system_includes_extractor,
    :include_factory,
    :tool_executor,
    :file_wrapper,
    :yaml_wrapper,
    :parsing_parcels,
    :loginator,
    :reportinator
  )

  def setup()
    # Aliases
    @system_includes_extractor = @preprocessinator_system_includes_extractor
  end

  def extract_bare_includes(test:, filepath:, search_paths:, flags:, defines:)
    filename = File.basename(filepath)

    msg = @reportinator.generate_module_progress(
      operation: "Extracting bare #includes via preprocessing from",
      module_name: test,
      filename: filename
    )
    @loginator.log( msg, Verbosity::OBNOXIOUS )

    # Creation:
    #  - This output is created with the -MM -MG -MP command line options.
    #  - Limited search paths are used towards shallow extracting of only the user #include statements of the file.
    #    This preprocessor mode assumes any includes discovered outside of a search path will be generated.
    #
    # Notes:
    #  - This approach can have gaps with complex macros / conditional statements.
    #    Gaps can be minimized with proper defines in the project file. However, needed / complex macros 
    #    located in other header files can still gum up the works.
    #  - Many errors can occur but may not necessarily prevent usable results.
    command = 
      @tool_executor.build_command_line(
        @configurator.tools_test_bare_includes_preprocessor,
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
    if not make_rules =~ PreprocessinatorBareIncludesExtractor::MAKE_RULE_MATCHER
      @loginator.lazy( Verbosity::DEBUG ) do
        "Preprocessor bare #include extraction failed: #{shell_result[:output]}"
      end
      return []
    end

    includes = PreprocessinatorBareIncludesExtractor.extract_includes( make_rules )
    includes = clean_self_reference(filepath, includes)

    header = "Extracted bare #includes from #{filepath}"
    @loginator.log_list( includes, header, Verbosity::DEBUG )

    return includes
  end

  def extract_system_includes(name:, filepath:, preprocessed_filepath:, fallback: false)
    includes = []

    filename = File.basename(filepath)

    if !fallback
      msg = @reportinator.generate_module_progress(
        operation: "Extracting system #includes from preprocessed output",
        module_name: name,
        filename: filename
      )
      @loginator.log(msg, Verbosity::OBNOXIOUS)

      # Get system includes from up to 3 levels of nested headers.
      # This may extract more system includes than necessary but ensures we don't
      # miss top-level system includes hidden by nesting include guards.
      # Later santization uses system includes slurped up in the top-level user 
      # include extraction to identify the actual needed system includes and filter
      # out any extras.
      includes = @system_includes_extractor.extract_includes_from_file( preprocessed_filepath, max_depth: 3 )
      includes = clean_self_reference(filepath, includes)
    else
      msg = @reportinator.generate_module_progress(
        operation: "Extracting system #includes from original file (fallback)",
        module_name: name,
        filename: filename
      )
      @loginator.log( msg, Verbosity::OBNOXIOUS )

      @file_wrapper.open(filepath, 'r') do |input|
        @parsing_parcels.code_lines( input ) do |line|
          _include = @include_factory.system_include_from_directive( line )
          includes << _include if !_include.nil?
        end
      end
    end

    header = "Extracted system #include list from #{filepath}"
    @loginator.log_list( includes, header, Verbosity::DEBUG )

    return includes
  end

  # Write to disk a yaml representation of a list of includes
  def write_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, Includes.to_hashes(list))
  end

  def load_includes_list(filepath)
    return Includes.from_hashes(
      # Note: It's possible empty YAML content returns nil so ensure empty list
      @yaml_wrapper.load( filepath ) || []
    )
  end

  ### Private ###
  private

  # Remove any filepath in the includes list that is identical to the filepath being processed.
  # We want to prevent an includes list containing an unnecessary self-reference.
  # Use normalized paths for comparison to handle variations (relative vs absolute, different separators, etc.)
  def clean_self_reference(filepath, includes)
    _filepath = File.expand_path(filepath)
    Includes.sanitize!(includes) do |include, _|
      _filepath == File.expand_path(include.filepath)
    end
    return includes
  end

end
