require File.expand_path(File.dirname(__FILE__)) + "/../config/test_environment"
require 'test_helper'
require 'fileutils'


class Test::Unit::TestCase
  extend Behaviors
  
  def rake_execute(*args_and_tasks)
     return execute('rake', ["-f #{File.join(LIB_ROOT, 'rakefile.rb')}"] + args_and_tasks)
  end

  def rake_dry_run(*args_and_tasks)
     return rake_execute(['-n'] + args_and_tasks)
  end
  
  private
  
  def report(message)
    $stdout.flush
    puts message
    $stdout.flush
  end
  
  def report_err(message)
    $stderr.flush
    $stderr.puts(message)
    $stderr.flush
  end
  
  def execute(cmd, args=[], verbose=false)
    cmd_str = "#{cmd} #{args.join(' ')}"
    response = `#{cmd_str}`

    report(cmd_str) if verbose
    report(response) if verbose
    report('') if verbose

    if ($?.exitstatus != 0)
      report_err(response) if !verbose
      report_err('')
      raise "Command '#{cmd_str}' failed. (Returned #{$?.exitstatus})" 
    end
    return response
  end
end

