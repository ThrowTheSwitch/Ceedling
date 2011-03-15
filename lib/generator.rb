require 'constants' # for Verbosity constants class


class Generator

  constructor :configurator, :preprocessinator, :cmock_builder, :generator_test_runner, :generator_test_results, :test_includes_extractor, :tool_executor, :file_finder, :file_path_utils, :streaminator, :plugin_manager, :file_wrapper


  def generate_shallow_includes_list(context, file)
    @preprocessinator.preprocess_shallow_includes(file)
  end

  def generate_preprocessed_file(context, file)
    @streaminator.stdout_puts("Preprocessing #{File.basename(file)}...", Verbosity::NORMAL)
    @preprocessinator.preprocess_file(file)
  end

  def generate_dependencies_file(tool, context, source, object, dependencies)
    @streaminator.stdout_puts("Generating dependencies for #{File.basename(source)}...", Verbosity::NORMAL)
    
    command_line = 
      @tool_executor.build_command_line(
        tool,
        source,
        dependencies,
        object)
    
    @tool_executor.exec(command_line)
  end

  def generate_mock(context, header_filepath)
    arg_hash = {:header_file => header_filepath, :context => context}
    @plugin_manager.pre_mock_execute(arg_hash)
    
    @cmock_builder.cmock.setup_mocks( arg_hash[:header_file] )

    @plugin_manager.post_mock_execute(arg_hash)
  end

  # test_filepath may be either preprocessed test file or original test file
  def generate_test_runner(context, test_filepath, runner_filepath)
    arg_hash = {:context => context, :test_file => test_filepath, :runner_file => runner_filepath}

    @plugin_manager.pre_runner_execute(arg_hash)
    
    # collect info we need
    module_name = File.basename(arg_hash[:test_file])
    test_cases  = @generator_test_runner.find_test_cases( @file_finder.find_test_from_runner_path(runner_filepath) )
    mock_list   = @test_includes_extractor.lookup_raw_mock_list(arg_hash[:test_file])

    @streaminator.stdout_puts("Generating runner for #{module_name}...", Verbosity::NORMAL)
    
    # build runner file
    @file_wrapper.open(runner_filepath, 'w') do |output|
      @generator_test_runner.create_header(output, mock_list)
      @generator_test_runner.create_externs(output, test_cases)
      @generator_test_runner.create_mock_management(output, mock_list)
      @generator_test_runner.create_runtest(output, mock_list, test_cases)
      @generator_test_runner.create_main(output, module_name, test_cases)
    end

    @plugin_manager.post_runner_execute(arg_hash)
  end

  def generate_object_file(tool, context, source, object)    
    arg_hash = {:tool => tool, :context => context, :source => source, :object => object}
    @plugin_manager.pre_compile_execute(arg_hash)

    @streaminator.stdout_puts("Compiling #{File.basename(arg_hash[:source])}...", Verbosity::NORMAL)
    shell_result = @tool_executor.exec( @tool_executor.build_command_line(arg_hash[:tool], arg_hash[:source], arg_hash[:object]) )

    arg_hash[:shell_result] = shell_result
    @plugin_manager.post_compile_execute(arg_hash)
  end

  def generate_executable_file(tool, context, objects, executable)
    shell_result = {}
    arg_hash = {:tool => tool, :context => context, :objects => objects, :executable => executable}
    @plugin_manager.pre_link_execute(arg_hash)
    
    @streaminator.stdout_puts("Linking #{File.basename(arg_hash[:executable])}...", Verbosity::NORMAL)
    
    begin
      shell_result = @tool_executor.exec( @tool_executor.build_command_line(arg_hash[:tool], arg_hash[:objects], arg_hash[:executable]) )
    rescue
      notice =    "\n" +
                  "NOTICE: If the linker reports missing symbols, the following may be to blame:\n" +
                  "  1. Test lacks #include statements corresponding to needed source files.\n" +
                  "  2. Project search paths do not contain source files corresponding to #include statements in the test.\n"
      
      if (@configurator.project_use_mocks)
        notice += "  3. Test does not #include needed mocks.\n\n"
      else
        notice += "\n"
      end
               
      @streaminator.stderr_puts(notice, Verbosity::COMPLAIN)
      raise
    end
    
    arg_hash[:shell_result] = shell_result
    @plugin_manager.post_link_execute(arg_hash)
  end

  def generate_test_results(tool, context, executable, result)
    arg_hash = {:tool => tool, :context => context, :executable => executable, :result_file => result}
    @plugin_manager.pre_test_execute(arg_hash)
    
    @streaminator.stdout_puts("Running #{File.basename(arg_hash[:executable])}...", Verbosity::NORMAL)
    
    # Unity's exit code is equivalent to the number of failed tests, so we tell @tool_executor not to fail out if there are failures
    # so that we can run all tests and collect all results
    shell_result = @tool_executor.exec( @tool_executor.build_command_line(arg_hash[:tool], arg_hash[:executable]), [], {:boom => false} )
    
    if (shell_result[:output].nil? or shell_result[:output].strip.empty?)
      @streaminator.stderr_puts("ERROR: Test executable \"#{File.basename(executable)}\" did not produce any results.", Verbosity::ERRORS)
      raise
    end
    
    processed = @generator_test_results.process_and_write_results( shell_result,
                                                                   arg_hash[:result_file],
                                                                   @file_finder.find_test_from_file_path(arg_hash[:executable]) )
    
    arg_hash[:result_file]  = processed[:result_file]
    arg_hash[:results]      = processed[:results]
    arg_hash[:shell_result] = shell_result # for raw output display if no plugins for formatted display
    
    @plugin_manager.post_test_execute(arg_hash)
  end
  
end
