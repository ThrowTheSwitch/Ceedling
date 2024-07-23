#!/usr/bin/env rake
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

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
