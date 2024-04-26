# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

class Verbosity
  SILENT      = 0   # as silent as possible (though there are some messages that must be spit out)
  ERRORS      = 1   # only errors
  COMPLAIN    = 2   # spit out errors and warnings/notices
  NORMAL      = 3   # errors, warnings/notices, standard status messages
  OBNOXIOUS   = 4   # all messages including extra verbose output (used for lite debugging / verification)
  DEBUG       = 5   # special extra verbose output for hardcore debugging
end

VERBOSITY_OPTIONS = { 
  :silent    => Verbosity::SILENT,
  :errors    => Verbosity::ERRORS,
  :warnings  => Verbosity::COMPLAIN,
  :normal    => Verbosity::NORMAL,
  :obnoxious => Verbosity::OBNOXIOUS,
  :debug     => Verbosity::DEBUG,
}.freeze()

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

DEFAULT_PROJECT_FILENAME = 'project.yml'

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

CMOCK_SYM       = :cmock
CMOCK_ROOT_PATH = 'cmock'
CMOCK_LIB_PATH  = "#{CMOCK_ROOT_PATH}/src"
CMOCK_C_FILE    = 'cmock.c'
CMOCK_H_FILE    = 'cmock.h'

DEFAULT_CEEDLING_LOGFILE = 'ceedling.log'

INPUT_CONFIGURATION_CACHE_FILE     = 'input.yml'   unless defined?(INPUT_CONFIGURATION_CACHE_FILE)     # input configuration file dump
DEFINES_DEPENDENCY_CACHE_FILE      = 'defines_dependency.yml' unless defined?(DEFINES_DEPENDENCY_CACHE_FILE) # preprocessor definitions for files

TEST_ROOT_NAME    = 'test'                unless defined?(TEST_ROOT_NAME)
TEST_TASK_ROOT    = TEST_ROOT_NAME + ':'  unless defined?(TEST_TASK_ROOT)
TEST_SYM          = :test

RELEASE_ROOT_NAME = 'release'                unless defined?(RELEASE_ROOT_NAME)
RELEASE_TASK_ROOT = RELEASE_ROOT_NAME + ':'  unless defined?(RELEASE_TASK_ROOT)
RELEASE_SYM       = RELEASE_ROOT_NAME.to_sym unless defined?(RELEASE_SYM)

UTILS_ROOT_NAME   = 'utils'                unless defined?(UTILS_ROOT_NAME)
UTILS_TASK_ROOT   = UTILS_ROOT_NAME + ':'  unless defined?(UTILS_TASK_ROOT)
UTILS_SYM         = UTILS_ROOT_NAME.to_sym unless defined?(UTILS_SYM)

OPERATION_COMPILE_SYM  = :compile  unless defined?(OPERATION_COMPILE_SYM)
OPERATION_ASSEMBLE_SYM = :assemble unless defined?(OPERATION_ASSEMBLE_SYM)
OPERATION_LINK_SYM     = :link     unless defined?(OPERATION_LINK_SYM)


# Match presence of any glob pattern characters
GLOB_PATTERN = /[\*\?\{\}\[\]]/
RUBY_STRING_REPLACEMENT_PATTERN = /#\{.+\}/
RUBY_EVAL_REPLACEMENT_PATTERN   = /^\{(.+)\}$/
TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN = /(\$\{(\d+)\})/
TEST_STDOUT_STATISTICS_PATTERN  = /\n-+\s*(\d+)\s+Tests\s+(\d+)\s+Failures\s+(\d+)\s+Ignored\s+(OK|FAIL)\s*/i

NULL_FILE_PATH = '/dev/null'

TESTS_BASE_PATH   = TEST_ROOT_NAME
RELEASE_BASE_PATH = RELEASE_ROOT_NAME

VENDORS_FILES = %w(unity UnityHelper cmock CException).freeze
