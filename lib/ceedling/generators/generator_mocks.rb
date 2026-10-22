# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'cmock'

class GeneratorMocks

  constructor :configurator

  def manufacture(config)
    return CMock.new(config)
  end

  def build_configuration( output_path, overrides: {} )
    config = @configurator.get_cmock_config
    config[:mock_path] = output_path

    # A project sets one overall verbosity; CMock's own scale is coarser (errors
    # only, warnings and errors, normal, verbose), so this maps the finer scale
    # down onto CMock's four levels, keeping messaging from both tools balanced
    # rather than doubled up at every level. Middling verbosity levels settle
    # on CMock's "warnings and errors" as a reasonable default.
    verbosity = @configurator.project_verbosity

    config[:verbosity] = 1

    if    (verbosity <= Verbosity::ERRORS)
      # CMock's quietest level -- errors only, since it has no true silent mode.
      config[:verbosity] = 0
    elsif (verbosity == Verbosity::DEBUG)
      config[:verbosity] = 3
    end

    # A caller with a reason to run this one mock through CMock differently than
    # the project's own defaults hands in exactly the settings that differ; those
    # win over whatever was computed above.
    config.merge!( overrides )

    return config
  end
  
end
