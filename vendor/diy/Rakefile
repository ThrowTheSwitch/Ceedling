require 'rubygems'

task :default => [ :test ]

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = true
end


begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    $: << "lib"
    require 'diy.rb'
    gemspec.name = 'diy'
    gemspec.version = DIY::VERSION
    gemspec.summary = 'Constructor-based dependency injection container using YAML input.'
    gemspec.description = 'Constructor-based dependency injection container using YAML input.'
    gemspec.homepage = 'http://atomicobject.github.com/diy'
    gemspec.authors = 'Atomic Object'
    gemspec.email = 'github@atomicobject.com'
    gemspec.test_files = FileList['test/*_test.rb']
    gemspec.add_dependency 'constructor', '>= 1.0.0'
  end

  Jeweler::GemcutterTasks.new

rescue LoadError
  puts "(jeweler not installed)"
end
