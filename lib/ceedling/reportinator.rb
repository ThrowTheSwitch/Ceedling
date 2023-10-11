##
# Pretifies reports
class Reportinator

  ##
  # Generates a banner for a message based on the length of the message or a
  # given width.
  # ==== Attributes
  #
  # * _message_:  The message to put.
  # * _width_:    The width of the message. If nil the size of the banner is
  # determined by the length of the message.
  #
  # ==== Examples
  #
  #    rp = Reportinator.new
  #    rp.generate_banner("Hello world!") => "------------\nHello world!\n------------\n" 
  #    rp.generate_banner("Hello world!", 3) => "---\nHello world!\n---\n" 
  #
  #
  def generate_banner(message, width=nil)
    dash_count = ((width.nil?) ? message.strip.length : width)
    return "#{'-' * dash_count}\n#{message}\n#{'-' * dash_count}\n"
  end

  def generate_heading(message)
    # <Message>
    # ---------
    return "\n#{message}\n#{'-' * message.length}"
  end

  def generate_progress(message)
    # <Message>...
    return "#{message}..."
  end

  def generate_module_progress(module_name:, filename:, operation:)
    # <Operation [module_name::]filename>..."

    # If filename is the module name, don't add the module label
    label = (File.basename(filename).ext('') == module_name.to_s) ? '' : "#{module_name}::"
    return generate_progress("#{operation} #{label}#{filename}")
  end

end
