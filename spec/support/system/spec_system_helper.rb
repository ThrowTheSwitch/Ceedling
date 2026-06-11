# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'fileutils'
require 'tmpdir'
require 'open3'
require 'ceedling/yaml_wrapper'
require 'spec_helper'
require 'deep_merge'

require_relative 'system_test_output'
require_relative 'gem_dir_layout'
require_relative 'system_context'
require_relative '../../system/support/common_test_cases'

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
    if @c.respond_to?(:console_summary) && !@c.console_summary.nil?
      $stderr.puts "-" * 72
      $stderr.puts @c.console_summary
    end
    $stderr.puts "=" * 72 + "\n"
  end
end

def test_asset_path(asset_file_name)
  File.join(File.dirname(__FILE__), '..', '..', '..', 'assets', asset_file_name)
end

def convert_slashes(path)
  if RUBY_PLATFORM.downcase.match(/mingw|win32/)
    path.gsub("/","\\")
  else
    path
  end
end
