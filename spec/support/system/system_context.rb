# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require_relative 'gem_dir_layout'

class SystemContext
  class VerificationFailed < RuntimeError; end
  class InvalidBackupEnv < RuntimeError; end

  attr_reader :dir, :gem, :console_summary, :raw_output, :last_exit_status, :last_cmd

  def initialize
    @dir = Dir.mktmpdir
    @gem = GemDirLayout.new(@dir)
  end

  SYSTEM_TEST_KEEP_ENV = 'CEEDLING_SYSTEM_TEST_KEEP'

  def done!
    if ENV[SYSTEM_TEST_KEEP_ENV]
      $stderr.puts "Keeping test artifacts at: #{@dir} (#{SYSTEM_TEST_KEEP_ENV} is set)"
    else
      FileUtils.rm_rf(@dir)
    end
  end

  def deploy_gem
    git_repo = File.expand_path( File.join( File.dirname( __FILE__ ), '..', '..', '..') )
    bundler_gem_file_data = [
      %Q{source "http://rubygems.org/"},
      %Q{gem "rake"},
      %Q{gem "constructor"},
      %Q{gem "diy"},
      %Q{gem "thor"},
      %Q{gem "deep_merge"},
      %Q{gem "unicode-display_width"},
      %Q{gem "ceedling", :path => '#{git_repo}'}
    ].join("\n")

    File.open(File.join(@dir, "Gemfile"), "w+") do |f|
      f.write(bundler_gem_file_data)
    end

    Dir.chdir @dir do
      with_constrained_env do
        deploy_output  = `bundle config set --local path '#{@gem.install_dir}' 2>&1`
        deploy_output += `bundle install 2>&1`
        raise VerificationFailed, "bundle install failed:\n#{deploy_output}" unless $?.success?

        checks = ["bundle exec ruby -S ceedling version 2>&1"]
        checks.each do |c|
          result = `#{c}`
          unless $?.success?
            raise VerificationFailed,
              "Ceedling does not appear to be installed or ready for use.\n" \
              "Command: `#{c}`\n" \
              "Output:\n#{result}"
          end
        end
      end
    end

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
