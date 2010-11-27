require 'rubygems'
require 'rake' # for ext()


class TestInvokerHelper

  constructor :configurator, :task_invoker, :dependinator, :test_includes_extractor, :file_finder, :file_path_utils, :streaminator, :file_wrapper

  def clean_results(results, options)
    @file_wrapper.rm_f( results[:fail] )
    @file_wrapper.rm_f( results[:pass] ) if (options[:force_run])
  end

  def process_auxiliary_dependencies(files)
    return if (not @configurator.project_use_auxiliary_dependencies)

    dependencies_list = @file_path_utils.form_test_dependencies_filelist( files )
    @task_invoker.invoke_test_dependencies_files( dependencies_list )
    @dependinator.load_test_object_deep_dependencies( dependencies_list )
  end
  
  def extract_sources(test)
    sources  = []
    includes = @test_includes_extractor.lookup_includes_list(test)
    
    includes.each { |include| sources << @file_finder.find_source_file(include, :ignore) }
    
    return sources.compact
  end
  
  def process_exception(exception)
    if (exception.message =~ /Don't know how to build task '(.+)'/i)
      @streaminator.stderr_puts("ERROR: Rake could not find file referenced in source or test: '#{$1}'.")
      @streaminator.stderr_puts("Possible stale dependency due to a file name change, etc. Execute 'clean' task and try again.") if (@configurator.project_use_auxiliary_dependencies)
      raise ''
    else
      raise exception
    end
  end
  
end
