# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Abstract base class that formalises the gcov reportinator interface.
#
# Subclasses must:
#   - Define a NAME string constant and implement name() to return it.
#   - Set @artifacts_path in initialize (nil for console-only reportinators)
#     and expose it via attr_reader.
#   - Set @configurator in initialize to access build_exclusion_data().
#   - Set @loginator in initialize to access print_shell_exec_time().
#   - Initialize @summary = '' and set it during generate_reports() when the
#     tool produces a coverage summary (e.g. gcovr --print-summary output).
#     Gcov#generate_coverage_reports reads summary() and is the sole logging site.
#   - Implement generate_reports(opts) as a void orchestrator.
#
class GcovReportinator

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

end
