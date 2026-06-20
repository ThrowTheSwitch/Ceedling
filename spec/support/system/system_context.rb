# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require_relative 'gem_dir_layout'

class SystemContext
  class VerificationFailed < RuntimeError; end
  class InvalidBackupEnv < RuntimeError; end

  attr_reader :dir, :gem, :console_summary, :raw_output, :last_exit_status, :last_cmd

  SYSTEM_TEST_KEEP_ENV = 'CEEDLING_SYSTEM_TEST_KEEP'

  # Shared gem installation — built once by setup_shared_gem!, reused by every deploy_gem call.
  # Eliminates redundant `bundle install` runs (one per describe group → one per suite).
  @@shared_gem_dir = nil
  @@shared_gem     = nil

  def self.setup_shared_gem!
    return if @@shared_gem_dir

    shared_dir = Dir.mktmpdir('ceedling_test_gem_')
    shared_gem = GemDirLayout.new(shared_dir)

    git_repo = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
    File.write(
      File.join(shared_dir, 'Gemfile'),
      [
        %Q{source "http://rubygems.org/"},
        %Q{gem "rake"},
        %Q{gem "constructor"},
        %Q{gem "diy"},
        %Q{gem "thor"},
        %Q{gem "deep_merge"},
        %Q{gem "unicode-display_width"},
        %Q{gem "ceedling", :path => '#{git_repo}'}
      ].join("\n")
    )

    Dir.chdir(shared_dir) do
      saved = ENV.to_hash
      begin
        %w{BUNDLE_GEMFILE BUNDLE_BIN_PATH RUBYOPT}.each { |k| ENV.delete(k) }
        deploy_output  = `bundle config set --local path '#{shared_gem.install_dir}' 2>&1`
        deploy_output += `bundle install 2>&1`
        raise VerificationFailed, "bundle install failed:\n#{deploy_output}" unless $?.success?

        verify = `bundle exec ruby -S ceedling version 2>&1`
        unless $?.success?
          raise VerificationFailed,
            "Ceedling does not appear to be installed or ready for use.\n" \
            "Output:\n#{verify}"
        end
      rescue
        FileUtils.rm_rf(shared_dir)
        raise
      ensure
        ENV.replace(saved)
      end
    end

    @@shared_gem_dir = shared_dir
    @@shared_gem     = shared_gem
  end

  def self.cleanup_shared_gem!
    FileUtils.rm_rf(@@shared_gem_dir) if @@shared_gem_dir
    @@shared_gem_dir = nil
    @@shared_gem     = nil
  end

  def initialize
    if ENV[SYSTEM_TEST_KEEP_ENV]
      # In either debug mode ('failures' or 'all'), root the temp dir inside systests/proj/
      # so that done! can rename it to pass/ or fail/ on the same filesystem without a
      # cross-device copy. The specific subdir (pass/ or fail/) is determined by done!.
      base = File.join(Dir.pwd, 'systests', 'proj')
      FileUtils.mkdir_p(base)
      @dir = Dir.mktmpdir(nil, base)
    else
      @dir = Dir.mktmpdir
    end
    @gem = GemDirLayout.new(@dir)
  end

  def done!
    if keep_all? || (keep_failures_only? && @failed)
      # 'all' mode: preserve pass and fail artifacts for post-run inspection.
      # 'failures' mode: preserve only failing artifacts; passing dirs are discarded
      # immediately to avoid accumulating thousands of files during a full CI run
      # (each --local project copies the entire Ceedling source tree).
      subdir = @failed ? 'fail' : 'pass'
      dest   = File.join(File.dirname(@dir), subdir, File.basename(@dir))
      FileUtils.mkdir_p(File.dirname(dest))
      FileUtils.mv(@dir, dest)
      $stderr.puts "Test artifacts saved: #{dest}"
    else
      FileUtils.rm_rf(@dir)
    end
  end

  # Called by the RSpec after(:each) hook on failure so done! routes this context to fail/.
  def mark_failed!
    @failed = true
  end

  def deploy_gem
    raise VerificationFailed,
      "Shared gem not initialized — ensure SystemContext.setup_shared_gem! " \
      "is called before running system specs (see spec_system_helper.rb before(:suite))" \
      unless @@shared_gem
    @gem = @@shared_gem
  end

  # Does a few things:
  #   - Configures the environment.
  #   - Runs the command from the temporary context directory.
  #   - Restores everything to where it was when finished.
  def context_exec(cmd, *args)
    with_context do
      `#{args.unshift(cmd).join(" ")}`
    end
  end

  def with_context
    Dir.chdir @dir do |current_dir|
      with_constrained_env do
        # Point bundle exec to the shared Gemfile so it works from any project directory.
        # constrain_env removes BUNDLE_GEMFILE; we re-set it here within the constrained scope.
        ENV['BUNDLE_GEMFILE'] = File.join(@@shared_gem_dir, 'Gemfile') if @@shared_gem_dir
        ENV['RUBYLIB'] = @gem.lib
        ENV['RUBYPATH'] = @gem.bin

        ENV['LANG'] = 'en_US.UTF-8'
        ENV['LANGUAGE'] = 'en_US.UTF-8'
        ENV['LC_ALL'] = 'en_US.UTF-8'

        yield
      end
    end
  end

  ############################################################
  # Functions for manipulating environment settings during tests:
  def backup_env
    @_env = ENV.to_hash
  end

  def reduce_env(destroy_keys=[])
    ENV.keys.each {|k| ENV.delete(k) if destroy_keys.include?(k) }
  end

  def constrain_env
    destroy_keys = %w{BUNDLE_GEMFILE BUNDLE_BIN_PATH RUBYOPT}
    reduce_env(destroy_keys)
  end

  def restore_env
    if @_env
      # delete environment variables we've added since we started
      ENV.to_hash.each_pair {|k,v| ENV.delete(k) unless @_env.include?(k) }

      # restore environment variables we've modified since we started
      @_env.each_pair {|k,v| ENV[k] = v}
    else
      raise InvalidBackupEnv.new
    end
  end

  def with_constrained_env
    begin
      backup_env
      constrain_env
      yield
    ensure
      restore_env
    end
  end

  ############################################################
  # Functions for manipulating project.yml files during tests:
  def merge_project_yml_for_test(settings, show_final=false)
    yaml_wrapper = YamlWrapper.new
    project_hash = yaml_wrapper.load('project.yml')
    project_hash.deep_merge!(settings)
    puts "\n\n#{project_hash.to_yaml}\n\n" if show_final
    yaml_wrapper.dump('project.yml', project_hash)
  end

  def append_project_yml_for_test(new_args)
    fake_prj_yml= "#{File.read('project.yml')}\n#{new_args}"
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  def uncomment_project_yml_option_for_test(option)
    fake_prj_yml= File.read('project.yml').gsub(/\##{option}/,option)
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  def comment_project_yml_option_for_test(option)
    fake_prj_yml= File.read('project.yml').gsub(/#{option}/,"##{option}")
    File.write('project.yml', fake_prj_yml, mode: 'w')
  end

  ############################################################
  # Ceedling command execution with structured failure reporting:

  # For build/test (Rake tasks): Routes through the Ceedling CLI application command `build`
  # This is the only command that accepts --verbosity.
  def ceedling_build_exec(*args)
    cmd = "bundle exec ruby -S ceedling build --verbosity=debug #{args.join(' ')}".strip
    stdout, stderr, status = Open3.capture3(cmd)

    @last_cmd         = cmd
    @last_exit_status = status.exitstatus
    @raw_output       = stdout + stderr
    @console_summary  = compose_failure_report(stdout, stderr)

    SystemTestOutput.new(@raw_output)
  end

  # All other Ceedling CLI application commands other than `build`
  # (new, upgrade, version, help, examples, example, etc.)
  def ceedling_appcmd_exec(*args)
    cmd = "bundle exec ruby -S ceedling #{args.join(' ')}".strip
    stdout, stderr, status = Open3.capture3(cmd)

    @last_cmd         = cmd
    @last_exit_status = status.exitstatus
    @raw_output       = stdout + stderr
    @console_summary  = compose_failure_report(stdout, stderr)

    SystemTestOutput.new(@raw_output)
  end

  private

  # True when running the full suite in CI batch debug mode: keep only failing artifacts.
  # Set by `specs:system:debug` rake task via CEEDLING_SYSTEM_TEST_KEEP='failures'.
  def keep_failures_only?
    ENV[SYSTEM_TEST_KEEP_ENV] == 'failures'
  end

  # True when running an individual spec in developer debug mode: keep all artifacts.
  # Set by `spec:system:debug:<name>` rake tasks via CEEDLING_SYSTEM_TEST_KEEP='all'.
  # Also used by the CI locale test job (spec:system:debug:preprocessing_locale).
  def keep_all?
    ENV[SYSTEM_TEST_KEEP_ENV] == 'all'
  end

  def compose_failure_report(stdout, stderr)
    sections = []

    error_lines     = stdout.lines.select { |l| l.include?('ERROR') }
    exception_lines = stdout.lines.select { |l| l.include?('EXCEPTION') }

    unless error_lines.empty? && exception_lines.empty?
      sections << ">> ERRORS & EXCEPTIONS"
      sections.concat(error_lines)
      sections.concat(exception_lines)
    end

    unless stderr.strip.empty?
      sections << ">> STDERR"
      sections << stderr.strip
    end

    label = 'FAILED TEST SUMMARY'
    failed_block = extract_section(stdout, label)
    unless failed_block.empty?
      sections << ">> #{label}"
      sections.concat(failed_block)
    end

    label = 'OVERALL TEST SUMMARY'
    overall_block = extract_section(stdout, label)
    unless overall_block.empty?
      sections << ">> #{label}"
      sections.concat(overall_block)
    end

    sections.join("\n")
  end

  def extract_section(output, banner)
    lines = output.lines
    idx   = lines.index { |l| l.include?(banner) }
    return [] unless idx

    # Skip the banner line and any following pure-separator lines
    start = idx + 1
    start += 1 while start < lines.length && lines[start].strip.match?(/\A[-=]+\z/)

    # Collect contiguous non-blank lines
    lines[start..].take_while { |l| !l.strip.empty? }
  end
  ############################################################
end
