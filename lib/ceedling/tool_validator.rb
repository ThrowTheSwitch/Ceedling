# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # For ext()
require 'ceedling/constants'
require 'ceedling/filename_extension'
require 'ceedling/exceptions'

# Confirms a tool's configuration can run before a build depends on it.
#
# A tool is valid when its executable can be found and its stderr redirect is a known
# option. The executable is an explicit path or a bare name searched on PATH, and either
# may omit the extension its file carries on disk. An executable built at run time, from
# an argument or a Ruby expansion, is left for the shell to resolve.
class ToolValidator

  constructor :file_wrapper, :loginator, :system_wrapper, :ruby_expandinator

  # The executable a tool's command names, or nil when it names none.
  #
  # A quoted executable may contain spaces (e.g. `"Code Cruncher" --fast`). Otherwise
  # the executable ends at the first space, ahead of the command's arguments.
  def self.executable_from(command)
    return nil if command.nil?

    command = command.strip
    return nil if command.empty?

    matched = command.match( /\A"(.+)"/ )
    return matched ? matched[1] : command.split( ' ' ).first
  end

  # Whether `executable` names a path rather than a name to search for. Windows' `\`
  # counts as a separator, since not every caller's paths pass through load-time cleanup.
  def self.explicit_path?(executable)
    return executable.match?( %r{[/\\]} )
  end

  # Every file that would satisfy `executable`, in the order they are tried.
  #
  # An explicit path is tried as written, and a bare name in each search path. Each is
  # also tried under every configured extension, and as .exe on Windows, since a command
  # may omit the extension its file carries on disk.
  def self.candidates(executable, extension:, windows:, search_paths:)
    bases = explicit_path?( executable ) ? [executable] : search_paths.map { |path| File.join( path, executable ) }

    return bases.flat_map { |base| variants( base, extension, windows ) }.uniq
  end

  def self.variants(path, extension, windows)
    variants = [path] + extension.map { |ext| path.ext( ext ) }
    variants << path.ext( EXTENSION_WIN_EXE ) if windows
    return variants
  end
  private_class_method :variants

  def validate(tool:, name:nil, extension:nil, respect_optional:false, boom:false)
    # A given name is usually the tool's key path into the configuration
    name = tool[:name] if name.nil? or name.empty?
    extension ||= default_extension()

    valid = validate_executable( tool:tool, name:name, extension:extension, respect_optional:respect_optional, boom:boom )

    # Both checks run, so a tool with two problems reports both
    return valid & validate_stderr_redirect( tool:tool, name:name, boom:boom )
  end

  ### Private ###

  private

  def validate_executable(tool:, name:, extension:, respect_optional:, boom:)
    command    = tool[:executable]
    executable = ToolValidator.executable_from( command )

    return fail_validation( "Tool #{name} is missing :executable in its configuration!", boom ) if executable.nil?

    return true if tool[:optional] and respect_optional

    return run_time_executable_valid?( command, name, boom ) if run_time_executable?( command )

    return true if executable_exists?( executable, extension )

    location = ToolValidator.explicit_path?( executable ) ? 'on disk' : 'in system search paths'
    return fail_validation( "#{name} ↳ :executable ➡️ `#{executable}` does not exist #{location}", boom )
  end

  # Whether the executable is built only when the tool runs, from an argument or a Ruby
  # expansion, so no file can be checked for now
  def run_time_executable?(command)
    return command.match?( PATTERNS::TOOL_EXECUTOR_ARGUMENT_REPLACEMENT ) ||
           command.match?( PATTERNS::RUBY_STRING_REPLACEMENT )
  end

  # The shell resolves an argument whenever the tool runs. A Ruby expansion resolves only
  # when that feature is enabled, so a disabled feature fails here rather than at run time.
  def run_time_executable_valid?(command, name, boom)
    return true if command.match?( PATTERNS::TOOL_EXECUTOR_ARGUMENT_REPLACEMENT )

    @ruby_expandinator.check!( command, source: "tool '#{name}' :executable" )
    return true
  rescue CeedlingException => e
    return fail_validation( e.message, boom )
  end

  # Search paths are read only for a bare name, which is the only kind searched for
  def executable_exists?(executable, extension)
    search_paths = ToolValidator.explicit_path?( executable ) ? [] : @system_wrapper.search_paths

    candidates = ToolValidator.candidates(
      executable,
      extension:    extension,
      windows:      @system_wrapper.windows?,
      search_paths: search_paths
    )

    return candidates.any? { |candidate| @file_wrapper.exist?( candidate ) }
  end

  def validate_stderr_redirect(tool:, name:, boom:)
    redirect = tool[:stderr_redirect]

    # No redirect and a custom redirect string are both valid
    return true if redirect.nil? or redirect.is_a?( String )

    # A value of the wrong type is a malformed configuration rather than a bad choice
    # among options, so it stops the build whatever `boom` is
    unless redirect.is_a?( Symbol )
      raise CeedlingException.new( "#{name} ↳ :stderr_redirect is neither a recognized value nor custom string" )
    end

    return true if recognized_redirect?( redirect )

    return fail_validation( "#{name} ↳ :stderr_redirect ➡️ :#{redirect} is not a recognized option {#{redirect_options()}}", boom )
  end

  # Options match case-insensitively, so :auto and :AUTO both name StdErrRedirect::AUTO
  def recognized_redirect?(redirect)
    return StdErrRedirect.constants.map( &:to_s ).include?( redirect.to_s.upcase )
  end

  def redirect_options()
    return StdErrRedirect.constants.map { |constant| ':' + constant.to_s.downcase }.join( ', ' )
  end

  # A loaded project configuration defines EXTENSION_EXECUTABLE. Before one loads, the
  # platform's own executable extension applies.
  def default_extension()
    return EXTENSION_EXECUTABLE if defined?( EXTENSION_EXECUTABLE )

    return FilenameExtension.new( @system_wrapper.windows? ? EXTENSION_WIN_EXE : EXTENSION_NONWIN_EXE )
  end

  # Raises under `boom`, and otherwise logs the error and reports the tool invalid
  def fail_validation(error, boom)
    raise CeedlingException.new( error ) if boom

    @loginator.log( error, Verbosity::ERRORS )
    return false
  end

end
