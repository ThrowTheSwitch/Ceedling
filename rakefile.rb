require File.expand_path(File.dirname(__FILE__)) + '/config/test_environment'
require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rakefile_helper'

TEST_FILE_SUFFIX  = '_test.rb'
TEST_FILE_PATTERN = "*#{TEST_FILE_SUFFIX}"

include RakefileHelpers



task :default => ['test:all']
task :cruise  => [:default]


unit_test_pattern           = "test/unit/#{TEST_FILE_PATTERN}"
integrations_test_pattern   = "test/integration/#{TEST_FILE_PATTERN}"
system_test_pattern         = "test/system/#{TEST_FILE_PATTERN}"

ALL_UNIT_TESTS          = FileList[unit_test_pattern]
ALL_INTEGRATION_TESTS   = FileList[integrations_test_pattern]
ALL_SYSTEM_TESTS        = FileList[system_test_pattern]


namespace :test do
  desc "Run all unit, integration, and system tests"
  task :all => ['test:unit:all']

  Rake::TestTask.new('unit:all') do |t|
    t.pattern = unit_test_pattern
    t.verbose = true
  end

  namespace :unit do
    create_test_tasks(ALL_UNIT_TESTS)
  end

  Rake::TestTask.new('integration:all') do |t|
    t.pattern = integrations_test_pattern
    t.verbose = true
  end

  namespace :integration do
    create_test_tasks(ALL_INTEGRATION_TESTS)
  end

  Rake::TestTask.new('system:all') do |t|
    t.pattern = system_test_pattern
    t.verbose = true
  end

  namespace :system do
    create_test_tasks(ALL_SYSTEM_TESTS)
  end

end

