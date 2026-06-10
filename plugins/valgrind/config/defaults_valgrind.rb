
DEFAULT_VALGRIND = {
    :executable => ENV['VALGRIND'].nil? ? FilePathUtils.os_executable_ext('valgrind').freeze : ENV['VALGRIND'].split[0],
    :name => 'default_valgrind'.freeze,
    :stderr_redirect => StdErrRedirect::NONE.freeze,
    :optional => false.freeze,
    :arguments => [
      "--leak-check=full".freeze,
      "--show-reachable=yes".freeze,
      "--show-leak-kinds=all".freeze,
      "--track-origins=yes".freeze,
      "--errors-for-leak-kinds=all".freeze,
      "--exit-on-first-error=yes".freeze,
      "--error-exitcode=1".freeze,
      "${1}".freeze
      ].freeze
    }

def get_default_config
    return :tools => {
        :valgrind => DEFAULT_VALGRIND
    }
end