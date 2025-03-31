require 'rake'
require 'stringio'

module CaptureHelpOutput
  def capture_display_tasks
    original_stdout = $stdout
    output_string = StringIO.new
    $stdout = output_string
    
    begin
      # Call the original method that writes directly to $stdout with printf()
      display_tasks_and_comments
    ensure
      # This block will always execute, even if an exception occurs
      $stdout = original_stdout
    end

    # Restore original stdout
    $stdout = original_stdout
    
    # Return the captured output
    output_string.string
  end
end
