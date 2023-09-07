

class PreprocessinatorIncludesHandler

  constructor :configurator, :tool_executor, :test_context_extractor, :yaml_wrapper, :streaminator, :reportinator


  def extract_includes(filepath:, test:, flags:, include_paths:, defines:)
    msg = @reportinator.generate_test_component_progress(
      operation: "Extracting #include statements via preprocessor from",
      test: test,
      filename: File.basename(filepath)
      )
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    success, shallow = 
      extract_shallow_includes_preprocessor(
        test:     test,
        filepath: filepath,
        flags:    flags,
        defines:  defines
        )

    if not success
      shallow = 
        extract_shallow_includes_regex(
          test:     test,
          filepath: filepath,
          flags:    flags,
          defines:  defines
          )
    end

    unless shallow.empty?
      mocks = extract_mocks( shallow )

      nested = extract_nested_includes(
        filepath:      filepath,
        include_paths: include_paths,
        flags:         flags,
        defines:       defines
      )

      shallow -= mocks
      nested  -= extract_mocks( nested )

      return (shallow & nested) + mocks
    end

    return extract_nested_includes(
      filepath:      filepath,
      include_paths: include_paths,
      flags:         flags,
      defines:       defines,
      shallow:       true
      )
  end

  def write_includes_list(filepath, list)
    @yaml_wrapper.dump(filepath, list)
  end

  ### Private ###
  private

  def extract_shallow_includes_preprocessor(test:, filepath:, flags:, defines:)
    command = 
      @tool_executor.build_command_line(
        @configurator.tools_test_shallow_includes_preprocessor,
        flags,
        filepath,
        defines
        )

    @streaminator.stdout_puts("Command: #{command}", Verbosity::DEBUG)

    command[:options][:boom] = false
    shell_result = @tool_executor.exec(command[:line], command[:options])

    if shell_result[:exit_code] != 0
      msg = "Preprocessor #include extraction failed: #{shell_result[:output]}"
      @streaminator.stdout_puts(msg, Verbosity::DEBUG)

      return false, []
    end

    includes = []

    make_rule = shell_result[:output]

    includes = make_rule.scan( /\S+?#{Regexp.escape(@configurator.extension_header)}/ )
    includes.flatten!
    includes.map! { |include| File.basename(include) }

    return true, includes.uniq
  end

  def extract_shallow_includes_regex(test:, filepath:, flags:, defines:)
    msg = @reportinator.generate_test_component_progress(
      operation: "Using fallback regex #include extraction for",
      test: test,
      filename: File.basename( filepath )
      )
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    return @test_context_extractor.scan_includes( filepath )
  end

  def extract_mocks(includes)
    return includes.select { |include| File.basename(include).start_with?( @configurator.cmock_mock_prefix ) }
  end

  def extract_nested_includes(filepath:, include_paths:, flags:, defines:, shallow:false)
    command = 
      @tool_executor.build_command_line(
        @configurator.tools_test_nested_includes_preprocessor,
        flags,
        filepath,
        include_paths,
        defines
        )

    command[:options][:stderr_redirect] = StdErrRedirect::AUTO

    @streaminator.stdout_puts( "Command: #{command}", Verbosity::DEBUG )

    shell_result = @tool_executor.exec( command[:line], command[:options] )

    list = shell_result[:output]

    includes = []

    if shallow
      # First level of includes in preprocessor output
      includes = list.scan(/^\. (.+$)/)      
    else
      # All levels of includes in preprocessor output
      includes = list.scan(/^\.+ (.+$)/)
    end

    includes.flatten!
    includes.map! { |include| File.basename(include) }

    return includes.uniq
  end

end
