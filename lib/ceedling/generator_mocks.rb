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
    case @configurator.project_verbosity
    when Verbosity::SILENT
      config[:verbosity] = 0 # CMock is silent
    when Verbosity::ERRORS
    when Verbosity::COMPLAIN
    when Verbosity::NORMAL
    when Verbosity::OBNOXIOUS
      config[:verbosity] = 1 # Errors and warnings only so we can customize generation message ourselves
    else # DEBUG
      config[:verbosity] = 3 # Max verbosity
    end

    return config
  end
  
end
