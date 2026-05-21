# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'tmpdir'
require 'open3'
require 'ceedling/yaml_wrapper'
require 'spec_helper'
require 'deep_merge'

module CeedlingSystemSpecHelpers
  SYSTEM_TESTS_LABEL = "Ceedling System Tests"

  # Helper method to convert method name to readable description
  def test_case(method_name)
    description = method_name.to_s.gsub('_', ' ').capitalize
    it(description) { send(method_name) }
  end
end

# Top-level DSL wrapper — replaces `describe "Ceedling System Tests" do` in each spec file.
# Must be a top-level def (not inside a module) because config.extend only injects methods
# into the RSpec example group DSL (inside describe blocks), not into main:Object where
# the outermost describe call in each spec file is made.
def ceedling_system_tests(&block)
  describe(CeedlingSystemSpecHelpers::SYSTEM_TESTS_LABEL, &block)
end

# Extend RSpec's DSL to include our helper above, and add system-test failure diagnostics
RSpec.configure do |config|
  config.extend CeedlingSystemSpecHelpers

  # Exclude any line that does NOT contain "system" and ends with .rb from backtraces
  # This helps reduce RSpec backtrace noise that is irrelevant to system test failures
  config.backtrace_formatter.exclusion_patterns = [
    /\A(?!.*system.*\.rb)/
  ]

  # Rebuild the full description from the group hierarchy using " :: " as separator.
  # example.full_description concatenates with spaces, which is unreadable at 3-4 levels deep.
  format_description = lambda do |example|
    groups = example.example_group.parent_groups.reverse.drop(1)
    parts  = groups.map(&:description).reject(&:empty?)
    parts << example.description               unless example.description.empty?
    parts.join(' :: ')
  end

  config.after(:each) do |example|
    next unless example.exception
    next unless defined?(@c) && @c.respond_to?(:raw_output) && !@c.raw_output.nil?

    test_name =
      example.full_description
             # Remove "ceedling" and "system test(s)" from the test name as redundant in the log filename
             .gsub(/^ceedling/i, '')
             .gsub(/system tests?/i, '')
             .gsub(/systests?/i, '')
             # Replace non-filesystem-safe chars with underscores
             .gsub(/[^a-zA-Z0-9_-]/, '_')
             # Collapse runs of underscores into a single underscore
             .squeeze('_')
             # Strip leading/trailing underscores
             .gsub(/\A_+|_+\z/, '')
             # Truncate long names by keeping the last 120 chars (preserves the specific end of the name).
             # String#slice(negative, length) returns nil when the string is shorter than the offset;
             # use a conditional instead.
             # After slicing, strip any partial leading word 
             # (e.g. "s_" from "Project's" -> "Project_s_" when the cut lands mid-segment).
             .then { |s| s.length > 120 ? s[-120..].sub(/\A[^_]*_+/, '') : s }
    timestamp = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
    log_path  = File.join(Dir.pwd, "systest.#{test_name}.#{timestamp}.fail.log")

    log_content = ""
    log_content << "Command: `#{@c.last_cmd}`\n\n" if @c.respond_to?(:last_cmd) && !@c.last_cmd.nil?
    log_content << @c.raw_output.to_s
    File.write(log_path, log_content)

    $stderr.puts "\n" + ("=" * 72)
    $stderr.puts "FAILED: #{format_description.call(example)}"
    $stderr.puts "Temp dir: #{@c.dir}"
    $stderr.puts "Log file: #{log_path}"
    $stderr.puts "-" * 72
    $stderr.puts @c.console_summary if @c.respond_to?(:console_summary) && !@c.console_summary.nil?
    $stderr.puts "=" * 72 + "\n"
  end
end

def test_asset_path(asset_file_name)
  File.join(File.dirname(__FILE__), '..', 'assets', asset_file_name)
end

def convert_slashes(path)
  if RUBY_PLATFORM.downcase.match(/mingw|win32/)
    path.gsub("/","\\")
  else
    path
  end
end

# Wraps Ceedling command output to suppress it in RSpec assertion failure messages.
# RSpec formats the "actual" value via #inspect; this class returns a short sentinel
# string so failures show only the expected pattern/substring, not thousands of lines.
# All RSpec string matchers (match, include) continue to work unchanged at every call site.
class SystemTestOutput
  def initialize(output)
    @output = output
  end

  def match(pattern) = @output.match(pattern)
  def include?(str)  = @output.include?(str)
  def to_s           = @output
  def to_str         = @output
  def inspect        = '(Ceedling build output — see log file)'
