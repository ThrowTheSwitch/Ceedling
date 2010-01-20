require 'rubygems'

desc 'Default: run specs'
task :default => :spec

require 'spec/rake/spectask'
desc 'Run constructor specs'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList['specs/*_spec.rb']
  t.spec_opts << '-c -f s'
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    $: << "lib"
    require 'constructor.rb'
    gemspec.name = 'constructor'
    gemspec.version = CONSTRUCTOR_VERSION
    gemspec.summary = 'Declarative named-argument object initialization.'
    gemspec.description = 'Declarative means to define object properties by passing a hash to the constructor, which will set the corresponding ivars.'
    gemspec.homepage = 'http://atomicobject.github.com/constructor'
    gemspec.authors = 'Atomic Object'
    gemspec.email = 'github@atomicobject.com'
    gemspec.test_files = FileList['specs/*_spec.rb']
  end

  Jeweler::GemcutterTasks.new

rescue LoadError
  puts "(jeweler not installed)"
end

