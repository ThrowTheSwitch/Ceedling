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

# Local developer gets hierarchical documentation output; CI gets compact progress output.
# Most CI systems (GitHub Actions, GitLab CI, CircleCI, etc.) set CI=true automatically.
RSPEC_FORMAT = ENV['CI_RSPEC_PROGRESS_FORMAT'] ? '--format progress' : '--format documentation'

desc "Run unit specs only"
RSpec::Core::RakeTask.new('specs:units') do |t|
  t.pattern    = 'spec/units/**/*_spec.rb'
  t.rspec_opts = RSPEC_FORMAT
end

desc "Run system specs only"
RSpec::Core::RakeTask.new('specs:system') do |t|
  t.pattern    = 'spec/system/**/*_spec.rb'
  t.rspec_opts = RSPEC_FORMAT
end

# Run unit tests first to fail on fast before running slower system tests
desc "Run all specs: units first then system (non-debug)"
task 'specs:all' => ['specs:units', 'specs:system']

# CI batch debug mode: run all system specs, keeping only failure artifacts.
# Passing project directories are deleted immediately; passing logs are never written.
desc "Run all system specs with artifact retention for failures only"
task 'specs:system:debug' do
  ENV['CEEDLING_SYSTEM_TEST_KEEP'] = 'failures'
  Rake::Task['specs:system'].invoke
end

# Formats three HTML reports -- units alone, system alone, and both combined --
# from the raw coverage data that CEEDLING_TEST_COVERAGE test runs accumulate
# (see .simplecov and spec/support/system/simplecov_boot.rb). Run after both
# `specs:units` and `specs:system`/`specs:system:debug` have completed with that
# env var set -- this task only reads back what they already wrote, it doesn't
# run any specs itself. Sources, one per report:
#   units    -- coverage/.resultset.json, written directly by the one unit-test
#               process (spec_helper.rb)
#   system   -- coverage/raw/system-<pid>-<timestamp>/.resultset.json, one small
#               file per system-test child process (simplecov_boot.rb). Each
#               process gets its own file rather than all sharing one growing
#               coverage/.resultset.json -- sharing one file means every single
#               process's exit re-reads, re-merges, and rewrites the *entire*
#               accumulated file so far, a cost that grows with every process
#               that ran before it and compounds across a full system-test run.
#               merge_results below reads each small file once, the same
#               approach SimpleCov itself recommends for "big CI setups" with
#               many result files.
#   combined -- the units file plus every system file
#
# `require 'simplecov'` here briefly starts SimpleCov for this task's own process
# too (via .simplecov's own autoload) -- overriding at_exit to a no-op keeps that
# process's own trivial self-coverage from being written anywhere at all, since
# this task reformats coverage_dir multiple times over its own run and has
# nothing of its own worth preserving.
desc "Merge and format units-only, system-only, and combined SimpleCov coverage reports"
task 'coverage:report' do
  require 'simplecov'
  SimpleCov.at_exit { }

  units_file  = File.join('coverage', '.resultset.json')
  system_files = Dir[File.join('coverage', 'raw', 'system-*', '.resultset.json')]

  raise "No coverage data found under coverage/ -- " \
        "run specs:units and specs:system with CEEDLING_TEST_COVERAGE set first" \
        if !File.exist?(units_file) && system_files.empty?

  reports = {
    'units'    => File.exist?(units_file) ? [units_file] : [],
    'system'   => system_files,
    'combined' => (File.exist?(units_file) ? [units_file] : []) + system_files
  }

  reports.each do |label, files|
    if files.empty?
      puts "Skipping #{label} report -- no matching coverage data (run with CEEDLING_TEST_COVERAGE=#{label == 'combined' ? 'units/system' : label} first)"
      next
    end

    # ignore_timeout: SimpleCov's default 10-minute merge_timeout exists to keep
    # live, in-process merges from combining coverage across unrelated runs -- it
    # doesn't apply here, where every file being merged is one CI step's already-
    # finished output, deliberately read back after the fact (the same reasoning
    # SimpleCov.collate's own API uses this same override for). Without it, a
    # system-test suite that legitimately runs longer than 10 minutes leaves the
    # early "units" file (and any early "system" files) older than the cutoff by
    # the time this task runs last, so they'd get silently dropped -- for units
    # alone (only ever one file) that's a full wipeout, nil coverage, and a crash
    # in HTMLFormatter#format on a nil result.
    result = SimpleCov::ResultMerger.merge_results(*files, ignore_timeout: true)

    SimpleCov.coverage_dir(File.join('coverage', label))
    SimpleCov::Formatter::HTMLFormatter.new.format(result)
    puts "#{label.capitalize} coverage: #{result.covered_percent.round(2)}% " \
         "(#{result.covered_lines}/#{result.total_lines} lines)"
  end
