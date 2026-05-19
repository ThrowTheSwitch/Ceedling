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
require 'open3'

##
## Testing tasks
##

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

##
## Default & CI tasks
##

task :default => ['specs:all']
task :ci => ['specs:all']

##
## Documentation tasks
##

# Docs tasks Python virtual environment activate / deactivate wrapper
# This wrapper skips venv actions if no venv is in use (such as in CI)
def venv_sh(cmd)
  puts "Running: #{cmd}"
  script = <<~SHELL
    _activated=0
    if [ -z "$VIRTUAL_ENV" ] && [ -f ".docsenv/bin/activate" ]; then
      source .docsenv/bin/activate
      _activated=1
    fi
    #{cmd}
    if [ "$_activated" = "1" ]; then deactivate; fi
  SHELL
  sh('bash', '-c', script, verbose: false) do |ok, res|
    raise "ERROR: '#{cmd}' failed (exit #{res.exitstatus})" unless ok
  end
end

namespace :docs do
  desc "Install documentation tooling (mkdocs-material, mike) in a Python virtual environment"
  task :install do
    venv_dir = '.docsenv'

    if File.directory?(venv_dir)
      puts "Python virtual environment '#{venv_dir}/' already exists — skipping creation."
    else
      puts "Creating Python virtual environment '#{venv_dir}/'..."
      output, status = Open3.capture2e("python3 -m venv #{venv_dir}")
      unless status.success?
        $stderr.puts output
        raise "Failed to create Python virtual environment '#{venv_dir}/'"
      end
      puts "Python virtual environment '#{venv_dir}/' created."
    end

    puts "Installing documentation packages (mkdocs, mkdocs-material, mike)..."
    output, status = Open3.capture2e('bash', '-c', <<~SHELL)
      _activated=0
      if [ -z "$VIRTUAL_ENV" ]; then
        source #{venv_dir}/bin/activate
        _activated=1
      fi
      pip install 'mkdocs>=1.6' 'mkdocs-material>=9.5' 'mike>=2.0'
      if [ "$_activated" = "1" ]; then deactivate; fi
    SHELL
    unless status.success?
      $stderr.puts output
      raise "Failed to install documentation packages"
    end
    puts "Documentation packages installed."
  end

  desc "Snapshot versioned project files into docs/snapshot/ for documentation"
  task :snapshot do
    snapshot_dir = 'docs/mkdocs/snapshot/'
    # Ensure the snapshot directory is empty before writing new files (to clear out anything stale)
    FileUtils.rm_rf(snapshot_dir)
    ruby "lib/snapshot.rb", "docs/mkdocs/snapshot.yml", snapshot_dir
  end

  namespace :build do
    desc "Build documentation site for web deployment"
    task :web => [:snapshot] do
      venv_sh "mkdocs build --strict"
    end

    desc "Build documentation site as local HTML files bundle"
    task :local => [:snapshot] do
      venv_sh "mkdocs build -f mkdocs.local.yml --strict"
    end
  end

  desc "Serve web deploy docs site locally on port 8000"
  task :serve do
    venv_sh "mkdocs serve"
  end

  desc "Browse versioned docs site locally on port 8000"
  task :preview do
    venv_sh "mike serve"
  end

  desc "Deploy 'dev' version to branch and push to Github Pages"
  task :deploy do
    venv_sh "mike deploy --push dev"
  end
end
