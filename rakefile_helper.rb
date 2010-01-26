require 'yaml'
require 'fileutils'

module RakefileHelpers
  
  def report(message)
    puts message
    $stdout.flush
    $stderr.flush
  end

  def create_test_tasks(test_list)
    test_list.each do |test|
      base_file = File.basename(test).gsub(/#{Regexp.escape(TEST_FILE_SUFFIX)}/, '')
      desc base_file
      Rake::TestTask.new(base_file) do |t|
        t.test_files = [test]
      end
    end
  end
  
end

