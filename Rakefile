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
## Shared task helpers
##

# Several Gemfile entries are declared with `install_if:`. That predicate is
# Bundler's runtime activation check as well as its install-time one, so a gated
# gem is invisible to this process no matter what is installed. Bundler fixed this
# process's load path at boot, before this Rakefile assigned anything. Tasks that
# need a gated gem therefore run it in a child process through this helper.
#
# with_unbundled_env strips the parent's Bundler environment, including the
# RUBYOPT=-rbundler/setup that `bundle exec` exports. Without that strip, a nested
# bundler command boots bundler/setup first, validates the whole dependency set,
# and dies on the gated gems before doing any work. The variables are seeded
# *inside* the block because with_unbundled_env restores ENV from the snapshot
# Bundler captured at load time, which predates anything assigned here.
#
# The command is yielded untouched and the block's value is returned. One helper
# therefore serves both `sh` callers, which raise, and `system` callers, which want
# the boolean. Yielding the string unsplit is also what preserves shell
# redirections in a caller's command.
def unbundled_sh(env, cmd)
  Bundler.with_unbundled_env do
    env.each { |name, value| ENV[name] = value }
    yield cmd
  end
end

# Marker separating a development checkout from an installed gem. The release gem
# deliberately ships this Rakefile, the Gemfile, and spec/ so external tooling can
# self-test the packaged gem. It carries none of the repository's own development
# files. `.gitmodules` is the sturdiest marker available: ceedling.gemspec builds
# its file list with Dir['**/*'], which skips dotfiles, and the few dotfiles added
# back are named one by one.
REPO_MARKER = File.join(__dir__, '.gitmodules')

# Tasks that cannot work outside the repository say so plainly rather than failing
# later on a missing file. __dir__ rather than Dir.pwd, since profile:run calls
# this from inside a Dir.chdir block.
def repo_only!(task)
  return if File.exist?( REPO_MARKER )

  raise "'#{task}' only runs from a Ceedling repository checkout.\n" \
        "The released gem ships this Rakefile but none of the development files " \
        "this task needs.\n" \
        "Tasks that do work from an installed gem: specs:units, specs:integration, " \
        "specs:system, and coverage:report."
end

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

# Integration specs sit between units and system: they compose real lib/ceedling
# objects and shell out to real tools (gcc), but exercise a single subsystem end
# to end rather than driving a whole `ceedling` build the way system specs do.
desc "Run integration specs only"
RSpec::Core::RakeTask.new('specs:integration') do |t|
  t.pattern    = 'spec/integration/**/*_spec.rb'
  t.rspec_opts = RSPEC_FORMAT
end

desc "Run system specs only"
RSpec::Core::RakeTask.new('specs:system') do |t|
  t.pattern    = 'spec/system/**/*_spec.rb'
  t.rspec_opts = RSPEC_FORMAT
end

# Ordered fastest to slowest so a failure surfaces as early as possible.
desc "Run all specs: units, then integration, then system (non-debug)"
task 'specs:all' => ['specs:units', 'specs:integration', 'specs:system']

# CI batch debug mode: run all system specs, keeping only failure artifacts.
# Passing project directories are deleted immediately; passing logs are never written.
desc "Run all system specs with artifact retention for failures only"
task 'specs:system:debug' do
  ENV['CEEDLING_SYSTEM_TEST_KEEP'] = 'failures'
  Rake::Task['specs:system'].invoke
end

# Dynamic analysis of the C Ceedling itself generates -- test runners, mocks,
# Partials -- plus the example projects. Each task selects a sanitizer flavor,
# which is a file in spec/support/system/sanitizers/; the harness turns that into
# a Ceedling mixin and the sanitizer's runtime options (see SystemContext).
#
# Set the variable and invoke the existing task, exactly as specs:system:debug
# above does, so a developer here and CI run identical wiring rather than two
# arrangements that can drift. CI instruments one matrix leg only (Linux, Ruby
# 3.5): instrumentation roughly doubles build time, and a sanitizer finding in
# generated code appears on every leg equally, so paying for it more than once
# buys nothing.
#
# Fixtures that fault on purpose are excluded by name -- see
# spec/support/system/sanitizers/asan_ubsan.yml.
#
# This flavor leaves leak detection off; specs:system:sanitize:leaks below is what
# CI runs. Reach for this one to tell a leak from a memory error or UB.
desc "Run all system specs with ASan+UBSan, leak detection off (triage)"
task 'specs:system:sanitize' do
  ENV['CEEDLING_TEST_SANITIZERS'] = 'asan_ubsan'
  Rake::Task['specs:system:debug'].invoke
