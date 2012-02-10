#!/usr/bin/env rake
require 'bundler'

task :ci => [:spec]

require 'rspec/core/rake_task'
desc "Run all rspecs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end
