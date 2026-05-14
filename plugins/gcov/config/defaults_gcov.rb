# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

DEFAULT_GCOV_COMPILER_TOOL = {
  :executable => FilePathUtils.os_executable_ext('gcc').freeze,
  :name => 'default_gcov_compiler'.freeze,
  :optional => false.freeze,
  :arguments => [
    "-g".freeze,
    "-fprofile-arcs".freeze,
    "-ftest-coverage".freeze,
    "-I\"${5}\"".freeze, # Per-test executable search paths
    "-D\"${6}\"".freeze, # Per-test executable defines
    "-DGCOV_COMPILER".freeze,
    "-DCODE_COVERAGE".freeze,
    "-c \"${1}\"".freeze,
    "-o \"${2}\"".freeze,
    # gcc's list file output options are complex; no use of ${3} parameter in default config
    "-MMD".freeze,
    "-MF \"${4}\"".freeze,
    ].freeze
  }

DEFAULT_GCOV_LINKER_TOOL = {
  :executable => FilePathUtils.os_executable_ext('gcc').freeze,
  :name => 'default_gcov_linker'.freeze,
  :optional => false.freeze,
  :arguments => [
    "-g".freeze,
    "-fprofile-arcs".freeze,
    "-ftest-coverage".freeze,
    "${1}".freeze,
    "${5}".freeze,
    "-o \"${2}\"".freeze,
    "${4}".freeze,
    ].freeze
  }

DEFAULT_GCOV_FIXTURE_TOOL = {
  :executable => '${1}'.freeze,
  :name => 'default_gcov_fixture'.freeze,
  :optional => false.freeze,
  :arguments => [].freeze
  }

# Produce summaries printed to console
DEFAULT_GCOV_SUMMARY_TOOL = {
  :executable => FilePathUtils.os_executable_ext('gcov').freeze,
  :name => 'default_gcov_summary'.freeze,
  :optional => true.freeze,
  :arguments => [
    "-n".freeze,          # --no-output
    "-p".freeze,          # --preserve-paths
    "-b".freeze,          # --branch-probabilities
    "-o \"${2}\"".freeze, # --object-directory
    "\"${1}\"".freeze
    ].freeze
  }

# Produce .gcov files (used in conjunction with ReportGenerator)
DEFAULT_GCOV_REPORT_TOOL = {
  :executable => FilePathUtils.os_executable_ext('gcov').freeze,
  :name => 'default_gcov_report'.freeze,
  :optional => true.freeze,
  :arguments => [
    "-b".freeze,   # --branch-probabilities
    "-c".freeze,   # --branch-counts
    "-r".freeze,   # --relative-only
    "-x".freeze,   # --hash-filenames
    "${1}".freeze
    ].freeze
  }

# Produce reports with `gcovr`
DEFAULT_GCOV_GCOVR_REPORT_TOOL = {
  # No extension handling -- `gcovr` is generally an extensionless Python script
  :executable => 'gcovr'.freeze,
  :name => 'default_gcov_gcovr_report'.freeze,
  :optional => true.freeze,
  :arguments => [
    "${1}".freeze
    ].freeze
  }

# Produce reports with `reportgenerator`
DEFAULT_GCOV_REPORTGENERATOR_REPORT_TOOL = {
  :executable => FilePathUtils.os_executable_ext('reportgenerator').freeze,
  :name => 'default_gcov_reportgenerator_report'.freeze,
  :optional => true.freeze,
  :arguments => [
    "${1}".freeze
    ].freeze
  }

# Used internally to query GCC version at startup
DEFAULT_GCOV_GCC_VERSION_TOOL = {
  :executable => FilePathUtils.os_executable_ext('gcc').freeze,
  :name => 'default_gcov_gcc_version'.freeze,
  :optional => false.freeze,
  :arguments => ["--version"].freeze
  }

# Used internally to query gcovr version at startup
DEFAULT_GCOV_GCOVR_VERSION_TOOL = {
  # No extension handling -- `gcovr` is generally an extensionless Python script
  :executable => 'gcovr'.freeze,
  :name => 'default_gcov_gcovr_version'.freeze,
  :optional => true.freeze,
  :arguments => ["--version"].freeze
  }

def get_default_config
  return :tools => {
    :gcov_compiler => DEFAULT_GCOV_COMPILER_TOOL,
    :gcov_linker   => DEFAULT_GCOV_LINKER_TOOL,
    :gcov_fixture  => DEFAULT_GCOV_FIXTURE_TOOL,
    :gcov_summary  => DEFAULT_GCOV_SUMMARY_TOOL,
    :gcov_gcc_version => DEFAULT_GCOV_GCC_VERSION_TOOL,
    :gcov_gcovr_version => DEFAULT_GCOV_GCOVR_VERSION_TOOL,
    :gcov_report => DEFAULT_GCOV_REPORT_TOOL,
    :gcov_gcovr_report => DEFAULT_GCOV_GCOVR_REPORT_TOOL,
    :gcov_reportgenerator_report => DEFAULT_GCOV_REPORTGENERATOR_REPORT_TOOL,
  }
end
