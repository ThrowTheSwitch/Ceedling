# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'ceedling/file_path_utils'
require 'rake'

class Generator

  constructor :configurator,
              :generator_helper,
              :preprocessinator,
              :generator_mocks,
              :generator_test_results,
              :test_context_extractor,
              :tool_executor,
              :file_finder,
              :file_path_utils,
              :reportinator,
              :loginator,
              :plugin_manager,
              :file_wrapper,
              :backtrace,
              :unity_utils


  def setup()
    # Alias
    @helper = @generator_helper
  end

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
      @loginator.log( msg )

      cmock = @generator_mocks.manufacture( config )
      cmock.setup_mocks( arg_hash[:header_file] )
    rescue
      raise
    ensure
      @plugin_manager.post_mock_generate( arg_hash )
    end
  end

  def generate_test_runner(context:, mock_list:, test_filepath:, input_filepath:, runner_filepath:)
    arg_hash = {
      :context => context,
      :test_file => test_filepath,
      :input_file => input_filepath,
      :runner_file => runner_filepath}

    @plugin_manager.pre_runner_generate( arg_hash )

    # Collect info we need
    module_name = File.basename( arg_hash[:test_file] )

    msg = @reportinator.generate_progress("Generating runner for #{module_name}")
    @loginator.log( msg )

    unity_test_runner_generator = 
      @test_context_extractor.lookup_test_runner_generator( test_filepath )

    if unity_test_runner_generator.nil?
      msg = "Could not find test runner generator for #{test_filepath}"
      raise CeedlingException.new( msg )
    end

    # Build runner file
    begin
      unity_test_runner_generator.generate(
        module_name: module_name,
        runner_filepath: runner_filepath,
        mock_list: mock_list,
        header_extension: @configurator.extension_header
      )
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
    @loginator.log( msg )

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
    @loginator.log( msg )

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
    @loginator.log( msg )

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
    @loginator.log( msg )

    # Unity's exit code is equivalent to the number of failed tests, so we tell @tool_executor not to fail out if there are failures
    # so that we can run all tests and collect all results
    command = @tool_executor.build_command_line(arg_hash[:tool], [], arg_hash[:executable])

    # Configure debugger
    @backtrace.configure_debugger(command)

    # Apply additional test case filters 
    command[:line] += @unity_utils.collect_test_runner_additional_args

    # Run the test executable itself
    # We allow it to fail without an exception.
    # We'll analyze its results apart from tool_executor
    command[:options][:boom] = false
    shell_result = @tool_executor.exec( command )

    # Handle crashes
    if @helper.test_crash?( shell_result )
      @helper.log_test_results_crash( test_name, executable, shell_result )

      case @configurator.project_config_hash[:project_use_backtrace]
      # If we have the options and tools to learn more, dig into the details
      when :gdb
        shell_result = 
          @backtrace.gdb_output_collector(
            shell_result,
            @test_context_extractor.lookup_test_cases( test_filepath )
          )

      # Simple test-case-by-test-case exercise
      when :simple
        shell_result = 
          @backtrace.do_simple(
            File.basename( test_filepath ),
            command,
            shell_result,
            @test_context_extractor.lookup_test_cases( test_filepath )
          )

      else # :none
        # Otherwise, call a crash a single failure so it shows up in the report
        shell_result = @generator_test_results.create_crash_failure( executable, shell_result )
      end
    end

    processed = @generator_test_results.process_and_write_results( 
      shell_result,
      arg_hash[:result_file],
      @file_finder.find_test_from_file_path(arg_hash[:executable])
    )

    arg_hash[:result_file]  = processed[:result_file]
    arg_hash[:results]      = processed[:results]
    # For raw output display if no plugins enabled for nice display
    arg_hash[:shell_result] = shell_result

    @plugin_manager.post_test_fixture_execute( arg_hash )
  end

end
