# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# `covc` wraps the entire compiler invocation (Bullseye's "Direct covc Invocation"
# integration method): `covc [options] compiler args...`, where everything before
# the compiler name is parsed as a covc option, not passed through. Ceedling always
# inserts per-file/per-test flags (search paths, defines, matcher-based `:flags`
# entries) immediately after a tool's `:executable`, ahead of its `:arguments`, so
# `-q` and `gcc` are folded into `:executable` itself here rather than left as
# leading `:arguments` — that keeps every Ceedling-injected flag positioned after
# the wrapped compiler's name, in the compiler-args section covc passes through,
# instead of being misread as an unrecognized covc option.
#
# No `--file`/`-f` is passed — covc and every other Bullseye tool here default to
# the `COVFILE` environment variable, which the plugin sets via its
# `Plugin#environment` mechanism.
DEFAULT_BULLSEYE_COMPILER_TOOL = {
  :executable => "#{FilePathUtils.os_executable_ext('covc')} -q #{FilePathUtils.os_executable_ext('gcc')}".freeze,
  :name => 'default_bullseye_compiler'.freeze,
  :optional => false.freeze,
  :arguments => [
    "-g".freeze,
    "-I\"${5}\"".freeze, # Per-test executable search paths
    "-D\"${6}\"".freeze, # Per-test executable defines
    "-DBULLSEYE_COMPILER".freeze,
    "-c \"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    "-MMD".freeze,
    "-MF \"${4}\"".freeze,
    ].freeze
  }

# `covc` wraps the entire linker invocation too — Bullseye's runtime auto-links
# its coverage library on the link step, so no manual -lcov/-L<path> is needed.
# `:executable` folds in `-q gcc` for the same reason as the compiler tool above.
DEFAULT_BULLSEYE_LINKER_TOOL = {
  :executable => "#{FilePathUtils.os_executable_ext('covc')} -q #{FilePathUtils.os_executable_ext('gcc')}".freeze,
  :name => 'default_bullseye_linker'.freeze,
  :optional => false.freeze,
  :arguments => [
    "-g".freeze,
    "${1}".freeze,
    "${5}".freeze,
    "-o \"${2}\"".freeze,
    "${4}".freeze,
    ].freeze
  }

DEFAULT_BULLSEYE_FIXTURE_TOOL = {
  :executable => '${1}'.freeze,
  :name => 'default_bullseye_fixture'.freeze,
  :optional => false.freeze,
  :arguments => [].freeze
  }

# Whole-COVFILE totals report, printed to console after a bullseye: task run
DEFAULT_BULLSEYE_REPORT_COVSRC_TOOL = {
  :executable => FilePathUtils.os_executable_ext('covsrc').freeze,
  :name => 'default_bullseye_report_covsrc'.freeze,
  :optional => true.freeze,
  :arguments => [
    "-q".freeze,
    "-w140".freeze,
    ].freeze
  }

# Per-source function-level coverage dump, printed to console after a bullseye: task run
DEFAULT_BULLSEYE_REPORT_COVFN_TOOL = {
  :executable => FilePathUtils.os_executable_ext('covfn').freeze,
  :name => 'default_bullseye_report_covfn'.freeze,
  :optional => true.freeze,
  :arguments => [
    "--width 120".freeze,
    "--no-source".freeze,
    "\"${1}\"".freeze,
    ].freeze
  }

# Generates a full interactive HTML coverage report. `covhtml` takes a single
# positional output-directory argument; no --file is needed (defaults to COVFILE).
DEFAULT_BULLSEYE_REPORT_COVHTML_TOOL = {
  :executable => FilePathUtils.os_executable_ext('covhtml').freeze,
  :name => 'default_bullseye_report_covhtml'.freeze,
  :optional => true.freeze,
  :arguments => [
    "-q".freeze,
    "\"${1}\"".freeze, # Output directory
    ].freeze
  }

# Applies report-time exclusions (framework/test sources) to the COVFILE's
# selection settings, independent of the coverage data itself. `--add '!pattern'`
# registers an exclusion; patterns support recursive `**/` and mid-filename `*` globs
# (e.g. `!**/test_*.c` excludes nested test sources regardless of directory depth,
# given BULLSEYE_COVFILE_PATH sits at project root — see bullseye_constants.rb).
DEFAULT_BULLSEYE_COVSELECT_TOOL = {
  :executable => FilePathUtils.os_executable_ext('covselect').freeze,
  :name => 'default_bullseye_covselect'.freeze,
  :optional => true.freeze,
  :arguments => [
    "-q".freeze,
    "--add".freeze,
    "\"${1}\"".freeze, # Exclusion pattern
    ].freeze
  }

# GUI coverage browser — relies on the COVFILE environment variable like every
# other Bullseye tool here; not a coverage-generation or reporting tool itself.
DEFAULT_BULLSEYE_BROWSER_TOOL = {
  :executable => FilePathUtils.os_executable_ext('CoverageBrowser').freeze,
  :name => 'default_bullseye_browser'.freeze,
  :optional => true.freeze,
  :arguments => [].freeze
  }

def get_default_config
  return :tools => {
    :bullseye_compiler       => DEFAULT_BULLSEYE_COMPILER_TOOL,
    :bullseye_linker         => DEFAULT_BULLSEYE_LINKER_TOOL,
    :bullseye_fixture        => DEFAULT_BULLSEYE_FIXTURE_TOOL,
    :bullseye_report_covsrc  => DEFAULT_BULLSEYE_REPORT_COVSRC_TOOL,
    :bullseye_report_covfn   => DEFAULT_BULLSEYE_REPORT_COVFN_TOOL,
    :bullseye_report_covhtml => DEFAULT_BULLSEYE_REPORT_COVHTML_TOOL,
    :bullseye_covselect      => DEFAULT_BULLSEYE_COVSELECT_TOOL,
    :bullseye_browser        => DEFAULT_BULLSEYE_BROWSER_TOOL,
  }
end
