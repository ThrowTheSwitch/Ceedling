require File.expand_path(File.dirname(__FILE__)) + '/config/test_environment'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rakefile_helper'

include RakefileHelpers



task :default => ['test:all']
task :cruise => [:default]


unit_test_pattern   = 'test/unit/*_test.rb'
system_test_pattern = 'test/system/*_test.rb'

ALL_UNIT_TESTS   = FileList[unit_test_pattern]
ALL_SYSTEM_TESTS = FileList[system_test_pattern]


namespace :test do
  desc "Run all unit and system tests"
  task :all => ['test:unit:all', 'test:system:all']

  Rake::TestTask.new('unit:all') do |t|
    t.pattern = unit_test_pattern
    t.verbose = true
  end

  namespace :unit do
    ALL_UNIT_TESTS.each do |test|
      base_file = File.basename(test).gsub(/_test\.rb/, '')
      desc base_file
      Rake::TestTask.new(base_file) do |t|
        t.test_files = [test]
      end
    end
  end

  Rake::TestTask.new('system:all') do |t|
    t.pattern = system_test_pattern
    t.verbose = true
  end

  namespace :system do
    ALL_SYSTEM_TESTS.each do |test|
      base_file = File.basename(test).gsub(/_test\.rb/, '')
      desc base_file
      Rake::TestTask.new(base_file) do |t|
        t.test_files = [test]
      end
    end
  end

end