end

# Individual unit specs
Dir['spec/units/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  desc "Run unit spec: #{base}"
  RSpec::Core::RakeTask.new("spec:unit:#{base}") do |t|
    t.pattern    = p
    t.rspec_opts = '--format documentation'
  end
end

# Individual system specs
Dir['spec/system/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  desc "Run system spec: #{base}"
  RSpec::Core::RakeTask.new("spec:system:#{base}") do |t|
    t.pattern    = p
    t.rspec_opts = '--format documentation'
  end
end

# Individual system specs with full artifact retention (unadvertised).
# Developer debug mode: preserve all artifacts — both pass and fail project directories and logs
Dir['spec/system/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  task "spec:system:debug:#{base}" do
    ENV['CEEDLING_SYSTEM_TEST_KEEP'] = 'all'
    Rake::Task["spec:system:#{base}"].invoke
  end
end

desc "Run specs by filename matching a substring (e.g., rake \"spec:filter:filename[<substring>]\")"
RSpec::Core::RakeTask.new('spec:filter:filename', [:pattern]) do |t, args|
  pattern = args[:pattern] || '*'
  t.pattern    = "spec/{units,system}/**/*#{pattern}*_spec.rb"
  t.rspec_opts = '--format documentation'
end

desc "Run specs matching an example's description (e.g., rake \"spec:filter:example[Version reporting]\")"
RSpec::Core::RakeTask.new('spec:filter:example', [:description]) do |t, args|
  description = args[:description] || ''
  t.pattern    = 'spec/{units,system}/**/*_spec.rb'
  t.rspec_opts = "--format documentation --example '#{description}'"
end

desc "Run specs whose example's description matches a regex pattern (e.g., rake \"spec:filter:match[version|help]\")"
RSpec::Core::RakeTask.new('spec:filter:match', [:regex]) do |t, args|
  regex = args[:regex] || ''
  t.pattern    = 'spec/{units,system}/**/*_spec.rb'
  t.rspec_opts = "--format documentation --pattern '#{regex}'"
end

##
## Default & CI tasks
##

task :default => ['specs:all']
task :ci      => [:no_color, :default]

##
## Profiling tasks
##
## On-demand stackprof-based profiling of a real Ceedling build/test run,
## for ad hoc performance investigation. Runs against a scaffolded *copy* of
## an example project (via `ceedling example`), never in-place under
## examples/, so a profiling run touches nothing but tmp/profiling/ -- which
## is entirely git-ignored. See tools/profiling/profile_ceedling.rb for the
## harness this task shells out to.
##

require 'yaml'

PROFILE_TMP_DIR      = File.join(__dir__, 'tmp', 'profiling')
PROFILE_SCRIPT       = File.join(__dir__, 'tools', 'profiling', 'profile_ceedling.rb')
PROFILE_CEEDLING_BIN = File.join(__dir__, 'bin', 'ceedling')

desc "Ensure profiling gems (stackprof) are installed"
task 'profile:setup' do
  begin
    require 'stackprof'
  rescue LoadError
    puts "stackprof gem not available -- running 'bundle install'..."
    sh 'bundle install'
    raise "Gems installed. Please re-run the rake task."
  end
end

desc "Profile a build task against an example project, generating flame graph."
task 'profile:run', [:project, :build_task] => 'profile:setup' do |_t, args|
  # The scaffolded copy persists across successive runs for the same project (build/ and
  # its dependency cache included), so e.g. a 'test:all' run followed by a
  # 'test:all' run exercises a real delta/no-op rebuild, not two fresh full builds.
  # Delete tmp/profiling/<project>/ by hand to force a from-scratch scaffold again.
  # Usage: rake "profile:run[<example project>,<ceedling build task>]"
  # Example: rake "profile:run[temp_sensor,clobber test:all]"

  available_projects = Dir.children(File.join(__dir__, 'examples')).sort

  project = args[:project]
  if project.nil? || !available_projects.include?(project)
    raise "Unknown example project '#{project}' -- available: #{available_projects.join(', ')}"
  end

  build_task = args[:build_task] || raise("A ceedling build task is required, e.g. 'clobber test:all'")

  # Keyed on project alone (not timestamped) so this directory -- and the
  # scaffolded project's build/ and dependency cache within it -- persists
  # across successive profile:run calls for the same project.
  scaffold_dir = File.join(PROFILE_TMP_DIR, project)
  project_dir  = File.join(scaffold_dir, project)

  FileUtils.mkdir_p(scaffold_dir)

  # Scaffold via Ceedling's own `example` command rather than running
  # in-place under examples/ -- keeps profiling runs isolated from the
  # checked-in example (no build/ artifacts polluting examples/<project>/).
  # `ceedling example NAME DEST` places the scaffolded project at
  # DEST/NAME/..., not directly in DEST -- hence project_dir above.
  #
  # Only scaffold if not already present: re-running `ceedling example`
  # unconditionally would still be content-idempotent (delta builds are
  # hash-based, not mtime-based), but skipping it here is simpler to reason
  # about and is what actually lets build/ and the dependency cache persist
  # untouched across successive runs, which is the whole point.
  unless File.exist?(File.join(project_dir, 'project.yml'))
    sh "bundle exec ruby \"#{PROFILE_CEEDLING_BIN}\" example #{project} \"#{scaffold_dir}\""
    raise "Expected scaffolded project at #{project_dir}, not found" unless File.directory?(project_dir)
  end

  # Hardcoded to 1: this is what makes Batchinator's serial fallback (see
  # lib/ceedling/batchinator.rb) kick in, keeping the real work on the same
  # thread StackProf is sampling instead of an unsampled worker thread. This
  # task has no way to profile multi-threaded contention -- every flame
  # graph it produces is single-threaded by design.
  mixin_path = File.join(scaffold_dir, 'threads_mixin.yml')
  File.write(mixin_path, { :project => { :test_threads => 1, :compile_threads => 1 } }.to_yaml)

  # Timestamped, since project_dir/scaffold_dir are reused across runs --
  # this is the one thing that has to be unique per invocation so successive
  # reports (e.g. a full build, then a delta rebuild) don't overwrite each other.
  reports_dir = File.join(scaffold_dir, 'reports')
  FileUtils.mkdir_p(reports_dir)
  timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
  dump_path = File.join(reports_dir, "#{timestamp}.dump")
  text_path = File.join(reports_dir, "#{timestamp}.txt")
  html_path = File.join(reports_dir, "#{timestamp}.html")

  puts "Profiling 'ceedling #{build_task}' in #{project_dir}..."

  Dir.chdir(project_dir) do
    sh "bundle exec ruby \"#{PROFILE_SCRIPT}\" \"#{dump_path}\" \"#{PROFILE_CEEDLING_BIN}\" -- #{build_task} --mixin=\"#{mixin_path}\""
  end

  sh "bundle exec stackprof \"#{dump_path}\" --text > \"#{text_path}\""
  sh "bundle exec stackprof \"#{dump_path}\" --d3-flamegraph > \"#{html_path}\""

  puts "\nProfiling complete:"
  puts "  Project dir: #{project_dir}"
  puts "  Raw dump:    #{dump_path}"
  puts "  Text report: #{text_path}"
  puts "  Flame graph: #{html_path}"
end

##
## Documentation tasks
##

task :no_color do 
  #doesn't do anything at the moment. will remove color from output for CI
end

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

  namespace :deploy do
    desc "Deploy 'dev' version to Github Pages"
    task :dev => [:snapshot] do
      venv_sh "mike deploy --push dev"
    end

    desc "Deploy a release version to Github Pages (usage: rake docs:deploy:release[1.1.0])"
    task :release, [:version] => [:snapshot] do |t, args|
      version = args[:version] || raise("Version required: rake docs:deploy:release[#.#.#]")
      venv_sh "mike deploy --push #{version} latest"
    end
  end
end
