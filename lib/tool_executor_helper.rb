require 'constants' # for Verbosity enumeration

class ToolExecutorHelper

  constructor :streaminator

  # if command succeeded and we have verbosity cranked up, spill our guts
  def print_happy_results(command_str, shell_result)
    if (shell_result[:exit_code] == 0)
      output  = "> Shell executed command:\n"
      output += "#{command_str}\n"
      output += "> Produced response:\n"           if (not shell_result[:output].empty?)
      output += "#{shell_result[:output].strip}\n" if (not shell_result[:output].empty?)
      output += "\n"
    
      @streaminator.stdout_puts(output, Verbosity::OBNOXIOUS)
    end
  end

  # if command failed and we have verbosity set to minimum error level, spill our guts
  def print_error_results(command_str, shell_result)
    if (shell_result[:exit_code] != 0)
      output  = "ERROR: Shell command failed.\n"
      output += "> Shell executed command:\n"
      output += "#{command_str}\n"
      output += "> Produced response:\n"           if (not shell_result[:output].empty?)
      output += "#{shell_result[:output].strip}\n" if (not shell_result[:output].empty?)
      output += "> And exited with status: [#{shell_result[:exit_code]}].\n" if (shell_result[:exit_code] != nil)
      output += "> And then likely crashed.\n"                               if (shell_result[:exit_code] == nil)
      output += "\n"

      @streaminator.stderr_puts(output, Verbosity::ERRORS)
    end
  end
  
end
