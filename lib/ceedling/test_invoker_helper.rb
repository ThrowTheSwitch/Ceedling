
require 'ceedling/par_map'

class TestInvokerHelper

  constructor :configurator, :task_invoker, :test_includes_extractor, :file_finder, :file_path_utils, :file_wrapper, :generator, :rake_wrapper

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
    sources  = []
    includes = @test_includes_extractor.lookup_includes_list(test)
    
    includes.each { |include| sources << @file_finder.find_compilation_input_file(include, :ignore) }
    
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

  def generate_objects_now(object_list, options)
    par_map(PROJECT_COMPILE_THREADS, object_list) do |object|
      if (@rake_wrapper[object].needed?)
        src = @file_finder.find_compilation_input_file(object)
        if (File.basename(src) =~ /#{EXTENSION_SOURCE}$/)
          @generator.generate_object_file(
            options[:test_compiler],
            OPERATION_COMPILE_SYM,
            options[:symbol],
            src,
            object,
            @file_path_utils.form_test_build_list_filepath( object ),
            @file_path_utils.form_test_dependencies_filepath( object ))
        elsif (defined?(TEST_BUILD_USE_ASSEMBLY) && TEST_BUILD_USE_ASSEMBLY)
          @generator.generate_object_file(
            options[:test_assembler],
            OPERATION_ASSEMBLE_SYM,
            options[:symbol],
            src,
            object )
        end
      end
    end
  end

  def generate_executables_now(executables, details, lib_args, lib_paths, options)
    par_map(PROJECT_COMPILE_THREADS, executables) do |executable|
      @generator.generate_executable_file(
        options[:test_linker],
        options[:symbol],
        details[executable][:objects].map{|v| "\"#{v}\""},
        @file_path_utils.form_test_executable_filepath( executable ),
        @file_path_utils.form_test_build_map_filepath( executable ),
        lib_args,
        lib_paths )
    end
  end

  def run_fixture_now(result, options)
    @generator.generate_test_results(
      options[:test_fixture], 
      options[:symbol], 
      @file_path_utils.form_test_executable_filepath(result), 
      result)
  end
  
end
