
class Verbosity
  SILENT      = 0  # as silent as possible (though there are some messages that must be spit out)
  ERRORS      = 1  # only errors
  COMPLAIN    = 2  # spit out errors and warnings/notices
  NORMAL      = 3  # errors, warnings/notices, standard status messages
  OBNOXIOUS   = 4  # all messages including extra verbose output (likely used for debugging)
end

class StdErrRedirect
  NONE = :none
  AUTO = :auto
  WIN  = :win
  UNIX = :unix
  TCSH = :tcsh
end


DEFAULT_CEEDLING_MAIN_PROJECT_FILE = 'project.yml' # main project file
DEFAULT_CEEDLING_USER_PROJECT_FILE = 'user.yml'    # supplemental user config file

TESTS_TASKS_ROOT_NAME   = 'test'
RELEASE_TASKS_ROOT_NAME = 'release'

RUBY_STRING_REPLACEMENT_PATTERN = /#\{.+\}/
RUBY_EVAL_REPLACEMENT_PATTERN   = /^\{(.+)\}$/
TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN = /(\$\{(\d+)\})/

NULL_FILE_PATH = '/dev/null'

TESTS_BASE_PATH   = 'tests'
RELEASE_BASE_PATH = 'release'
