require 'ceedling/plugin'
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
      @ceedling[:streaminator].stderr_puts("Tool :beep_on_done is not defined.", verbosity=Verbosity::COMPLAIN)
    end
    
    if @tools[:beep_on_error].nil?
      @ceedling[:streaminator].stderr_puts("Tool :beep_on_error is not defined.", verbosity=Verbosity::COMPLAIN)
    end
  end
  
  def post_build
    return if @tools[:beep_on_done].nil?
    command = @ceedling[:tool_executor].build_command_line(@tools[:beep_on_done], [])
    system(command[:line])
  end
  
  def post_error
    return if @tools[:beep_on_error].nil?
    command = @ceedling[:tool_executor].build_command_line(@tools[:beep_on_error], [])
    system(command[:line])
  end
  
end
