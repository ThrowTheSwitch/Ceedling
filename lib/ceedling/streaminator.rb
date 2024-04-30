# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Loginator handles console and file output of logging statements

class Streaminator

  constructor :streaminator_helper, :verbosinator, :loginator, :stream_wrapper

  def setup()
    $decorate = false if $decorate.nil?

    @replace = {
      # Problematic characters pattern => Simple characters
      /↳/ => '>>', # Config sub-entry notation
      /•/ => '*',  # Bulleted lists
    }

  end


  # stream_puts() + out()
  # -----
  # stream_puts() -> add "\n"
  # out() -> raw string to stream(s)
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

  def stream_puts(string, verbosity=Verbosity::NORMAL, label=LogLabels::AUTO, stream=nil)
    # Call out() with string contatenated with "\n" (unless it aready ends with a newline)
    string += "\n" unless string.end_with?( "\n" )
    out( string, verbosity, label, stream )
  end


  def out(string, verbosity=Verbosity::NORMAL, label=LogLabels::AUTO, stream=nil)
    # Choose appropriate console stream
    stream = get_stream( verbosity, stream )

    # Add labels and fun characters
    string = format( string, verbosity, label )

    # write to log as though Verbosity::DEBUG (no filtering at all)
    @loginator.log( string, @streaminator_helper.extract_name( stream ) )

    # Only output when message reaches current verbosity level
    return if !(@verbosinator.should_output?( verbosity ))

    # Write to output stream after optionally removing any problematic characters
    stream.print( sanitize( string) )
  end


  def decorate(d)
    $decorate = d
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

  def format(string, verbosity, label)
    prepend = ''

    # Force no automatic label / decorator
    return string if label == LogLabels::NONE

    # Add decorators if enabled
    if $decorate
      case label
      when LogLabels::AUTO
        if verbosity == Verbosity::ERRORS
          prepend = '🪲 '
        elsif verbosity == Verbosity::COMPLAIN
          prepend = '⚠️ '
        end
        # Otherwise, no decorators for verbosity levels
      when LogLabels::NOTICE
        prepend = 'ℹ️ '
      when LogLabels::WARNING
        prepend = '⚠️ '
      when LogLabels::ERROR
        prepend = '🪲 '
      when LogLabels::EXCEPTION
        prepend = '🧨 '
      when LogLabels::SEGFAULT
        prepend = '☠️ '
      when LogLabels::TITLE
        prepend = '🌱 '
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
    end

    return prepend + string
  end

  def sanitize(string)
    # Remove problematic console characters in-place if decoration disabled
    @replace.each_pair {|k,v| string.gsub!( k, v) } if ($decorate == false)
    return string
  end

end
