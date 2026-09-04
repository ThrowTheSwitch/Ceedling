# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# major.minor version of any tool this plugin shells out to (gcovr, gcc) --
# generic so gcc-version and gcovr-version checks share one comparable type
# instead of each plugin file inventing its own.
ToolVersion = Struct.new(:major, :minor)

# Generic version detection + gating, mixed into any class that shells out to
# a tool whose available features depend on its version (GcovReportinator's
# gcovr/ReportGenerator subclasses, Gcov's own gcc check). One mechanic here;
# each includer supplies its own version-tool config, output pattern, and
# declarative gate table rather than hand-rolling comparison/raise boilerplate
# per gated option. Requires the includer to have set @tool_executor.
module ToolVersionGating

  # True when version is at least major.minor. Defined at both module- and instance-level
  # (the instance method just delegates) so a declarative table built at class-definition
  # time -- outside any includer instance's context, e.g. a Proc picking a version-dependent
  # flag name -- can still call it as ToolVersionGating.min_version?(...).
  def self.min_version?(version, major, minor)
    return true if version.major > major
    return true if version.major == major && version.minor >= minor
    return false
  end

  def min_version?(version, major, minor)
    ToolVersionGating.min_version?(version, major, minor)
  end

  # Run a `--version`-style tool invocation and parse a ToolVersion from its output.
  # tool_config: a ToolExecutor tool-config hash needing no positional substitutions.
  # pattern: a Regexp whose first two capture groups are (major, minor).
  def detect_tool_version(tool_config, pattern, tool_label:)
    command = @tool_executor.build_command_line( tool_config, [] )
    shell_result = @tool_executor.exec( command )
    version_match = shell_result[:output].match( pattern )

    if version_match.nil? || version_match[1].nil? || version_match[2].nil?
      raise CeedlingException.new( "Could not collect `#{tool_label}` version from its command line" )
    end

    ToolVersion.new( version_match[1].to_i, version_match[2].to_i )
  end

  # Raise one CeedlingException listing every configured option in gate_table whose
  # value is set but whose required minimum version exceeds the detected version.
  # gate_table: { option_symbol => { min: [major, minor], message: "... %{req} ... %{found} ..." } }.
  # opts: any hash the option symbols can be looked up in -- callers may merge values
  # from more than one config namespace (e.g. gcov.rb's :mcdc lives directly under
  # :gcov, not under :gcov ↳ :gcovr like GcovrReportinator's own gated options).
  def enforce_version_gates!(opts, version, gate_table)
    violations = gate_table.filter_map do |option, gate|
      next if opts[option].nil? || opts[option] == false
      next if min_version?( version, *gate[:min] )

      gate[:message] % { req: gate[:min].join('.'), found: "#{version.major}.#{version.minor}" }
    end

    raise CeedlingException.new( violations.join("\n") ) unless violations.empty?
  end

end
