
require 'ceedling/par_map'

class TestInvokerHelper

  constructor :configurator, :streaminator, :task_invoker, :test_context_extractor, :file_finder, :file_path_utils, :file_wrapper, :generator, :rake_wrapper

  def execute_build_step(msg, banner: true)
    if banner
      # <Message>
      # ---------
      msg = "\n#{msg}\n#{'-' * msg.length}"
    else
      # <Message>...
      msg = "\n#{msg}..."
    end

    @streaminator.stdout_puts(msg, Verbosity::NORMAL)

    yield # Execute build step block
  end

  def clean_results(results, options)
    @file_wrapper.rm_f( results[:fail] )
    @file_wrapper.rm_f( results[:pass] ) if (options[:force_run])
  end

  def process_deep_dependencies(files)
    return if (not @configurator.project_use_deep_dependencies)

    dependencies_list = @file_path_utils.form_test_dependencies_filelist( files ).uniq

    if @configurator.project_generate_deep_dependencies
      @task_invoker.invoke_test_dependencies_files( dependencies_list )
    end

    yield( dependencies_list ) if block_given?
  end
  
  def extract_sources(test)
    sources  = @test_context_extractor.lookup_source_extras_list(test)
    includes = @test_context_extractor.lookup_header_includes_list(test)
    
    includes.each do |include|
      sources << @file_finder.find_compilation_input_file(include, :ignore)
    end
    
    return sources.compact
  end

  def generate_mocks_now(mock_list)
    par_map(PROJECT_TEST_THREADS, mock_list) do |mock| 
      if (@rake_wrapper[mock].needed?)
        @generator.generate_mock(TEST_SYM, @file_finder.find_header_input_for_mock_file(mock))
      end
    end
  end

  def generate_runners_now(runner_list)
    par_map(PROJECT_TEST_THREADS, runner_list) do |runner|
      if (@rake_wrapper[runner].needed?)
        @generator.generate_test_runner(TEST_SYM, @file_finder.find_test_input_for_runner_file(runner), runner)
      end
    end
  end

  def invalidate_objects(object_list)
    object_list.each do |obj|
      @file_wrapper.rm_f(obj) #TODO eventually these will just be in another subfolder
    end
  end

  def generate_objects_now(object_list, options)
    par_map(PROJECT_COMPILE_THREADS, object_list) do |object|
      if (@rake_wrapper[object].needed?)
        src = @file_finder.find_compilation_input_file(object)
        if (File.basename(src) =~ /#{EXTENSION_SOURCE}$/)
          @generator.generate_object_file(
            options[:test_compiler],
            OPERATION_COMPILE_SYM,
            options[:context],
            src,
            object,
            @file_path_utils.form_test_build_list_filepath( object ),
            @file_path_utils.form_test_dependencies_filepath( object ))
        elsif (defined?(TEST_BUILD_USE_ASSEMBLY) && TEST_BUILD_USE_ASSEMBLY)
          @generator.generate_object_file(
            options[:test_assembler],
            OPERATION_ASSEMBLE_SYM,
            options[:context],
            src,
            object )
        end
      end
    end
  end

  def generate_executable_now(build_path, executable, objects, flags, lib_args, lib_paths, options)
    @generator.generate_executable_file(
      options[:test_linker],
      options[:context],
      objects.map{|v| "\"#{v}\""},
      flags,
      executable,
      @file_path_utils.form_test_build_map_filepath( build_path, executable ),
      lib_args,
      lib_paths )
  end

  def run_fixture_now(executable, result, options)
    @generator.generate_test_results(
      options[:test_fixture], 
      options[:context],
      executable, 
      result)
  end
  
end