end

# What CI runs. Leak detection was measured clean across the whole suite before
# being enabled -- see spec/support/system/sanitizers/asan_ubsan_leaks.yml.
desc "Run all system specs with ASan+UBSan and leak detection (what CI runs)"
task 'specs:system:sanitize:leaks' do
  ENV['CEEDLING_TEST_SANITIZERS'] = 'asan_ubsan_leaks'
  Rake::Task['specs:system:debug'].invoke
end

# Formats four HTML reports -- units alone, integration alone, system alone, and all
# combined -- from the raw coverage data that CEEDLING_TEST_COVERAGE test runs
# accumulate (see .simplecov and spec/support/system/simplecov_boot.rb). Run after
# `specs:units`, `specs:integration`, and `specs:system`/`specs:system:debug` have
# completed with that env var set -- this task only reads back what they already
# wrote, it doesn't run any specs itself. Sources, one per report:
#   units       -- coverage/.resultset.json, written directly by the one unit-test
#                  process (spec_helper.rb)
#   integration -- coverage/raw/integration/.resultset.json, written directly by the
#                  one integration-test process (spec_helper.rb, its own coverage_dir)
#   system      -- coverage/raw/system-<pid>-<timestamp>/.resultset.json, one small
#                  file per system-test child process (simplecov_boot.rb). Each
#                  process gets its own file rather than all sharing one growing
#                  coverage/.resultset.json -- sharing one file means every single
#                  process's exit re-reads, re-merges, and rewrites the *entire*
#                  accumulated file so far, a cost that grows with every process
#                  that ran before it and compounds across a full system-test run.
#                  merge_results below reads each small file once, the same
#                  approach SimpleCov itself recommends for "big CI setups" with
#                  many result files.
#   combined    -- the units file plus the integration file plus every system file
#
# `require 'simplecov'` here briefly starts SimpleCov for this task's own process
# too (via .simplecov's own autoload) -- overriding at_exit to a no-op keeps that
# process's own trivial self-coverage from being written anywhere at all, since
# this task reformats coverage_dir multiple times over its own run and has
# nothing of its own worth preserving.
desc "Merge and format units-only, integration-only, system-only, and combined SimpleCov coverage reports"
task 'coverage:report' do
  require 'simplecov'
  SimpleCov.at_exit { }

  units_file        = File.join('coverage', '.resultset.json')
  integration_files = Dir[File.join('coverage', 'raw', 'integration', '.resultset.json')]
  system_files      = Dir[File.join('coverage', 'raw', 'system-*', '.resultset.json')]

  raise "No coverage data found under coverage/ -- " \
        "run specs:units, specs:integration, and specs:system with CEEDLING_TEST_COVERAGE set first" \
        if !File.exist?(units_file) && integration_files.empty? && system_files.empty?

  units_files = File.exist?(units_file) ? [units_file] : []

  reports = {
    'units'       => units_files,
    'integration' => integration_files,
    'system'      => system_files,
    'combined'    => units_files + integration_files + system_files
  }

  reports.each do |label, files|
    if files.empty?
      want = label == 'combined' ? 'units/integration/system' : label
      puts "Skipping #{label} report -- no matching coverage data (run with CEEDLING_TEST_COVERAGE=#{want} first)"
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
    # silent: true suppresses SimpleCov's own "Coverage report generated for
    # <command_name> to ..." status line. For the merged system/combined reports
    # that command_name is every system-<pid>-<timestamp> name joined with ", " --
    # hundreds of them, burying this task's own one-line summary below. The
    # concise line this task prints next says everything that noise did.
    SimpleCov::Formatter::HTMLFormatter.new(silent: true).format(result)
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

