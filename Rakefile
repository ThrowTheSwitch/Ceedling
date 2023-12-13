#!/usr/bin/env rake
require 'bundler'
require 'rspec/core/rake_task'

desc "Run all rspecs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end

Dir['spec/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  desc "rspec #{base}"
  RSpec::Core::RakeTask.new("spec:#{base}") do |t|
    t.pattern = p
  end
end

task :default => [:spec]
task :ci => [:spec]
