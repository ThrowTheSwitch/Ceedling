#!/usr/bin/env rake
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'bundler'
require 'rspec/core/rake_task'

desc "Run all specs"
RSpec::Core::RakeTask.new('specs:all') do |t|
  t.pattern = 'spec/**/*_spec.rb'
  # Dots
  t.rspec_opts = '--format progress'
end

Dir['spec/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  desc "rspec #{base}"
  RSpec::Core::RakeTask.new("spec:file:#{base}") do |t|
    t.pattern = p
    # Hierarchical listing of tests with names and contexts
    t.rspec_opts = '--format documentation'
  end
end

desc "Run specs by filename matching a substring (e.g., rake \"spec:filter:filename[<substring>]\")"
RSpec::Core::RakeTask.new('spec:filter:filename', [:pattern]) do |t, args|
  pattern = args[:pattern] || '*'
  t.pattern = "spec/**/*#{pattern}*_spec.rb"
    # Hierarchical listing of tests with names and contexts
  t.rspec_opts = '--format documentation'
end

desc "Run specs matching an example's description (e.g., rake \"spec:filter:example[Version Reporting]\")"
RSpec::Core::RakeTask.new('spec:filter:example', [:description]) do |t, args|
  description = args[:description] || ''
  t.pattern = 'spec/**/*_spec.rb'
  # Hierarchical listing of tests with names and contexts
  t.rspec_opts = "--format documentation --example '#{description}'"
end

desc "Run specs whose example's description matches a regex pattern (e.g., rake \"spec:filter:match[version|help]\")"
RSpec::Core::RakeTask.new('spec:filter:match', [:regex]) do |t, args|
  regex = args[:regex] || ''
  t.pattern = 'spec/**/*_spec.rb'
  # Hierarchical listing of tests with names and contexts
  t.rspec_opts = "--format documentation --pattern '#{regex}'"
end

task :default => ['specs:all']
task :ci => ['specs:all']
