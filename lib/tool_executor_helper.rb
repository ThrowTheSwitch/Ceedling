require 'verbosinator' # for Verbosity enumeration

class ToolExecutorHelper

  constructor :verbosinator, :stream_wrapper

  # if command succeeded and we have verbosity cranked up, spill our guts
  def print_happy_results(command_str, shell_result)
    if ((shell_result[:exit_code] == 0) and @verbosinator.should_output?(Verbosity::OBNOXIOUS))
      @stream_wrapper.stdout_puts("> Shell executed command:")
      @stream_wrapper.stdout_puts(command_str)
      @stream_wrapper.stdout_puts("> Produced response:") if (not shell_result[:output].empty?)
      @stream_wrapper.stdout_puts(shell_result[:output])  if (not shell_result[:output].empty?)
      @stream_wrapper.stdout_puts('')
      @stream_wrapper.stdout_flush
    end
  end

  # if command failed and we have verbosity set to minimum error level, spill our guts
  def print_error_results(command_str, shell_result)
    if ((shell_result[:exit_code] != 0) and @verbosinator.should_output?(Verbosity::ERRORS))
      @stream_wrapper.stderr_puts("ERROR: Shell command failed.")
      @stream_wrapper.stderr_puts("> Shell executed command:")
      @stream_wrapper.stderr_puts(command_str)
      @stream_wrapper.stderr_puts("> Produced response:") if (not shell_result[:output].empty?)
      @stream_wrapper.stderr_puts(shell_result[:output])  if (not shell_result[:output].empty?)
      @stream_wrapper.stderr_puts("> And exited with status: [#{shell_result[:exit_code]}].")
      @stream_wrapper.stderr_puts('')
      @stream_wrapper.stderr_flush
    end
  end
  
end
