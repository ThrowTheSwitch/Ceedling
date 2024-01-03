require 'ceedling/plugin'
require 'ceedling/exceptions'
require 'beep_tools'

BEEP_ROOT_NAME = 'beep'.freeze
BEEP_SYM       = BEEP_ROOT_NAME.to_sym

class Beep < Plugin
  
  def setup
    project_config = @ceedling[:setupinator].config_hash
    @config = project_config[BEEP_SYM]
    @tools = {
      :beep_on_done => BEEP_TOOLS[@config[:on_done]]&.deep_clone,
      :beep_on_error => BEEP_TOOLS[@config[:on_error]]&.deep_clone
    }
    
    if @tools[:beep_on_done].nil?
      raise CeedlingException.new("Option '#{@config[:on_done]}' for plugin :beep ↳ :on_done configuration did not map to a tool.")
    end
    
    if @tools[:beep_on_error].nil?
      raise CeedlingException.new("Option '#{@config[:on_done]}' for plugin :beep ↳ :on_error configuration did not map to a tool.")
    end
  end
  
  def post_build
    if @tools[:beep_on_done].nil?
      @ceedling[:streaminator].stderr_puts("Tool for :beep ↳ :on_done event handling is not available", Verbosity::COMPLAIN)
      return
    end

    command = @ceedling[:tool_executor].build_command_line(
      @tools[:beep_on_done],
      [],
      ["ceedling build done"]) # Only used by tools with `${1}` replacement arguments

    @ceedling[:streaminator].stdout_puts("Command: #{command}", Verbosity::DEBUG)

    # Verbosity is enabled to allow shell output (primarily for sake of the bell character)
    @ceedling[:system_wrapper].shell_system( command: command[:line], verbose: true )
  end
  
  def post_error
    if @tools[:beep_on_error].nil?
      @ceedling[:streaminator].stderr_puts("Tool for :beep ↳ :on_error event handling is not available", Verbosity::COMPLAIN)
      return
    end

    command = @ceedling[:tool_executor].build_command_line(
      @tools[:beep_on_error],
      [],
      ["ceedling build error"]) # Only used by tools with `${1}` replacement arguments

    @ceedling[:streaminator].stdout_puts("Command: #{command}", Verbosity::DEBUG)

    # Verbosity is enabled to allow shell output (primarily for sake of the bell character)
    @ceedling[:system_wrapper].shell_system( command: command[:line], verbose: true )
  end
  
end
