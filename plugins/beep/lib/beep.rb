# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/plugin'
require 'ceedling/exceptions'

BEEP_ROOT_NAME = 'beep'.freeze
BEEP_SYM       = BEEP_ROOT_NAME.to_sym

class Beep < Plugin
  
  # `Plugin` setup()
  def setup
    # Get non-flattenified project configuration
    project_config = @ceedling[:setupinator].config_hash
    
    # Get beep configuration hash
    beep_config = project_config[BEEP_SYM]

    # Get tools hash
    tools = project_config[:tools]

    # Lookup and capture the selected beep tools
    @tools = {
      :beep_on_done => tools["beep_#{beep_config[:on_done]}".to_sym],
      :beep_on_error => tools["beep_#{beep_config[:on_error]}".to_sym]
    }
    
    # Ensure configuration option is an actual tool
    if @tools[:beep_on_done].nil?
      error = "Option :#{beep_config[:on_done]} for :beep ↳ :on_done plugin configuration does not map to a tool."
      raise CeedlingException.new( error )
    end
    
    # Ensure configuration option is an actual tool
    if @tools[:beep_on_error].nil?
      error = "Option :#{beep_config[:on_done]} for :beep ↳ :on_error plugin configuration does not map to a tool."
      raise CeedlingException.new( error )
    end

    # Validate the selected beep tools
    # Do not validate the `:bell` tool as it relies on `echo` that could be a shell feature rather than executable
    @ceedling[:tool_validator].validate(
      tool: @tools[:beep_on_done],
      boom: true
    ) if tools[:on_done] != :bell

    @ceedling[:tool_validator].validate(
      tool: @tools[:beep_on_error],
      boom: true
    ) if tools[:on_error] != :bell
  end

  # `Plugin` build step hook  
  def post_build
    command = @ceedling[:tool_executor].build_command_line(
      @tools[:beep_on_done],
      [],
      # Only used by tools with `${1}` replacement argument
      'ceedling build done'
    )


    # Verbosity is enabled to allow shell output (primarily for sake of the bell character)
    @ceedling[:system_wrapper].shell_system( command: command[:line], verbose: true )
  end
  
  # `Plugin` build step hook
  def post_error
    command = @ceedling[:tool_executor].build_command_line(
      @tools[:beep_on_error],
      [],
      # Only used by tools with `${1}` replacement argument
      'ceedling build error'
    )

    # Verbosity is enabled to allow shell output (primarily for sake of the bell character)
    @ceedling[:system_wrapper].shell_system( command: command[:line], verbose: true )
  end
  
end