# Individual integration specs
Dir['spec/integration/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  desc "Run integration spec: #{base}"
  RSpec::Core::RakeTask.new("spec:integration:#{base}") do |t|
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

# Individual system specs with full artifact retention. Developer debug mode:
# preserve all artifacts, both pass and fail project directories and logs.
#
# Deliberately undescribed one by one. There are forty of them, and advertising
# each would bury every other task in `rake -T`. The wildcard task below carries
# one description for the whole family.
Dir['spec/system/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  task "spec:system:debug:#{base}" do
    ENV['CEEDLING_SYSTEM_TEST_KEEP'] = 'all'
    Rake::Task["spec:system:#{base}"].invoke
  end
end

# Stand-in that documents the family above. It is a signpost in `rake -T` rather
# than something to run, so the description says what to put in place of the
# wildcard. The same technique carries the `test:*` and `gen:mocks:*` placeholders
# in lib/ceedling/rakefiles/.
desc "Run a system spec, retaining all artifacts (replace [*] with spec name)."
task 'spec:system:debug:*' do
  message = "Oops! 'spec:system:debug:*' isn't a real task. " \
            "Use a real system spec name in place of the wildcard.\n" \
            "Example: `rake spec:system:debug:cli_surface`\n" \
            "Run `rake -AT spec:system:debug` to list every available name.\n" \
            "Artifact locations are printed when the suite starts."

  $stderr.puts message
end

# Individual system specs under ASan+UBSan. Triage, not routine: when CI's
# instrumented leg reports a finding, chasing it in the one spec that produced it
# beats re-running the whole suite at roughly double build time.
#
# Undescribed one by one for the same reason as the debug family above -- the
# wildcard task below documents the whole family.
# Matches the flavor CI runs, so a finding reproduces here rather than changing
# shape. Switch to specs:system:sanitize above to ask whether it was a leak.
Dir['spec/system/**/*_spec.rb'].each do |p|
  base = File.basename(p,'.*').gsub('_spec','')
  task "spec:system:sanitize:#{base}" do
    ENV['CEEDLING_TEST_SANITIZERS'] = 'asan_ubsan_leaks'
    ENV['CEEDLING_SYSTEM_TEST_KEEP'] = 'all'
    Rake::Task["spec:system:#{base}"].invoke
  end
end

desc "Run a system spec with ASan+UBSan instrumentation (replace [*] with spec name)."
task 'spec:system:sanitize:*' do
  message = "Oops! 'spec:system:sanitize:*' isn't a real task. " \
            "Use a real system spec name in place of the wildcard.\n" \
            "Example: `rake spec:system:sanitize:cli_surface`\n" \
            "Run `rake -AT spec:system:sanitize` to list every available name.\n" \
            "Requires a real GCC with ASan+UBSan support -- on macOS, run inside " \
            "throwtheswitch/madsciencelab-plugins."

  $stderr.puts message
end

desc "Run specs by filename matching a substring (e.g., rake \"spec:filter:filename[<substring>]\")"
RSpec::Core::RakeTask.new('spec:filter:filename', [:pattern]) do |t, args|
  pattern = args[:pattern] || '*'
  t.pattern    = "spec/{units,integration,system}/**/*#{pattern}*_spec.rb"
  t.rspec_opts = '--format documentation'
end

desc "Run specs matching an example's description (e.g., rake \"spec:filter:example[Version reporting]\")"
RSpec::Core::RakeTask.new('spec:filter:example', [:description]) do |t, args|
  description = args[:description] || ''
  t.pattern    = 'spec/{units,integration,system}/**/*_spec.rb'
  t.rspec_opts = "--format documentation --example '#{description}'"
end

desc "Run specs whose example's description matches a regex pattern (e.g., rake \"spec:filter:match[version|help]\")"
RSpec::Core::RakeTask.new('spec:filter:match', [:regex]) do |t, args|
  regex = args[:regex] || ''
  t.pattern    = 'spec/{units,integration,system}/**/*_spec.rb'
  t.rspec_opts = "--format documentation --pattern '#{regex}'"
end

##
## Default & CI tasks
##

task :default => ['specs:all']
task :ci      => [:no_color, :default]

##
## Gem tasks
##
## Build the release gem the same way CI does, for inspecting what actually gets
## packaged. ceedling.gemspec assembles its file list by sweeping the working tree
## with Dir['**/*'], so a local build reflects whatever is lying around -- which is
## most of the reason to run one by hand.
##

desc "Remove built Ceedling gems from the repository root"
task 'gem:clean' do
  repo_only!( 'gem:clean' )

  gems = Dir[ File.join( __dir__, 'ceedling-*.gem' ) ]

  if gems.empty?
    puts "No built gems to remove."
    next
  end

  # Named as they go, since a developer may have kept one deliberately for
  # comparison against a new build.
  gems.each do |path|
    puts "Removing #{File.basename( path )}"
    FileUtils.rm_f( path )
  end
end

desc "Build the Ceedling gem into the repository root"
task 'gem:build' => 'gem:clean' do
  repo_only!( 'gem:build' )

  # The gemspec's file sweep has no *.gem exclusion, so a gem left from an earlier
  # build would be packaged inside the next one. The gem:clean dependency is what
  # prevents that.
  #
  # Invoked exactly as CI invokes it, with no --output, so the artifact lands in
  # the repository root where CI's own `ceedling-*.gem` upload glob expects it.
  sh 'gem build ceedling.gemspec'

  $LOAD_PATH.unshift( File.join( __dir__, 'lib' ) )
  require 'version'
  expected = "ceedling-#{Ceedling::Version::GEM}.gem"

  # Asserted rather than pinned with --output. A mismatch means lib/version.rb and
  # the built gem disagree, which pinning the name would hide.
  unless File.exist?( File.join( __dir__, expected ) )
    raise "Expected #{expected}, which `gem build` did not produce. " \
          "Check lib/version.rb against the built gem's name."
  end

  # site-local/ holds the offline documentation bundle and reaches the gem only
  # through the gemspec's file sweep. CI downloads it before building. A local gem
  # without it is still valid and still worth building, so this informs rather
  # than fails.
  unless File.directory?( File.join( __dir__, 'site-local' ) )
    puts "\nNOTE: site-local/ is absent, so this gem carries no offline " \
         "documentation bundle."
    puts "Run `rake docs:build:local` first to match what CI packages."
  end

  puts "\nBuilt #{expected}"
end

##
## SBOM tasks
##
## Software Bill of Materials describing the Ceedling gem as installed: what ships
## inside it, plus the transitive closure of its declared runtime dependencies.
## CycloneDX and SPDX are rendered from one component model, so the two cannot
## disagree about facts. Every component is identified by a PURL, and the vendored
## C components by the commit they are pinned at -- the only identity that separates
## the two Unity source trees a Ceedling gem carries, both of which report header
## version 2.7.2.
##
## Generation lives in tools/, which the gemspec excludes from the gem, so none of
## this reaches an installed Ceedling. Specs live beside it for the same reason:
## spec/ ships for certification self-tests and would otherwise carry specs for
## code the gem does not contain.
##
## The documents describe the gem as distributed. They do not describe the C code
## Ceedling builds, nor the external tools an enabled plugin needs.

desc "Generate CycloneDX and SPDX SBOMs into the repository root"
task 'sbom:build' do
  repo_only!( 'sbom:build' )

  require_relative 'tools/sbom/generator'

  written = Sbom::Generator.new( __dir__ ).build

  puts "\nGenerated:"
  written.each { |path| puts "  #{File.basename( path )}" }
end

desc "Run the SBOM generator's own specs"
task 'sbom:specs' do
  repo_only!( 'sbom:specs' )

  # Not folded into specs:units or specs:integration. Those suites ship in the gem
  # and run against an installed Ceedling, where tools/ does not exist.
  sh 'bundle exec rspec tools/sbom/spec --format documentation'
end

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

# Gate for stackprof, which is install_if:-gated in the Gemfile so an ordinary
# `bundle install` never attempts its native extension. See unbundled_sh for why
# the gate only ever reaches a child process.
#
# BUNDLE_GEMFILE is pinned because profile:run runs one command from inside the
# scaffolded project directory. Stripping the parent's Bundler environment also
# strips the absolute BUNDLE_GEMFILE that `bundle exec` exported, which would
# otherwise leave Bundler searching upward from a directory that is not the
# repository root.
PROFILE_ENV = {
  'CEEDLING_PROFILING' => 'true',
  'BUNDLE_GEMFILE'     => File.join(__dir__, 'Gemfile'),
}.freeze

def profile_sh(cmd, &block)
  unbundled_sh( PROFILE_ENV, cmd, &block )
end

# True when stackprof can actually be loaded under the gate. Probed in a child
# process because a `require` here could never succeed, whatever is installed.
def stackprof_available?
  profile_sh( %q{bundle exec ruby -e "require 'stackprof'"} ) do |cmd|
    system( cmd, out: File::NULL, err: File::NULL )
  end
end

desc "Ensure profiling gems (stackprof) are installed"
task 'profile:setup' do
  repo_only!( 'profile:setup' )

  # stackprof's native extension fails to build on Windows (Gem::Ext::BuildError),
  # and whether it can ever build there is untested. Declining early beats burying
  # the developer in a failed compile. See the Gemfile's stackprof entry.
  if Gem.win_platform?
    raise "Profiling is not available on Windows -- stackprof's native extension " \
          "does not build there. See the stackprof entry in the Gemfile."
  end

  puts "Probing for stackprof..."

  if stackprof_available?
    puts "stackprof is available."
    next
  end

  puts "stackprof not found -- installing now via 'bundle install'..."

  begin
    profile_sh( 'bundle install' ) { |cmd| sh cmd }
  rescue StandardError
    raise "stackprof installation failed -- a native-extension build " \
          "toolchain (e.g. the 'ruby-dev'/'ruby-devel' package on Linux) " \
          "may be missing. See the error above for details."
  end

  # Re-probed rather than assumed, so a gem that installs but will not load is
  # diagnosed here instead of surfacing as a LoadError from a grandchild process
  # in the middle of a profiled build.
  unless stackprof_available?
    raise "stackprof installed but still will not load. Profiling cannot continue."
  end

  puts "stackprof installed."
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
    profile_sh( "bundle exec ruby \"#{PROFILE_CEEDLING_BIN}\" example #{project} \"#{scaffold_dir}\"" ) { |cmd| sh cmd }
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
    profile_sh( "bundle exec ruby \"#{PROFILE_SCRIPT}\" \"#{dump_path}\" \"#{PROFILE_CEEDLING_BIN}\" -- #{build_task} --mixin=\"#{mixin_path}\"" ) { |cmd| sh cmd }
  end

  # Both commands redirect, so each must reach `sh` as one string for a shell to
  # interpret. profile_sh yields the command unsplit.
  profile_sh( "bundle exec stackprof \"#{dump_path}\" --text > \"#{text_path}\"" ) { |cmd| sh cmd }
  profile_sh( "bundle exec stackprof \"#{dump_path}\" --d3-flamegraph > \"#{html_path}\"" ) { |cmd| sh cmd }

  puts "\nProfiling complete:"
  puts "  Project dir: #{project_dir}"
  puts "  Raw dump:    #{dump_path}"
  puts "  Text report: #{text_path}"
  puts "  Flame graph: #{html_path}"
end

##
## Linting tasks
##
## RuboCop over Ceedling's own Ruby, limited to the Lint, Metrics, Security, and
## Performance departments (see .rubocop.yml for why only those four). The gems
## are install_if:-gated in the Gemfile, so `lint:setup` exists to install them on
## demand and every other task here depends on it.
##
## `.rubocop_todo.yml` records the pre-existing offense backlog, so `lint` passing
## means "no NEW offenses" rather than "no offenses." Regenerate it with
## `lint:todo` only when deliberately re-baselining -- it is meant to shrink.
##

# Local developer gets RuboCop's default output; CI gets GitHub workflow annotations
# so findings land inline on the pull request diff.
LINT_FORMAT = ENV['CI_LINT_GITHUB_FORMAT'] ? '--format github' : ''

# Gate for the RuboCop gems. See unbundled_sh for why every lint task runs RuboCop
# in a child process rather than loading it here.
LINT_ENV = { 'CEEDLING_LINT' => 'true' }.freeze

def lint_sh(cmd, &block)
  unbundled_sh( LINT_ENV, cmd, &block )
end

# Shared runner so every lint task reports failure the same way. RuboCop exits
# non-zero when it finds offenses, which is the intended local signal, so the message
# says so rather than implying the tool broke.
def rubocop_sh(args)
  cmd = "bundle exec rubocop #{LINT_FORMAT} #{args}".squeeze(' ').strip
  puts "Running: #{cmd}"
  lint_sh(cmd) do |c|
    sh(c, verbose: false) do |ok, res|
      next if ok
      raise "RuboCop reported offenses or failed to run (exit #{res.exitstatus})"
    end
  end
end

desc "Ensure linting gems (rubocop, rubocop-performance) are installed"
task 'lint:setup' do
  # .rubocop.yml and .rubocop_todo.yml are not packaged, so linting an installed
  # gem would silently run against RuboCop's defaults instead. Every other lint
  # task depends on this one and inherits the check.
  repo_only!( 'lint:setup' )

  puts "Probing for rubocop..."

  available = lint_sh('bundle exec rubocop --version') do |c|
    system(c, out: File::NULL, err: File::NULL)
  end

  if available
    puts "rubocop is available."
  else
    puts "rubocop not found -- installing now via 'bundle install'..."
    lint_sh('bundle install') { |c| sh c }
    puts "rubocop installed."
  end
end

desc "Lint Ceedling's Ruby source"
task 'lint' => 'lint:setup' do
  rubocop_sh ''
end

desc "Lint only changed files, against a branch (e.g., rake \"lint:changed[master]\")"
task 'lint:changed', [:branch] => 'lint:setup' do |_t, args|
  # next_version is the integration branch, so it is the comparison a contributor
  # wants nearly always. Naming another branch or any revision overrides it.
  branch = args[:branch] || 'next_version'

  # Checked up front because an unresolvable revision makes `git diff` fail while
  # the backticks below swallow the error, leaving an empty file list that reports
  # as "nothing to lint." A typo would otherwise look like a clean branch.
  unless system( 'git', 'rev-parse', '--verify', '--quiet', branch, out: File::NULL )
    raise "Cannot compare against '#{branch}' -- no such branch or revision"
  end

  # Diff filter drops deletions; a removed file cannot be linted. Restricted to
  # Ruby-ish paths so a run is not wasted on changed Markdown or YAML.
  changed  = `git diff --name-only --diff-filter=d #{branch}...HEAD`.split("\n")
  changed += `git diff --name-only --diff-filter=d`.split("\n")
  changed  = changed.uniq.grep(/\.(rb|rake|gemspec)$|^Rakefile$|^bin\//)

  if changed.empty?
    puts "No changed Ruby files to lint against '#{branch}'."
    next
  end

  puts "Linting #{changed.length} file(s) changed against '#{branch}'..."
  # --force-exclusion so a named file that .rubocop.yml excludes stays excluded.
  rubocop_sh "--force-exclusion #{changed.join(' ')}"
end

desc "Apply RuboCop's safe auto-corrections"
task 'lint:fix' => 'lint:setup' do
  # Safe corrections only (-a, not -A). Review the diff before keeping it. Metrics
  # offenses are never autocorrectable, so what this changes is mostly Performance
  # and a handful of Lint cops.
  rubocop_sh '--autocorrect'
end

desc "Regenerate .rubocop_todo.yml, the pre-existing offense backlog"
task 'lint:todo' => 'lint:setup' do
  # --no-exclude-limit keeps per-file Exclude lists complete instead of collapsing a
  # cop to a blanket override once it passes RuboCop's default threshold. Without it
  # the backlog hides which files are involved, and that list is the only thing that
  # makes the backlog actionable.
  rubocop_sh '--auto-gen-config --no-exclude-limit'
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
    repo_only!( 'docs:install' )

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
    # docs/mkdocs/ is not packaged. Every docs build and deploy task depends on
    # this one, so the whole namespace inherits the check from here.
    repo_only!( 'docs:snapshot' )

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

    desc "Build the prerelease documentation site for local validation"
    task :prerelease => [:snapshot] do
      venv_sh "mkdocs build -f mkdocs.prerelease.yml --strict"
    end
  end

  desc "Serve web deploy docs site locally on port 8000"
  task :serve do
    venv_sh "mkdocs serve"
  end

  namespace :serve do
    desc "Serve the prerelease documentation site locally on port 8000"
    task :prerelease do
      venv_sh "mkdocs serve -f mkdocs.prerelease.yml"
    end
  end

  desc "Browse versioned docs site locally on port 8000"
  task :preview do
    venv_sh "mike serve"
  end

  namespace :deploy do
    desc "Deploy prerelease docs to Github Pages"
    task :prerelease, [:version] => [:snapshot] do |t, args|
      version = args[:version] || raise("Version required: rake docs:deploy:prerelease[#.#.#]")
      venv_sh "mike deploy --push --config-file mkdocs.prerelease.yml #{version}"
    end

    desc "Deploy release docs to Github Pages without changing 'latest'"
    task :release, [:version] => [:snapshot] do |t, args|
      version = args[:version] || raise("Version required: rake docs:deploy:release[#.#.#]")
      venv_sh "mike deploy --push #{version}"
    end

    namespace :release do
      desc "Deploy release docs to Github Pages without and set it as 'latest'"
      task :latest, [:version] => [:snapshot] do |t, args|
        version = args[:version] || raise("Version required: rake docs:deploy:release:latest[#.#.#]")
        venv_sh "mike deploy --push #{version} latest"
      end
    end
  end
end
