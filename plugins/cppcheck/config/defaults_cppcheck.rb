# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# `:optional => true` keeps Ceedling's project-wide tool validation from failing a
# build merely because this plugin is enabled. Cppcheck is an external tool, so an
# enabled plugin is not evidence the executable exists. The plugin validates it for
# real at `cppcheck:` task time instead. See the :cppcheck_deps Rake task.
DEFAULT_CPPCHECK_TOOL = {
  :executable => (ENV['CPPCHECK'].nil? ? FilePathUtils.os_executable_ext('cppcheck') : ENV['CPPCHECK'].split[0]).freeze,
  :name => 'default_cppcheck'.freeze,
  :stderr_redirect => StdErrRedirect::AUTO.freeze,
  :optional => true.freeze,
  :arguments => [
    '-I"${1}"'.freeze,
    '${2}'.freeze
  ].freeze
}

DEFAULT_CPPCHECK_HTMLREPORT_TOOL = {
  :executable => (ENV['CPPCHECK_HTMLREPORT'].nil? ? FilePathUtils.os_executable_ext('cppcheck-htmlreport') : ENV['CPPCHECK_HTMLREPORT'].split[0]).freeze,
  :name => 'default_cppcheck_htmlreport'.freeze,
  :stderr_redirect => StdErrRedirect::NONE.freeze,
  :optional => true.freeze,
  :arguments => [].freeze
}

def get_default_config()
  return :tools => {
    :cppcheck => DEFAULT_CPPCHECK_TOOL,
    :cppcheck_htmlreport => DEFAULT_CPPCHECK_HTMLREPORT_TOOL
  }
end
