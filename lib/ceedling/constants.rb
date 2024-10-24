# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Logging verbosity levels
class Verbosity
  SILENT      = 0   # As silent as possible (though there are some messages that must be spit out)
  ERRORS      = 1   # Only errors
  COMPLAIN    = 2   # Spit out errors and warnings/notices
  NORMAL      = 3   # Errors, warnings/notices, standard status messages
  OBNOXIOUS   = 4   # All messages including extra verbose output (used for lite debugging / verification)
  DEBUG       = 5   # Special extra verbose output for hardcore debugging
end

VERBOSITY_OPTIONS = { 
  :silent    => Verbosity::SILENT,
  :errors    => Verbosity::ERRORS,
  :warnings  => Verbosity::COMPLAIN,
  :normal    => Verbosity::NORMAL,
  :obnoxious => Verbosity::OBNOXIOUS,
  :debug     => Verbosity::DEBUG,
}.freeze()

# Label + decorator options for logging
class LogLabels
  NONE       =  0  # Override logic and settings with no label and no decoration
  AUTO       =  1  # Default labeling and decorators
  NOTICE     =  2  # decorator + 'NOTICE:'
  WARNING    =  3  # decorator + 'WARNING:'
  ERROR      =  4  # decorator + 'ERROR:'
  EXCEPTION  =  5  # decorator + 'EXCEPTION:'
  CONSTRUCT  =  6  # decorator only
  RUN        =  7  # decorator only
  CRASH      =  8  # decorator only
  PASS       =  9  # decorator only
  FAIL       = 10  # decorator only
  TITLE      = 11  # decorator only

  # Verbosity levels ERRORS – DEBUG default to certain labels or lack thereof
  # The above label constants are available to override Loginator's default AUTO level as needed
  # See Loginator comments
end

class DurationCounts
  DAY_MS     = (24 * 60 * 60 * 1000)
  HOUR_MS    =      (60 * 60 * 1000)
  MINUTE_MS  =           (60 * 1000)
  SECOND_MS  =                (1000)
end

class TestResultsSanityChecks
  NONE      = 0  # no sanity checking of test results
  NORMAL    = 1  # perform non-problematic checks
  THOROUGH  = 2  # perform checks that require inside knowledge of system workings
end

class StdErrRedirect
  NONE = :none
  AUTO = :auto
  WIN  = :win
  UNIX = :unix
  TCSH = :tcsh
end

GIT_COMMIT_SHA_FILENAME = 'GIT_COMMIT_SHA'

# Escaped newline literal (literally double-slash-n) for "encoding" multiline strings as single string
NEWLINE_TOKEN = '\\n'

DEFAULT_PROJECT_FILENAME = 'project.yml'
DEFAULT_BUILD_LOGS_PATH = 'logs'

GENERATED_DIR_PATH = [['vendor', 'ceedling'], 'src', "test", ['test', 'support'], 'build'].each{|p| File.join(*p)}

EXTENSION_WIN_EXE     = '.exe'
EXTENSION_NONWIN_EXE  = '.out'
# Vendor frameworks, generated mocks, generated runners are always .c files
EXTENSION_CORE_SOURCE = '.c' 

PREPROCESS_SYM = :preprocess

CEXCEPTION_SYM       = :cexception
CEXCEPTION_ROOT_PATH = 'c_exception'
CEXCEPTION_LIB_PATH  = "#{CEXCEPTION_ROOT_PATH}/lib"
CEXCEPTION_C_FILE    = 'CException.c'
CEXCEPTION_H_FILE    = 'CException.h'

UNITY_SYM              = :unity
UNITY_ROOT_PATH        = 'unity'
UNITY_LIB_PATH         = "#{UNITY_ROOT_PATH}/src"
UNITY_C_FILE           = 'unity.c'
UNITY_H_FILE           = 'unity.h'
UNITY_INTERNALS_H_FILE = 'unity_internals.h'

# Do-nothing macros defined in unity.h for extra build context to be used by build tools like Ceedling
UNITY_TEST_SOURCE_FILE  = 'TEST_SOURCE_FILE'
UNITY_TEST_INCLUDE_PATH = 'TEST_INCLUDE_PATH'

RUNNER_BUILD_CMDLINE_ARGS_DEFINE = 'UNITY_USE_COMMAND_LINE_ARGS'

CMOCK_SYM       = :cmock
CMOCK_ROOT_PATH = 'cmock'
CMOCK_LIB_PATH  = "#{CMOCK_ROOT_PATH}/src"
CMOCK_C_FILE    = 'cmock.c'
CMOCK_H_FILE    = 'cmock.h'

DEFAULT_CEEDLING_LOGFILE = 'ceedling.log'

BACKTRACE_GDB_SCRIPT_FILE = 'backtrace.gdb'

INPUT_CONFIGURATION_CACHE_FILE = 'input.yml'   unless defined?(INPUT_CONFIGURATION_CACHE_FILE)     # input configuration file dump
DEFINES_DEPENDENCY_CACHE_FILE  = 'defines_dependency.yml' unless defined?(DEFINES_DEPENDENCY_CACHE_FILE) # preprocessor definitions for files

TEST_ROOT_NAME    = 'test'                unless defined?(TEST_ROOT_NAME)
TEST_TASK_ROOT    = TEST_ROOT_NAME + ':'  unless defined?(TEST_TASK_ROOT)
TEST_SYM          = :test

RELEASE_ROOT_NAME = 'release'                unless defined?(RELEASE_ROOT_NAME)
RELEASE_TASK_ROOT = RELEASE_ROOT_NAME + ':'  unless defined?(RELEASE_TASK_ROOT)
RELEASE_SYM       = RELEASE_ROOT_NAME.to_sym unless defined?(RELEASE_SYM)

UTILS_ROOT_NAME   = 'utils'                unless defined?(UTILS_ROOT_NAME)
UTILS_TASK_ROOT   = UTILS_ROOT_NAME + ':'  unless defined?(UTILS_TASK_ROOT)
UTILS_SYM         = UTILS_ROOT_NAME.to_sym unless defined?(UTILS_SYM)

OPERATION_PREPROCESS_SYM  = :preprocess unless defined?(OPERATION_PREPROCESS_SYM)
OPERATION_COMPILE_SYM     = :compile    unless defined?(OPERATION_COMPILE_SYM)
OPERATION_ASSEMBLE_SYM    = :assemble   unless defined?(OPERATION_ASSEMBLE_SYM)
OPERATION_LINK_SYM        = :link       unless defined?(OPERATION_LINK_SYM)


# Match presence of any glob pattern characters
GLOB_PATTERN = /[\*\?\{\}\[\]]/
RUBY_STRING_REPLACEMENT_PATTERN = /#\{.+\}/
TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN = /(\$\{(\d+)\})/
TEST_STDOUT_STATISTICS_PATTERN  = /\n-+\s*(\d+)\s+Tests\s+(\d+)\s+Failures\s+(\d+)\s+Ignored\s+(OK|FAIL)\s*/i

NULL_FILE_PATH = '/dev/null'

TESTS_BASE_PATH   = TEST_ROOT_NAME
RELEASE_BASE_PATH = RELEASE_ROOT_NAME

VENDORS_FILES = %w(unity UnityHelper cmock CException).freeze

# Ruby Here
UNITY_TEST_RESULTS_TEMPLATE = <<~UNITY_TEST_RESULTS
  %{output}

  -----------------------
  %{total} Tests %{failed} Failures %{ignored} Ignored
  %{result}
UNITY_TEST_RESULTS




