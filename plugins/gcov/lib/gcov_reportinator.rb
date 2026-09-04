# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'
require 'gcov_types'

# Abstract base class that formalises the gcov reportinator interface.
#
# Subclasses must:
#   - Define a NAME string constant and implement name() to return it.
#   - Set @artifacts_path in initialize (nil for console-only reportinators)
#     and expose it via attr_reader.
#   - Set @configurator in initialize to access build_exclusion_data().
#   - Set @loginator in initialize to access print_shell_exec_time().
#   - Set @tool_executor in initialize to use ToolVersionGating's detect_tool_version().
#   - Initialize @summary = '' and set it during generate_reports() when the
#     tool produces a coverage summary (e.g. gcovr --print-summary output).
#     Gcov#generate_coverage_reports reads summary() and is the sole logging site.
#   - Implement generate_reports(opts) as a void orchestrator.
#
class GcovReportinator

  include ToolVersionGating

  def initialize(config)
    @config = config
  end

  def name
    raise NotImplementedError.new("#{self.class} must implement name()")
  end

  def artifacts_path
    raise NotImplementedError.new("#{self.class} must implement artifacts_path()")
  end

  def generate_reports(opts)
    raise NotImplementedError.new("#{self.class} must implement generate_reports()")
  end

  def summary
    @summary || ''
  end

  protected

  # Log the shell result timing
  def print_shell_exec_time(shell_result)
    return if shell_result.nil?

    @loginator.log( "Done in #{Reportinator.generate_duration_string( shell_result[:time] )}.", Verbosity::NORMAL )
  end


  # Returns raw exclusion data used by subclasses to build tool-specific filter arguments.
  # GcovrReportinator formats these as Python regex patterns (--exclude).
  # ReportGeneratorReportinator formats them as glob wildcards (-filefilters:).
  def build_exclusion_data
    {
      test_paths:    @configurator.collection_paths_test,
      support_paths: @configurator.collection_paths_support,
      test_prefix:   @configurator.project_test_file_prefix,
      mock_prefix:   @configurator.cmock_mock_prefix,
      build_root:    @configurator.project_build_root,
      src_extension: @configurator.extension_source
    }
  end


  # Shared "escape hatch" handling for arbitrary user-supplied CLI arguments, applied
  # even when a config/report file is otherwise in full control -- both GcovrReportinator's
  # :custom_args and ReportGeneratorReportinator's :custom_args use this identical pattern.
  def build_custom_args(custom_args)
    return "" if custom_args.nil?

    custom_args.each_with_object(String.new) do |custom_arg, args|
      args << "\"#{custom_arg}\" " unless custom_arg.nil? || custom_arg.empty?
    end
  end


  # Generic CLI-argument builder driven by a declarative table, so each reportinator's
  # own option-to-flag mapping reads as plain data rather than repeated ad hoc string
  # concatenation. table: { option_symbol => spec }, where spec is:
  #   :flag        - the CLI flag text, or a Proc(version) -> String for a flag whose
  #                   name itself depends on the tool version (e.g. a deprecated/renamed flag).
  #   :type        - :boolean (flag alone), :value (flag + one quoted value by default),
  #                   :inline_value (flag and value quoted together as a single CLI token,
  #                   ReportGenerator's `-key:value` style, vs. gcovr's `--flag "value"`),
  #                   :list (flag repeated once per array entry), :integer (flag + value,
  #                   only if the configured value is an Integer), or :integer_percent
  #                   (as :integer, plus a 1-100 range check raising CeedlingException).
  #   :quote       - set false to emit a :value/:list entry's value unquoted.
  #   :min_version - [major, minor]; entry is silently omitted below this version
  #                   (distinct from VERSION_GATES-style checks, which raise instead).
  def build_args_from_table(opts, table, version: nil, component_prefix: '')
    table.each_with_object(String.new) do |(option, spec), args|
      value = opts[option]
      next if value.nil? || value == false
      next if spec[:min_version] && !min_version?(version, *spec[:min_version])

      flag = spec[:flag].respond_to?(:call) ? spec[:flag].call(version) : spec[:flag]
      quote = spec[:quote] != false

      case spec[:type]
      when :boolean
        args << "#{flag} "
      when :value
        args << "#{flag} #{quote ? "\"#{value}\"" : value} "
      when :inline_value
        args << "\"#{flag}#{value}\" "
      when :list
        Array(value).each { |v| args << "#{flag} #{quote ? "\"#{v}\"" : v} " }
      when :integer
        args << "#{flag} #{value} " if value.is_a?(Integer)
      when :integer_percent
        unless value.is_a?(Integer)
          raise CeedlingException.new("#{component_prefix} ↳ :#{option} ➡️ '#{value}' must be an integer")
        end
        unless (1..100).cover?(value)
          raise CeedlingException.new("#{component_prefix} ↳ :#{option} ➡️ '#{value}' must be an integer percentage 1 – 100")
        end
        args << "#{flag} #{value} "
      end
    end
  end

end
