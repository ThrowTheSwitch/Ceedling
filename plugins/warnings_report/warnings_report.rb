require 'plugin'
require 'constants'

class WarningsReport < Plugin

  def setup
    @stderr_redirect = nil
    @log_paths = {}
  end

  def pre_compile_execute(arg_hash)
    @stderr_redirect = arg_hash[:tool][:stderr_redirect]
    arg_hash[:tool][:stderr_redirect] = StdErrRedirect::AUTO
  end
  
  def post_compile_execute(arg_hash)
    output = arg_hash[:shell_result][:output]
    arg_hash[:tool][:stderr_redirect] = @stderr_redirect
    
    write_warning_log( arg_hash[:context], output )
  end

  def pre_link_execute(arg_hash)
    @stderr_redirect = arg_hash[:tool][:stderr_redirect]
    arg_hash[:tool][:stderr_redirect] = StdErrRedirect::AUTO
  end
  
  def post_link_execute(arg_hash)
    output = arg_hash[:shell_result][:output]
    arg_hash[:tool][:stderr_redirect] = @stderr_redirect
    
    write_warning_log( arg_hash[:context], output )
  end

  private
  
  def write_warning_log(context, output)
    generate_log_path( context ) { |path| @ceedling[:file_wrapper].write( path, output + "\n" ) } if (output =~ /warning/i)
  end

  def generate_log_path(context)
    yield @log_paths[context] if (not @log_paths[context].nil?)
    
    base_path = File.join( PROJECT_BUILD_ARTIFACTS_ROOT, context.to_s )
    file_path = File.join( base_path, 'warnings.log' )
    
    if (@ceedling[:file_wrapper].exist?( base_path ))
      @log_paths[context] = file_path
      yield file_path
    end
  end

end