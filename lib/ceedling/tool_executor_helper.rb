# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants' # for Verbosity enumeration & $stderr redirect enumeration

##
# Helper functions for the tool executor
class ToolExecutorHelper

  constructor :loginator, :system_utils, :system_wrapper, :verbosinator

  ##
  # Modifies an executables path based on platform.
  # ==== Attributes
  #
  # * _executable_:  The executable's path.
  #
  def osify_path_separators(executable)
    return executable.gsub(/\//, '\\') if (@system_wrapper.windows?)
    return executable
  end

  ##
  # Returns the stderr redirect append based on the config.
  # ==== Attributes
  #
  # * _tool_config_:  A hash containing config information.
  #
  def stderr_redirect_cmdline_append(tool_config)
    return nil if (tool_config.nil? || tool_config[:stderr_redirect].nil?)

    config_redirect = tool_config[:stderr_redirect]
    redirect        = StdErrRedirect::NONE

    if (config_redirect == StdErrRedirect::AUTO)
       if (@system_wrapper.windows?)
         redirect = StdErrRedirect::WIN
       elsif (@system_utils.tcsh_shell?)
         redirect = StdErrRedirect::TCSH
       else
         redirect = StdErrRedirect::UNIX
       end
    end

    case redirect
      when StdErrRedirect::NONE then nil
      when StdErrRedirect::WIN  then '2>&1'
      when StdErrRedirect::UNIX then '2>&1'
      when StdErrRedirect::TCSH then '|&'
      else redirect.to_s
    end
  end

  ##
  # Logs tool execution results
  # ==== Attributes
  #
  # * _command_str_:  The command ran.
  # * _shell_results_:  The outputs of the command including exit code and output.
  #
  def log_results(command_str, shell_result)
    # No logging unless we're at least at Obnoxious
    return if !@verbosinator.should_output?( Verbosity::OBNOXIOUS )

    output =      "> Shell executed command:\n"
    output +=     "`#{command_str}`\n"

    if !shell_result.empty?
      # Detailed debug logging
      if @verbosinator.should_output?( Verbosity::DEBUG )
        output +=   "> With $stdout: "
        output += shell_result[:stdout].empty? ? "<empty>\n" : "\n#{shell_result[:stdout].strip()}\n"

        output +=   "> With $stderr: "
        output += shell_result[:stderr].empty? ? "<empty>\n" : "\n#{shell_result[:stderr].strip()}\n"

        output +=   "> And terminated with status: #{shell_result[:status]}\n"

        @loginator.log( '', Verbosity::DEBUG )
        @loginator.log( output, Verbosity::DEBUG )
        @loginator.log( '', Verbosity::DEBUG )

        return # Bail out
      end

      # Slightly less verbose obnoxious logging
      if !shell_result[:output].empty?
        output += "> Produced output: "
        output += shell_result[:output].strip().empty? ? "<empty>\n" : "\n#{shell_result[:output].strip()}\n"
      end

      if !shell_result[:exit_code].nil?
        output += "> And terminated with exit code: [#{shell_result[:exit_code]}]\n"
      else
        output += "> And exited prematurely\n"      
      end
    end

    @loginator.log( '', Verbosity::OBNOXIOUS )
    @loginator.log( output, Verbosity::OBNOXIOUS )
    @loginator.log( '', Verbosity::OBNOXIOUS )
  end
end
