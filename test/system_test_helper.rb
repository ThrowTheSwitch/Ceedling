require File.expand_path(File.dirname(__FILE__)) + "/../config/test_environment"
require 'test_helper'
require 'fileutils'
require 'yaml'


class Test::Unit::TestCase
  extend Behaviors
  
  def ceedling_execute(*args_and_tasks)
    return execute('rake', ["-f #{File.join(LIB_ROOT, 'rakefile.rb')}"] + args_and_tasks)
  end

  # do not raise if rake execution of ceedling bombs & do not display any output
  def ceedling_execute_no_boom(*args_and_tasks)
    return execute('rake', ["-f #{File.join(LIB_ROOT, 'rakefile.rb')}"] + args_and_tasks, false, false, false)
  end

  # execute rake in dry run mode -- checking dependencies and invoke states but not actually taking action
  def ceedling_execute_dry_run(*args_and_tasks)
    return ceedling_execute(['-n'] + args_and_tasks)
  end
  
  def fetch_test_results(results_path, test_name)
    filepath = ''
    
    pass_path = File.join(results_path, "#{test_name}.pass")
    fail_path = File.join(results_path, "#{test_name}.fail")

    if (File.exists?(pass_path))
      filepath = pass_path
    elsif (File.exists?(fail_path))
      filepath = fail_path
    else
      raise "Could not find test results for '#{test_name}' in #{results_path}"
    end
    
    return YAML.load(File.read(filepath))
  end
  
  private
  
  def report(message)
    puts message
    $stdout.flush
  end
  
  def report_err(message)
    $stderr.puts(message)
    $stderr.flush
  end
  
  def execute(cmd, args=[], verbose_cmd=false, verbose_error=true, should_raise=true)
    cmd_str = "#{cmd} #{args.join(' ')}"
    
    # execute command and redirect stderr to stdout;
    # the redirect grabs all response output centrally & 
    #  lets us gobble up errors if we need to parse them for test execution
    response = `#{cmd_str} 2>&1`

    report(cmd_str) if verbose_cmd
    report(response) if verbose_cmd
    report('') if verbose_cmd

    if ($?.exitstatus != 0)
      report_err(response) if verbose_error
      report_err('') if verbose_error
      raise "Command '#{cmd_str}' failed. (Returned #{$?.exitstatus})" if should_raise
    end
    return response
  end
end

