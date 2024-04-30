# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class Streaminator

  constructor :streaminator_helper, :verbosinator, :loginator, :stream_wrapper

  def setup()
    $decorate = false if $decorate.nil?
  end

  # for those objects for whom the configurator has already been instantiated,
  # Streaminator is a convenience object for handling verbosity and writing to the std streams

  def stream_puts(string, verbosity=Verbosity::NORMAL, stream=nil)

    # If no stream has been specified, choose one based on the verbosity level of the prompt
    if stream.nil?
      if verbosity <= Verbosity::ERRORS
        stream = $stderr
      else
        stream = $stdout
      end
    end

    # write to log as though Verbosity::OBNOXIOUS
    @loginator.log( string, @streaminator_helper.extract_name(stream) )

    # Flatten if needed
    string = string.flatten.join('\n') if (string.class == Array)

    # Only stream when message reaches current verbosity level
    if (@verbosinator.should_output?(verbosity))

      # Apply decorations if supported
      if ($decorate)
        {
          / -> /      => ' ↳ ',
          /^Ceedling/ => '🌱 Ceedling',
        }.each_pair {|k,v| string.gsub!(k,v) }
        if (verbosity == Verbosity::ERRORS)
          string.sub!(/^\n?/, "\n🪲 ")
        end
      end

      # Write to output stream
      stream.puts(string)
    end
  end

  def decorate(d)
    $decorate = d
  end

end