end

class GemDirLayout
  attr_reader :gem_dir_base_name

  def initialize(install_dir)
    @gem_dir_base_name = "gems"
    @d = File.join install_dir, @gem_dir_base_name
    FileUtils.mkdir_p @d
  end

  def install_dir; convert_slashes(@d)  end
  def bin;         File.join(@d, 'bin') end
  def lib;         File.join(@d, 'lib') end
end

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
    git_repo = File.expand_path( File.join( File.dirname( __FILE__ ), '..') )
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

module CeedlingSystemTestCases
  def can_report_version_no_git_commit_sha
    @c.with_context do
      # Version without Git commit short SHA file in project
      output = @c.ceedling_appcmd_exec("version")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Ceedling => \d\.\d\.\d\n/)
    end
  end

  def can_report_version_with_git_commit_sha
    # Version with Git commit short SHA file in root of project
    # Creating the commit file before building + installing the gem simulates the CI process
    File.open('GIT_COMMIT_SHA', 'w') do |f|
      f << '---{-@'
    end

    @c.with_context do
      output = @c.ceedling_appcmd_exec("version")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Ceedling => \d\.\d\.\d----{-@\n/)
    end
  end

  def can_create_projects
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        expect(File.exist?("test/support")).to eq true
      end
    end
  end

  def has_git_support
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?(".gitignore")).to eq true
        expect(File.exist?("test/support/.gitkeep")).to eq true
      end
    end
  end

  def can_upgrade_projects
    @c.with_context do
      output = @c.ceedling_appcmd_exec("upgrade #{@proj_name}")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Upgraded/i)
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
        all_docs = Dir["vendor/ceedling/docs/*.pdf"].length + Dir["vendor/ceedling/docs/*.md"].length
      end
    end
  end

  def can_upgrade_projects_even_if_test_support_folder_does_not_exist
    @c.with_context do
      output = @c.ceedling_appcmd_exec("upgrade #{@proj_name}")
      FileUtils.rm_rf("#{@proj_name}/test/support")

      updated_prj_yml = []
      File.read("#{@proj_name}/project.yml").split("\n").each do |line|
        updated_prj_yml.append(line) unless line =~ /support/
      end
      File.write("#{@proj_name}/project.yml", updated_prj_yml.join("\n"), mode: 'w')

      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/Upgraded/i)
      Dir.chdir @proj_name do
        expect(File.exist?("project.yml")).to eq true
        expect(File.exist?("src")).to eq true
        expect(File.exist?("test")).to eq true
      end
    end
  end

  def cannot_upgrade_non_existing_project
    @c.with_context do
      output = @c.ceedling_appcmd_exec("upgrade #{@proj_name}")
      expect(@c.last_exit_status).to eq(1)
      expect(output).to match(/Could not find an existing project/i)
    end
  end

  def contains_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling")).to eq true
      end
    end
  end

  def does_not_contain_a_vendor_directory
    @c.with_context do
      Dir.chdir @proj_name do
        expect(File.exist?("vendor/ceedling")).to eq false
      end
    end
  end

  def contains_documentation
    @c.with_context do
      Dir.chdir @proj_name do
        all_docs = Dir["docs/*"]
        expect(all_docs).to contain_exactly('docs/ceedling', 'docs/unity', 'docs/cmock', 'docs/c_exception', 'docs/license.txt')
      end
    end
  end

  def does_not_contain_documentation
    @c.with_context do
      Dir.chdir @proj_name do
        expect(Dir.exist?("docs/")).to eq false
      end
    end
  end

  def can_test_projects_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_test_alias
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_default
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_named_verbosity
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("--verbosity=obnoxious")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(output).to match(/:post_test_fixture_execute/)
      end
    end
  end

  def can_test_projects_with_numerical_verbosity
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("-v=4")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)

        expect(output).to match(/:post_test_fixture_execute/)
      end
    end
  end

  def can_test_projects_with_unity_exec_time
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_EXEC_TIME" ] } }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_test_and_vendor_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_unity_printf.c"), 'test/'
        settings = { :unity => { :defines => [ "UNITY_INCLUDE_PRINT_FORMATTED" ] },
                     :defines => { :test => { :example_file_unity_printf => [ "TEST" ] } }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_test_name_replaced_defines_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.copy_entry test_asset_path("tests_with_defines/src/"), 'src/'
        FileUtils.cp_r test_asset_path("tests_with_defines/test/."), 'test/'
        settings = { :defines => { :test => { '*' => [ "TEST", "STANDARD_CONFIG" ],
                                   'test_adc_hardware_special.c' => [ "TEST", "SPECIFIC_CONFIG" ],
                                 } }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either passes or is ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # Ceedling :use_test_preprocessor is disabled
  def can_test_projects_unity_parameterized_test_cases_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_test_preprocessor => :none },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  # NOTE: This is not supported in this release, therefore is not getting called.
  def can_test_projects_unity_parameterized_test_cases_with_preprocessor_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("test_example_with_parameterized_tests.c"), 'test/'
        settings = { :project => { :use_test_preprocessor => :all },
                     :unity => { :use_param_tests => true }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_test_files_symbols_undefined
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareA.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorA.h"), 'src/'
        # Rely on undefined symbols in our C files
        # 2 enabled intentionally failing test cases (no mocks generated)
        settings = { :project => { :use_test_preprocessor => :tests },
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareA")
        expect(@c.last_exit_status).to eq(1) # Intentional test failure in successful build
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+2/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_test_files_symbols_defined
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareA.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareA.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorA.h"), 'src/'
        # 1 enabled passing test case with 1 mock used
        settings = { :project => { :use_test_preprocessor => :tests },
                     :defines => { :test => ['PREPROCESSING_TESTS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareA")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_mocks_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareB.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorB.h"), 'src/'
        # 1 test case with 1 mocked function
        settings = { :project => { :use_test_preprocessor => :mocks },
                     :defines => { :test => ['PREPROCESSING_MOCKS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareB")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_preprocessing_for_mocks_intentional_build_failure
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareB.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareB.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorB.h"), 'src/'
        # 1 test case with a missing mocked function
        settings = { :project => { :use_test_preprocessor => :mocks }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareB")
        expect(@c.last_exit_status).to eq(1) # Failing build because of missing mock
        expect(output).to match(/(undeclared|undefined|implicit).+Adc_Reset/)
      end
    end
  end

  def can_test_projects_with_preprocessing_all
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("tests_with_preprocessing/test/test_adc_hardwareC.c"), 'test/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareC.c"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardwareC.h"), 'src/'
        FileUtils.cp test_asset_path("tests_with_preprocessing/src/adc_hardware_configuratorC.h"), 'src/'
        # 1 test case using 1 mock
        settings = { :project => { :use_test_preprocessor => :all },
                     :defines => { :test => ['PREPROCESSING_TESTS', 'PREPROCESSING_MOCKS'] }
                   }
        @c.merge_project_yml_for_test(settings)

        output = @c.ceedling_build_exec("test:adc_hardwareC")
        expect(@c.last_exit_status).to eq(0) # Successful build and tests
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
      end
    end
  end

  def can_test_projects_with_fail
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_fail_alias
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = @c.ceedling_build_exec("test")
        expect(@c.last_exit_status).to eq(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_fail_default
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(1) # Since a test fails, we return error here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_compile_error
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_boom.c"), 'test/'

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Since a test explodes, we return error here
        expect(output).to match(/(?:ERROR: Ceedling Failed)|(?:Ceedling could not complete operations because of errors)/)
      end
    end
  end

  def can_test_projects_with_both_mock_and_real_header
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("example_file_call.h"), 'src/'
        FileUtils.cp test_asset_path("example_file_call.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_with_mock.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either passed or was ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def uses_report_tests_raw_output_log_plugin
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_verbose.c"), 'test/'

        @c.uncomment_project_yml_option_for_test('- report_tests_raw_output_log')

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
        expect(File.exist?("build/artifacts/test/test_example_file_verbose.raw.log")).to eq true
      end
    end
  end


  def can_fetch_non_project_help
    @c.with_context do
      # notice we don't change directory into the project
      output = @c.ceedling_appcmd_exec("help")
      expect(@c.last_exit_status).to eq(0)
      expect(output).to match(/ceedling example/i)
      expect(output).to match(/ceedling new/i)
      expect(output).to match(/ceedling upgrade/i)
      expect(output).to match(/ceedling version/i)
    end
  end

  def can_fetch_project_help
    @c.with_context do
      Dir.chdir @proj_name do
        output = @c.ceedling_appcmd_exec("help")
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/ceedling clean/i)
        expect(output).to match(/ceedling clobber/i)
        expect(output).to match(/ceedling module:create/i)
        expect(output).to match(/ceedling module:destroy/i)
        expect(output).to match(/ceedling summary/i)
        expect(output).to match(/ceedling test:\*/i)
        expect(output).to match(/ceedling test:all/i)
        expect(output).to match(/ceedling version/i)
      end
    end
  end

  def can_run_single_test_with_full_test_case_name_from_test_file_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=test_add_numbers_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_run_single_test_with_partial_test_case_name_from_test_file_with_success
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_passed_does_not_fit_defined_in_test_file
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=zumzum")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/No tests executed./)
      end
    end
  end

  def none_of_test_is_executed_if_test_case_name_and_exclude_test_case_name_is_the_same
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=_adds_numbers --exclude_test_case=_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/No tests executed./)
      end
    end
  end

  def exclude_test_case_name_filter_works_and_only_one_test_case_is_executed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:all --exclude_test_case=test_add_numbers_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+0/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+1/)
      end
    end
  end

  def run_one_testcase_from_one_test_file_when_test_case_name_is_passed
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_success.c"), 'test/'

        output = @c.ceedling_build_exec("test:test_example_file_success --test_case=_adds_numbers")

        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+1/)
        expect(output).to match(/FAILED:\s+0/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end


  def test_run_of_projects_fail_because_of_crash_without_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(!File.exist?('./build/test/results/test_add.fail'))
      end
    end
  end

  def test_run_of_projects_fail_because_of_crash_with_report
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :none }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Executable Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
      end
    end
  end

  def execute_all_test_cases_from_crashing_test_runner_and_return_test_report_with_failue
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+2/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_test_case_argument_with_enabled_debug
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all --test_case=test_add_numbers_will_fail")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def execute_and_collect_debug_logs_from_crashing_test_case_defined_by_exclude_test_case_argument_with_enabled_debug
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_crash.c"), 'test/'

        @c.merge_project_yml_for_test({:project => { :use_backtrace => :gdb }})

        output = @c.ceedling_build_exec("test:all --exclude_test_case=add_numbers_adds_numbers")
        expect(@c.last_exit_status).to eq(1) # Test should fail because of crash
        expect(output).to match(/Test Case Crashed/i)
        expect(output).to match(/Unit test failures./)
        expect(File.exist?('./build/test/results/test_example_file_crash.fail'))
        output_rd = File.read('./build/test/results/test_example_file_crash.fail')
        expect(output_rd =~ /test_add_numbers_will_fail \(\) at test\/test_example_file_crash.c\:14/ )
        expect(output).to match(/TESTED:\s+1/)
        expect(output).to match(/PASSED:\s+(?:0|1)/)
        expect(output).to match(/FAILED:\s+(?:1|2)/)
        expect(output).to match(/IGNORED:\s+0/)
      end
    end
  end

  def can_test_projects_with_test_file_directly_including_source_file
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file_with_statics.c"), 'src/'
        FileUtils.cp test_asset_path("test_example_file_source_include.c"), 'test/'

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0)
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end

  def can_test_projects_with_success_when_space_appears_between_hash_and_include
    # test case cover issue described in https://github.com/ThrowTheSwitch/Ceedling/issues/588
    @c.with_context do
      Dir.chdir @proj_name do
        FileUtils.cp test_asset_path("example_file.h"), 'src/'
        FileUtils.cp test_asset_path("example_file.c"), 'src/'
        FileUtils.cp test_asset_path('test_example_file_success.c'), 'test/'

        add_line = false
        updated_test_file = []
        File.read(File.join('test','test_example_file_success.c')).split("\n").each do |line|
          if line =~ /#include "unity.h"/
            add_line = true
            updated_test_file.append(line)
          else
            if add_line
              updated_test_file.append('# include "unity.h"')
              add_line = false
            end
            updated_test_file.append(line)
          end
        end

        File.write(File.join('test','test_example_file_success.c'), updated_test_file.join("\n"), mode: 'w')

        output = @c.ceedling_build_exec
        expect(@c.last_exit_status).to eq(0) # Since a test either pass or are ignored, we return success here
        expect(output).to match(/TESTED:\s+\d/)
        expect(output).to match(/PASSED:\s+\d/)
        expect(output).to match(/FAILED:\s+\d/)
        expect(output).to match(/IGNORED:\s+\d/)
      end
    end
  end
end
