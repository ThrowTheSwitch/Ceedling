require 'constants' # for Verbosity constants class


class Generator

  constructor :configurator, :preprocessinator, :cmock_builder, :generator_test_runner, :generator_test_results, :test_includes_extractor, :tool_executor, :file_finder, :file_path_utils, :streaminator, :plugin_manager, :file_wrapper


  def generate_shallow_includes_list(file)
    @preprocessinator.preprocess_shallow_includes(file)
  end

  def generate_preprocessed_file(file)
    @streaminator.stdout_puts("Preprocessing #{File.basename(file)}...", Verbosity::NORMAL)
    @preprocessinator.preprocess_file(file)
  end

  def generate_dependencies_file(tool, source, object, dependencies)
    @streaminator.stdout_puts("Generating dependencies for #{File.basename(source)}...", Verbosity::NORMAL)
    
    command_line = 
      @tool_executor.build_command_line(
        tool,
        source,
        dependencies,
        object)
    
    @tool_executor.exec(command_line)
  end

  def generate_mock(header_file)
    arg_hash = {:header_file => header_file}
    @plugin_manager.pre_mock_execute(arg_hash)
    
    @cmock_builder.cmock.setup_mocks( @preprocessinator.form_file_path(arg_hash[:header_file]) )

    @plugin_manager.post_mock_execute(arg_hash)
  end

  def generate_test_runner(raw_test_file, test_runner_file)
    test_file_to_parse = @preprocessinator.form_file_path(raw_test_file)

    arg_hash = {:test_file => test_file_to_parse, :runner_file => test_runner_file}
    @plugin_manager.pre_runner_execute(arg_hash)
    
    # collect info we need
    module_name = File.basename(arg_hash[:test_file])
    test_cases  = @generator_test_runner.find_test_cases(arg_hash[:test_file], raw_test_file)
    mock_list   = @test_includes_extractor.lookup_raw_mock_list(arg_hash[:test_file])
    
    @streaminator.stdout_puts("Creating test runner for #{module_name}...", Verbosity::NORMAL)

    # build runner file
    @file_wrapper.open(arg_hash[:runner_file], 'w') do |output|
      @generator_test_runner.create_header(output, mock_list)
      @generator_test_runner.create_externs(output, test_cases)
      @generator_test_runner.create_mock_management(output, mock_list)
      @generator_test_runner.create_runtest(output, mock_list, test_cases)
      @generator_test_runner.create_main(output, module_name, test_cases)
    end

    @plugin_manager.post_runner_execute(arg_hash)
  end

  def generate_object_file(tool, source, object)    
    arg_hash = {:tool => tool, :source => source, :object => object}
    @plugin_manager.pre_compile_execute(arg_hash)

    @streaminator.stdout_puts("Compiling #{File.basename(arg_hash[:source])}...", Verbosity::NORMAL)
    output = @tool_executor.exec( @tool_executor.build_command_line(arg_hash[:tool], arg_hash[:source], arg_hash[:object]) )

    arg_hash[:tool_output] = output
    @plugin_manager.post_compile_execute(arg_hash)
  end

  def generate_executable_file(tool, objects, executable)
    arg_hash = {:tool => tool, :objects => objects, :executable => executable}
    @plugin_manager.pre_link_execute(arg_hash)
    
    @streaminator.stdout_puts("Linking #{File.basename(arg_hash[:executable])}...", Verbosity::NORMAL)
    output = @tool_executor.exec( @tool_executor.build_command_line(arg_hash[:tool], arg_hash[:objects], arg_hash[:executable]) )
    
    arg_hash[:tool_output] = output
    @plugin_manager.post_link_execute(arg_hash)
  end

  def generate_test_results(tool, executable, result)
    arg_hash = {:tool => tool, :executable => executable, :result => result}
    @plugin_manager.pre_test_execute(arg_hash)
    
    @streaminator.stdout_puts("Running #{File.basename(arg_hash[:executable])}...", Verbosity::NORMAL)
    output = @tool_executor.exec( @tool_executor.build_command_line(arg_hash[:tool], arg_hash[:executable]) )
    
    if (output.nil? or output.strip.empty?)
      @streaminator.stderr_puts("ERROR: Test executable \"#{File.basename(executable)}\" did not produce any results.", Verbosity::ERRORS)
      raise
    end
    
    @generator_test_results.process_and_write_results(output, arg_hash[:result], @file_finder.find_test_from_file_path(arg_hash[:executable]))
    
    arg_hash[:tool_output] = output
    @plugin_manager.post_test_execute(arg_hash)
  end
  
end
