require 'ceedling/plugin'
require 'ceedling/exceptions'

BEEP_ROOT_NAME = 'beep'.freeze
BEEP_SYM       = BEEP_ROOT_NAME.to_sym

class Beep < Plugin
  
  def setup
    # Get non-flattenified project configuration
    project_config = @ceedling[:setupinator].config_hash
    
    # Get beep configuration hash
    beep_config = project_config[BEEP_SYM]
    # Get tools hash
    tools = project_config[:tools]

    # Lookup the selected beep tool
    @tools = {
      :beep_on_done => tools["beep_#{beep_config[:on_done]}".to_sym],
      :beep_on_error => tools["beep_#{beep_config[:on_error]}".to_sym]
    }
    
    # Ensure configuration option is an actual tool
    if @tools[:beep_on_done].nil?
      raise CeedlingException.new("Option :#{beep_config[:on_done]} for :beep ↳ :on_done plugin configuration does not map to a tool.")
    end
    
    # Ensure configuration option is an actual tool
    if @tools[:beep_on_error].nil?
      raise CeedlingException.new("Option :#{beep_config[:on_done]} for :beep ↳ :on_error plugin configuration does not map to a tool.")
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
      ["ceedling build done"]) # Only used by tools with `${1}` replacement argument

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
      ["ceedling build error"]) # Only used by tools with `${1}` replacement argument

    @ceedling[:streaminator].stdout_puts("Command: #{command}", Verbosity::DEBUG)

    # Verbosity is enabled to allow shell output (primarily for sake of the bell character)
    @ceedling[:system_wrapper].shell_system( command: command[:line], verbose: true )
  end
  
end
