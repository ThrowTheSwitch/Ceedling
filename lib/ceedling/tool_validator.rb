require 'rake' # For ext()
require 'ceedling/constants'
require 'ceedling/tool_executor'    # For argument replacement pattern
require 'ceedling/file_path_utils'  # For glob handling class methods


class ToolValidator
  
  constructor :file_wrapper, :stream_wrapper, :system_wrapper, :reportinator

  def validate(tool:, name:nil, extension:, respect_optional:false, boom:false)
    # Redefine name with name inside tool hash if it's not provided
    # If the name is provided it's likely the formatted key path into the configuration file
    name = tool[:name] if name.nil? or name.empty?

    valid = true

    valid &= validate_executable( tool:tool, name:name, extension:extension, respect_optional:respect_optional, boom:boom )
    valid &= validate_stderr_redirect( tool:tool, name:name, boom:boom )

    return valid
  end

  ### Private ###

  private

  def validate_executable(tool:, name:, extension:, respect_optional:, boom:)
    exists = false
    error = ''

    filepath = tool[:executable]

    # Handle a missing :executable
    if (filepath.nil?)
      error = "#{name} is missing :executable in its configuration."
      if !boom
        @stream_wrapper.stderr_puts( 'ERROR: ' + error )
        return false 
      end

      raise CeedlingException.new(error)
    end

    # If optional tool, don't bother to check if executable is legit
    return true if tool[:optional] and respect_optional

    # Skip everything if we've got an argument replacement pattern in :executable
    # (Allow executable to be validated by shell at run time)
    return true if (filepath =~ TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN)

    # If no path included, verify file exists in system search paths
    if (not filepath.include?('/'))      

      # Iterate over search paths
      @system_wrapper.search_paths.each do |path|
        # File exists as named
        if (@file_wrapper.exist?( File.join(path, filepath)) )
          exists = true
          break
        # File exists with executable file extension
        elsif (@file_wrapper.exist?( (File.join(path, filepath)).ext( extension ) ))
          exists = true
          break
        # We're on Windows and file exists with .exe file extension
        elsif (@system_wrapper.windows? and @file_wrapper.exist?( (File.join(path, filepath)).ext( EXTENSION_WIN_EXE ) ))
          exists = true
          break
        end
      end

      # Construct end of error message
      error = "does not exist in system search paths." if not exists
      
    # If there is a path included, check that explicit filepath exists
    else
      if @file_wrapper.exist?(filepath)
        exists = true
      else
        # Construct end of error message
        error = "does not exist on disk." if not exists
      end      
    end

    if !exists
      error = "#{name} ↳ :executable => `#{filepath}` " + error
    end

    # Raise exception if executable can't be found and boom is set
    if !exists and boom
      raise CeedlingException.new( error )
    end

    # Otherwise, log error
    if !exists
      # No verbosity level (no @streaminator) since this is low level error & verbosity handling depends on self-referential configurator
      @stream_wrapper.stderr_puts( 'ERROR: ' + error )
    end

    return exists
  end
  
  def validate_stderr_redirect(tool:, name:, boom:)
    error = ''
    redirect = tool[:stderr_redirect]

    if redirect.class == Symbol
      if not StdErrRedirect.constants.map{|constant| constant.to_s}.include?( redirect.to_s.upcase )
        options = StdErrRedirect.constants.map{|constant| ':' + constant.to_s.downcase}.join(', ')
        error = "#{name} ↳ :stderr_redirect => :#{redirect} is not a recognized option {#{options}}."

        # Raise exception if requested
        raise CeedlingException.new( error ) if boom

        # Otherwise log error
        @stream_wrapper.stderr_puts('ERROR: ' + error)
        return false        
      end    
    elsif redirect.class != String
      raise CeedlingException.new( "#{name} ↳ :stderr_redirect is neither a recognized value nor custom string." )
    end

    return true
  end
  
end
