require 'rake/testtask'

namespace :test do

  desc "Run unit tests"
  Rake::TestTask.new("units") { |t|
    t.libs << "test"
    t.pattern = 'test/unit/*_test.rb'
    t.verbose = true
  }

  desc "Run functional tests"
  Rake::TestTask.new("functional") { |t|
    t.libs << "test"
    t.pattern = 'test/functional/*_test.rb'
    t.verbose = true
  }

  desc "Run all the tests"
  task :all => [ 'test:units', 'test:functional' ]

end
