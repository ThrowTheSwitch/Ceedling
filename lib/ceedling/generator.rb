require 'ceedling/constants'
require 'ceedling/file_path_utils'
require 'rake'

class Generator

  constructor :configurator,
              :generator_helper,
              :preprocessinator,
              :generator_mocks,
              :generator_test_runner,
              :generator_test_results,
              :test_context_extractor,
              :tool_executor,
              :file_finder,
              :file_path_utils,
              :reportinator,
              :streaminator,
              :plugin_manager,
              :file_wrapper,
              :debugger_utils,
              :unity_utils


  def generate_mock(context:, mock:, test:, input_filepath:, output_path:)
    arg_hash = {
      :header_file => input_filepath,
      :test => test,
      :context => context,
      :output_path => output_path }
    
    @plugin_manager.pre_mock_generate( arg_hash )

    begin
      # Below is a workaround that instantiates CMock anew:
      #  1. To allow dfferent output path per mock
      #  2. To avoid any thread safety complications

      # TODO:
      #  - Add option to CMock to generate mock to any destination path
      #  - Make CMock thread-safe

      # Get default config created by Ceedling and customize it
      config = @generator_mocks.build_configuration( output_path )
  
      # Generate mock
      msg = @reportinator.generate_module_progress(
        operation: "Generating mock for",
        module_name: test,
        filename: File.basename(input_filepath)
      )
      @streaminator.stdout_puts(msg, Verbosity::NORMAL)

      cmock = @generator_mocks.manufacture( config )
      cmock.setup_mocks( arg_hash[:header_file] )
    rescue
      raise
    ensure
      @plugin_manager.post_mock_generate( arg_hash )
    end
  end

  # test_filepath may be either preprocessed test file or original test file
  def generate_test_runner(context:, mock_list:, test_filepath:, input_filepath:, runner_filepath:)
    arg_hash = {
      :context => context,
      :test_file => test_filepath,
      :input_file => input_filepath,
      :runner_file => runner_filepath}

    @plugin_manager.pre_runner_generate(arg_hash)

    # Instantiate the test runner generator each time needed for thread safety
    # TODO: Make UnityTestRunnerGenerator thread-safe
    generator = @generator_test_runner.manufacture()

    # collect info we need
    module_name = File.basename( arg_hash[:test_file] )
    test_cases  = @generator_test_runner.find_test_cases(
      generator: generator,
      test_filepath:  arg_hash[:test_file],
      input_filepath: arg_hash[:input_file]
      )

    msg = @reportinator.generate_progress("Generating runner for #{module_name}")
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    # build runner file
    begin
      @generator_test_runner.generate(
        generator: generator,
        module_name: module_name,
        runner_filepath: runner_filepath,
        test_cases: test_cases,
        mock_list: mock_list)
    rescue
      raise
    ensure
      @plugin_manager.post_runner_generate(arg_hash)
    end
  end

  def generate_object_file_c(
      tool:,
      module_name:,
      context:,
      source:,
      object:,
      search_paths:[],
      flags:[],
      defines:[],
      list:'',
      dependencies:'',
      msg:nil
    )

    shell_result = {}
    arg_hash = { :tool => tool,
                 :module_name => module_name,
                 :operation => OPERATION_COMPILE_SYM,
                 :context => context,
                 :source => source,
                 :object => object,
                 :search_paths => search_paths,
                 :flags => flags,
                 :defines => defines,
                 :list => list,
                 :dependencies => dependencies
               }

    @plugin_manager.pre_compile_execute(arg_hash)

    msg = String(msg)
    msg = @reportinator.generate_module_progress(
      operation: "Compiling",
      module_name: module_name,
      filename: File.basename(arg_hash[:source])
      ) if msg.empty?
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    command =
      @tool_executor.build_command_line(
        arg_hash[:tool],
        arg_hash[:flags],
        arg_hash[:source],
        arg_hash[:object],
        arg_hash[:list],
        arg_hash[:dependencies],
        arg_hash[:search_paths],
        arg_hash[:defines]
      )


    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellExecutionException => ex
      shell_result = ex.shell_result
      raise ex
    ensure
      arg_hash[:shell_command] = command[:line]
      arg_hash[:shell_result] = shell_result
      @plugin_manager.post_compile_execute(arg_hash)
    end
  end

  def generate_object_file_asm(
      tool:,
      module_name:,
      context:,
      source:,
      object:,
      search_paths:[],
      flags:[],
      defines:[],
      list:'',
      dependencies:'',
      msg:nil
    )

    shell_result = {}

    arg_hash = { :tool => tool,
                 :module_name => module_name,
                 :operation => OPERATION_ASSEMBLE_SYM,
                 :context => context,
                 :source => source,
                 :object => object,
                 :search_paths => search_paths,
                 :flags => flags,
                 :defines => defines,
                 :list => list,
                 :dependencies => dependencies
               }

    @plugin_manager.pre_compile_execute(arg_hash)

    msg = String(msg)
    msg = @reportinator.generate_module_progress(
      operation: "Assembling",
      module_name: module_name,
      filename: File.basename(arg_hash[:source])
      ) if msg.empty?
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    command =
      @tool_executor.build_command_line( 
        arg_hash[:tool],
        arg_hash[:flags],
        arg_hash[:source],
        arg_hash[:object],
        arg_hash[:search_paths],
        arg_hash[:defines],
        arg_hash[:list],
        arg_hash[:dependencies]
      )


    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellExecutionException => ex
      shell_result = ex.shell_result
      raise ex
    ensure
      arg_hash[:shell_command] = command[:line]
      arg_hash[:shell_result] = shell_result
      @plugin_manager.post_compile_execute(arg_hash)
    end
  end

  def generate_executable_file(tool, context, objects, flags, executable, map='', libraries=[], libpaths=[])
    shell_result = {}
    arg_hash = { :tool => tool,
                 :context => context,
                 :objects => objects,
                 :flags => flags,
                 :executable => executable,
                 :map => map,
                 :libraries => libraries,
                 :libpaths => libpaths
               }

    @plugin_manager.pre_link_execute(arg_hash)

    msg = @reportinator.generate_progress("Linking #{File.basename(arg_hash[:executable])}")
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    command =
      @tool_executor.build_command_line(
        arg_hash[:tool],
        arg_hash[:flags],
        arg_hash[:objects],
        arg_hash[:executable],
        arg_hash[:map],
        arg_hash[:libraries],
        arg_hash[:libpaths]
      )

    begin
      shell_result = @tool_executor.exec( command )
    rescue ShellExecutionException => ex
      shell_result = ex.shell_result
      raise ex
    ensure
      arg_hash[:shell_command] = command[:line]
      arg_hash[:shell_result] = shell_result
      @plugin_manager.post_link_execute(arg_hash)
    end
  end

  def generate_test_results(tool:, context:, test_name:, test_filepath:, executable:, result:)
    arg_hash = {
      :tool => tool,
      :context => context,
      :test_name => test_name,
      :test_filepath => test_filepath,
      :executable => executable,
      :result_file => result
    }

    @plugin_manager.pre_test_fixture_execute(arg_hash)

    msg = @reportinator.generate_progress("Running #{File.basename(arg_hash[:executable])}")
    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    # Unity's exit code is equivalent to the number of failed tests, so we tell @tool_executor not to fail out if there are failures
    # so that we can run all tests and collect all results
    command = @tool_executor.build_command_line(arg_hash[:tool], [], arg_hash[:executable])

    # Configure debugger
    @debugger_utils.configure_debugger(command)

    # Apply additional test case filters 
    command[:line] += @unity_utils.collect_test_runner_additional_args

    # Enable collecting GCOV results even when segmenatation fault is appearing
    # The gcda and gcno files will be generated for a test cases which doesn't
    # cause segmentation fault
    @debugger_utils.enable_gcov_with_gdb_and_cmdargs(command)

    # Run the test itself (allow it to fail. we'll analyze it in a moment)
    command[:options][:boom] = false
    shell_result = @tool_executor.exec( command )

    # Handle SegFaults
    if shell_result[:output] =~ /\s*Segmentation\sfault.*/i
      if @configurator.project_config_hash[:project_use_backtrace] && @configurator.project_config_hash[:test_runner_cmdline_args]
        # If we have the options and tools to learn more, dig into the details
        shell_result = @debugger_utils.gdb_output_collector(shell_result)
      else
        # Otherwise, call a segfault a single failure so it shows up in the report
        source = File.basename(executable).ext(@configurator.extension_source)
        shell_result[:output] = "#{source}:1:test_Unknown:FAIL:Segmentation Fault" 
        shell_result[:output] += "\n-----------------------\n1 Tests 1 Failures 0 Ignored\nFAIL\n"
        shell_result[:exit_code] = 1
      end
    else
      # Don't Let The Failure Count Make Us Believe Things Aren't Working
      @generator_helper.test_results_error_handler(executable, shell_result)
    end

    processed = @generator_test_results.process_and_write_results( shell_result,
                                                                   arg_hash[:result_file],
                                                                   @file_finder.find_test_from_file_path(arg_hash[:executable]) )

    arg_hash[:result_file]  = processed[:result_file]
    arg_hash[:results]      = processed[:results]
    arg_hash[:shell_result] = shell_result # for raw output display if no plugins for formatted display

    @plugin_manager.post_test_fixture_execute(arg_hash)
  end

end
