# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'cmock'

class GeneratorMocks

  constructor :configurator

  def manufacture(config)
    return CMock.new(config)
  end

  def build_configuration( output_path )
    config = @configurator.get_cmock_config
    config[:mock_path] = output_path

    # Verbosity management for logging messages
    verbosity = @configurator.project_verbosity

    # Default to errors and warnings only so we can customize messages inside Ceedling
    config[:verbosity] = 1

    # Extreme ends of verbosity scale case handling
    if    (verbosity == Verbosity::SILENT)
      # CMock is silent
      config[:verbosity] = 0
      
    elsif (verbosity == Verbosity::DEBUG)
      # CMock max verbosity
      config[:verbosity] = 3
    end

    return config
  end
  
end
