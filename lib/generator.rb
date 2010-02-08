require 'constants' # for Verbosity constants class


class Generator

  constructor :configurator, :preprocessinator, :cmock_factory, :generator_test_runner, :generator_test_results, :test_includes_extractor, :tool_executor, :file_finder, :file_path_utils, :streaminator, :plugin_manager, :file_wrapper


  def setup
    @cmock = nil
  end

  def generate_shallow_includes_list(file)
    @preprocessinator.preprocess_shallow_includes(file)
  end

  def generate_preprocessed_file(file)
    @streaminator.stdout_puts("Preprocessing #{File.basename(file)}...", Verbosity::NORMAL)
    @preprocessinator.preprocess_file(file)
  end

  def generate_dependencies_file(source, dependencies)
    @streaminator.stdout_puts("Generating dependencies for #{File.basename(source)}...", Verbosity::NORMAL)
    
    command_line = 
      @tool_executor.build_command_line(
        @configurator.tools_dependencies_generator,
        source,
        dependencies,
        @file_path_utils.form_object_filepath(source))
    
    @tool_executor.exec(command_line)
  end

  def generate_mock(header_file)
    # delay building cmock object until needed to allow for cmock_config changes after loading project file
    @cmock = @cmock_factory.manufacture(@configurator.cmock_config_hash) if (@cmock.nil?)
    
    @cmock.setup_mocks( @preprocessinator.form_file_path(header_file) )
  end

  def generate_test_runner(test_file, test_runner_file)
    test_file_to_parse = @preprocessinator.form_file_path(test_file)
    
    # collect info we need
    module_name = File.basename(test_file_to_parse)
    test_cases  = @generator_test_runner.find_test_cases(test_file_to_parse)
    mock_list   = @test_includes_extractor.lookup_raw_mock_list(test_file_to_parse)
    
    @streaminator.stdout_puts("Creating test runner for #{module_name}...", Verbosity::NORMAL)

    # build runner file
    @file_wrapper.open(test_runner_file, 'w') do |output|
      @generator_test_runner.create_header(output, mock_list)
      @generator_test_runner.create_externs(output, test_cases)
      @generator_test_runner.create_mock_management(output, mock_list)
      @generator_test_runner.create_runtest(output, mock_list)
      @generator_test_runner.create_main(output, module_name, test_cases)
    end
  end

  def generate_object_file(source, object)    
    @streaminator.stdout_puts("Compiling #{File.basename(source)}...", Verbosity::NORMAL)
    @tool_executor.exec( @tool_executor.build_command_line(@configurator.tools_test_compiler, source, object) )
  end

  def generate_executable_file(objects, executable)
    @streaminator.stdout_puts("Linking #{File.basename(executable)}...", Verbosity::NORMAL)
    @tool_executor.exec( @tool_executor.build_command_line(@configurator.tools_test_linker, objects, executable) )
  end

  def generate_test_results(executable, result)
    arg_hash = {:executable => executable, :result => result}
    @plugin_manager.pre_test_execute(arg_hash)
    
    @streaminator.stdout_puts("Running #{File.basename(executable)}...", Verbosity::NORMAL)
    raw_output = @tool_executor.exec( @tool_executor.build_command_line(@configurator.tools_test_fixture, executable) )
    
    if (raw_output.nil? or raw_output.strip.empty?)
      @streaminator.stderr_puts("ERROR: Test executable \"#{File.basename(executable)}\" did not produce any results.", Verbosity::ERRORS)
      raise
    end
    
    @generator_test_results.process_and_write_results(raw_output, result, @file_finder.find_test_from_file_path(executable))
    
    @plugin_manager.post_test_execute(arg_hash)
  end
  
end
