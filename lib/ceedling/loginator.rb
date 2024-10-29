# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Loginator handles console and file output of logging statements

class Loginator

  attr_reader :project_logging
  attr_writer :decorators

  constructor :verbosinator, :file_wrapper, :system_wrapper

  def setup()
    $loginator = self
    @decorators = false

    # Friendly robustification for certain testing scenarios
    unless @system_wrapper.nil?
      # Automatic setting of console printing decorations based on platform
      @decorators = !@system_wrapper.windows?()

      # Environment variable takes precedence over automatic setting
      _env = @system_wrapper.env_get('CEEDLING_DECORATORS') if !@system_wrapper.nil?
      if !_env.nil?
        if (_env == '1' or _env.strip().downcase() == 'true')
          @decorators = true
        elsif (_env == '0' or _env.strip().downcase() == 'false')
          @decorators = false
        end
      end
    end

    @replace = {
      # Problematic characters pattern => Simple characters
      /↳/ => '>>', # Config sub-entry notation
      /•/ => '*',  # Bulleted lists
    }

    @project_logging = false
    @log_filepath = nil
  
    @queue = Queue.new
    @worker = Thread.new do
      # Run tasks until there are no more enqueued
      @done = false
      while !@done do
        Thread.handle_interrupt(Exception => :never) do
          begin
            Thread.handle_interrupt(Exception => :immediate) do
              # pop(false) is blocking and should just hang here and wait for next message
              item = @queue.pop(false)
              if (item.nil?)
                @done = true
                next
              end

              # pick out the details
              message   = item[:message]
              label     = item[:label]
              verbosity = item[:verbosity]
              stream    = item[:stream]
              
              # Write to log as though Verbosity::DEBUG (no filtering at all) but without fun characters
              if @project_logging
                file_msg = message.dup() # Copy for safe inline modifications
        
                # Add labels
                file_msg = format( file_msg, verbosity, label, false )
        
                # Note: In practice, file-based logging only works with trailing newlines (i.e. `log()` calls)
                #       `out()` calls will be a little ugly in the log file, but these are typically only
                #       used for console logging anyhow.
                logfile( sanitize( file_msg, false ), extract_stream_name( stream ) )
              end
        
              # Only output to console when message reaches current verbosity level
              if !stream.nil? && (@verbosinator.should_output?( verbosity ))
                # Add labels and fun characters
                console_msg = format( message, verbosity, label, @decorators )
        
                # Write to output stream after optionally removing any problematic characters
                stream.print( sanitize( console_msg, @decorators ) )
              end
            end
          rescue ThreadError
            @done = true
          rescue Exception => e
            puts e.inspect
          end
        end
      end
    end
  end

  def wrapup
    begin
      @queue.close
      @worker.join
    rescue
      #If we failed at this point, just give up on it
    end
  end

  def set_logfile( log_filepath )
    if !log_filepath.empty?
      @project_logging = true
      @log_filepath = log_filepath
    end
  end


  # log()
  # -----
  #
  # Write the given string to an optional log file and to the console
  #  - Logging statements to a file are always at the highest verbosity
  #  - Console logging is controlled by the verbosity level
  #
  # For default label of LogLabels::AUTO
  #  - If verbosity ERRORS, add ERROR: heading
  #  - If verbosity COMPLAIN, added WARNING: heading
  #  - All other verbosity levels default to no heading
  #
  # By setting a label:
  #  - A heading begins a message regardless of verbosity level, except NONE
  #  - NONE forcibly presents headings and emoji decorators
  #
  # If decoration is enabled:
  #  - Add fun emojis before all headings, except TITLE
  #  - TITLE log level adds seedling emoji alone
  #
  # If decoration is disabled:
  #  - No emojis are added to label
  #  - Any problematic console characters in a message are replaced with
  #    simpler variants

  def log(message="\n", verbosity=Verbosity::NORMAL, label=LogLabels::AUTO, stream=nil)
    # Choose appropriate console stream
    stream = get_stream( verbosity, stream )

    # Flatten if needed
    message = message.flatten.join("\n") if (message.class == Array)

    # Message contatenated with "\n" (unless it aready ends with a newline)
    message += "\n" unless message.end_with?( "\n" )

    # Add item to the queue
    item = {
      :message => message,
      :verbosity => verbosity,
      :label => label,
      :stream => stream
    }
    @queue << item
  end


  def log_debug_backtrace(exception)
      log( "\nDebug Backtrace ==>", Verbosity::DEBUG )
      
      # Send backtrace to debug logging, formatted almost identically to how Ruby does it.
      # Don't log the exception message itself in the first `log()` call as it will already be logged elsewhere
      log( "#{exception.backtrace.first}: (#{exception.class})", Verbosity::DEBUG )
      log( exception.backtrace.drop(1).map{|s| "\t#{s}"}.join("\n"),                  Verbosity::DEBUG )
  end


  def decorate(str, label=LogLabels::NONE)
    return str if !@decorators

    prepend = ''

    case label
    when LogLabels::NOTICE
      prepend = 'ℹ️ '
    when LogLabels::WARNING
      prepend = '⚠️ '
    when LogLabels::ERROR
      prepend = '🪲 '
    when LogLabels::EXCEPTION
      prepend = '🧨 '
    when LogLabels::CONSTRUCT
      prepend = '🚧 '
    when LogLabels::CRASH
      prepend = '☠️ '
    when LogLabels::RUN
      prepend = '👟 '
    when LogLabels::PASS
      prepend = '✅ '
    when LogLabels::FAIL
      prepend = '❌ '
    when LogLabels::TITLE
      prepend = '🌱 '
    end

    return prepend + str
  end


  def sanitize(string, decorate=nil)
    # Redefine `decorate` to @decorators value by default,
    # otherwise use the argument as an override value
    decorate = @decorators if decorate.nil?

    # Remove problematic console characters in-place if decoration disabled
    @replace.each_pair {|k,v| string.gsub!( k, v) } if (decorate == false)
    return string
  end

  ### Private ###

  private

  def get_stream(verbosity, stream)
    # If no stream has been specified, choose one based on the verbosity level of the prompt
    if stream.nil?
      if verbosity <= Verbosity::ERRORS
        return $stderr
      else
        return $stdout
      end
    end

    return stream
  end


  def format(string, verbosity, label, decorate)
    prepend = ''

    # Force no automatic label / decorator
    return string if label == LogLabels::NONE

    # Add decorators if enabled
    if decorate
      case label
      when LogLabels::AUTO
        if verbosity == Verbosity::ERRORS
          prepend = '🪲 '
        elsif verbosity == Verbosity::COMPLAIN
          prepend = '⚠️ '
        end
        # Otherwise, no decorators for verbosity levels
      else
        # If not auto, go get us a decorator
        prepend = decorate('', label)
      end
    end

    # Add headings
    case label
    when LogLabels::AUTO
      if verbosity == Verbosity::ERRORS
        prepend += 'ERROR: '
      elsif verbosity == Verbosity::COMPLAIN
        prepend += 'WARNING: '
      end
      # Otherwise, no headings
    when LogLabels::NOTICE
      prepend += 'NOTICE: '
    when LogLabels::WARNING
      prepend += 'WARNING: '
    when LogLabels::ERROR
      prepend += 'ERROR: '
    when LogLabels::EXCEPTION
      prepend += 'EXCEPTION: '
    when LogLabels::CRASH
      prepend += 'ERROR: '
    # Otherwise no headings for decorator-only messages
    end

    return prepend + string
  end


  def extract_stream_name(stream)
    name = case (stream.fileno)
      when 0 then '<IO:$stdin>'
      when 1 then '<IO:$stdout>'
      when 2 then '<IO:$stderr>'
      else stream.inspect
    end
    
    return name
  end


  def logfile(string, stream='')
    # Ex: '#<IO:$stdout> May  1 22:20:41 2024 | '
    header = "#{stream} #{@system_wrapper.time_now('%b %e %H:%M:%S %Y')} | "

    # Split any multiline strings so we can align them with the header
    lines = string.strip.split("\n")

    # Build output string with the first (can be only) line
    output = "#{header}#{lines[0]}\n"

    # If additional lines in a multiline string, pad them on the left
    # to align with the header
    if lines.length > 1
      lines[1..-1].each {|line| output += ((' ' * header.length) + line + "\n")}
    end

    # Example output:
    #
    # <IO:$stdout> May  1 22:20:40 2024 | Determining Artifacts to Be Built...
    # <IO:$stdout> May  1 22:20:40 2024 | Building Objects
    #                                     ----------------
    # <IO:$stdout> May  1 22:20:40 2024 | Compiling TestUsartModel.c...
    # <IO:$stdout> May  1 22:20:40 2024 | Compiling TestUsartModel::unity.c...
    # <IO:$stdout> May  1 22:20:40 2024 | Compiling TestUsartModel::cmock.c...

    @file_wrapper.write( @log_filepath, output, 'a' )
  end

end

END {
  $loginator.wrapup unless $loginator.nil?
}