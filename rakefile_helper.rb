require 'yaml'
require 'fileutils'

module RakefileHelpers
  
  def report(message)
    puts message
    $stdout.flush
    $stderr.flush
  end
  
end

