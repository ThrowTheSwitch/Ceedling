# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'cmock'

class GeneratorMocks

  constructor :configurator

  def manufacture(config)
    return CMock.new(config)
  end

  def build_configuration( output_path, mock_include_config=nil )
    config = @configurator.get_cmock_config
    config[:mock_path] = output_path

    apply_mock_include_config( config, mock_include_config )

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

  private

  def apply_mock_include_config(config, mock_include_config)
    return if mock_include_config.nil? || mock_include_config.empty?

    [
      :includes_h_pre_orig_header,
      :includes_h_post_orig_header,
      :includes_c_pre_header,
      :includes_c_post_header
    ].each do |key|
      next if mock_include_config[key].nil? || mock_include_config[key].empty?

      config[key] ||= []
      config[key] += mock_include_config[key]
      config[key].uniq!
    end
  end
  
end
