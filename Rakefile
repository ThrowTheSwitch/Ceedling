#!/usr/bin/env rake
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'bundler'
require 'rspec/core/rake_task'
require 'fileutils'

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

namespace :docs do
  desc "Install Python documentation tooling (mkdocs-material, mike)"
  task :install do
    sh "pip3 install --break-system-packages -r requirements-docs.txt"
  end

  desc "Snapshot versioned project files into docs/snapshot/ for documentation"
  task :snapshot do
    snapshot_dir = 'docs/snapshot/'
    # Ensure the snapshot directory is empty before writing new files (to clear out anything stale)
    FileUtils.rm_rf(snapshot_dir)
    ruby "lib/snapshot.rb", "docs/snapshot.yml", snapshot_dir
  end

  namespace :build do
    desc "Build deployable documentation site in strict mode — fails on broken links or warnings"
    task :deploy => [:snapshot] do
      sh "mkdocs build --strict"
    end

    desc "Build local documentation site in strict mode — fails on broken links or warnings"
    task :local => [:snapshot] do
      sh "mkdocs build -f mkdocs.local.yml --strict"
    end
  end

  desc "Serve documentation site locally on port 8000"
  task :serve do
    sh "mkdocs serve"
  end

  desc "Browse versioned documentation site locally on port 8000"
  task :preview do
    sh "mike serve"
  end

  desc "Deploy 'dev' version to local gh-pages branch (no remote push)"
  task :deploy do
    sh "mike deploy dev"
  end
end
