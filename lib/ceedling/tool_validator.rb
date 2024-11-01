# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'rake' # For ext()
require 'ceedling/constants'
require 'ceedling/tool_executor'    # For argument replacement pattern
require 'ceedling/file_path_utils'  # For glob handling class methods


class ToolValidator
  
  constructor :file_wrapper, :loginator, :system_wrapper, :reportinator

  def validate(tool:, name:nil, extension:EXTENSION_EXECUTABLE, respect_optional:false, boom:false)
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

    # Get unfrozen copy so we can modify for our processing
    executable = tool[:executable].dup()

    # Handle a missing :executable
    if (executable.nil? or executable.empty?)
      error = "Tool #{name} is missing :executable in its configuration."
      if !boom
        @loginator.log( error, Verbosity::ERRORS )
        return false 
      end

      raise CeedlingException.new(error)
    end

    # If tool is optional and we're respecting that, don't bother to check if executable is legit
    return true if tool[:optional] and respect_optional

    # Skip everything if we've got an argument replacement pattern or Ruby string replacement in :executable
    # (Allow executable to be validated by shell at run time)
    return true if (executable =~ TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN)
    return true if (executable =~ RUBY_STRING_REPLACEMENT_PATTERN)

    # Extract the executable (including optional filepath) apart from any additional arguments
    # Be mindful of legal quote enclosures (e.g. `"Code Cruncher" foo bar`)
    executable.strip!
    if (matched = executable.match(/^"(.+)"/))
      # If the regex matched, extract contents of match group within parens
      executable = matched[1]
    else
      # Otherwise grab first token before arguments
      executable = executable.split(' ')[0]
    end

    # If no path included, verify file exists in system search paths
    if (not executable.include?('/'))      

      # Iterate over search paths
      @system_wrapper.search_paths.each do |path|
        # File exists as named
        if (@file_wrapper.exist?( File.join(path, executable)) )
          exists = true
          break
        # File exists with executable file extension
        elsif (@file_wrapper.exist?( (File.join(path, executable)).ext( extension ) ))
          exists = true
          break
        # We're on Windows and file exists with .exe file extension
        elsif (@system_wrapper.windows? and @file_wrapper.exist?( (File.join(path, executable)).ext( EXTENSION_WIN_EXE ) ))
          exists = true
          break
        end
      end

      # Construct end of error message
      error = "does not exist in system search paths" if not exists
      
    # If there is a path included, check that explicit filepath exists
    else
      if @file_wrapper.exist?( executable )
        exists = true
      else
        # Construct end of error message
        error = "does not exist on disk" if not exists
      end      
    end

    if !exists
      error = "#{name} ↳ :executable => `#{executable}` " + error
    end

    # Raise exception if executable can't be found and boom is set
    if !exists and boom
      raise CeedlingException.new( error )
    end

    # Otherwise, log error
    if !exists
      @loginator.log( error, Verbosity::ERRORS )
    end

    return exists
  end
  
  def validate_stderr_redirect(tool:, name:, boom:)
    error = ''
    redirect = tool[:stderr_redirect]

    # If no redirect set at all, it's cool
    return if redirect.nil?

    # Otherwise, process the redirect that's been set
    if redirect.class == Symbol
      if not StdErrRedirect.constants.map{|constant| constant.to_s}.include?( redirect.to_s.upcase )
        options = StdErrRedirect.constants.map{|constant| ':' + constant.to_s.downcase}.join(', ')
        error = "#{name} ↳ :stderr_redirect => :#{redirect} is not a recognized option {#{options}}"

        # Raise exception if requested
        raise CeedlingException.new( error ) if boom

        # Otherwise log error
        @loginator.log( error, Verbosity::ERRORS )
        return false
      end    
    elsif redirect.class != String
      raise CeedlingException.new( "#{name} ↳ :stderr_redirect is neither a recognized value nor custom string" )
    end

    return true
  end
  
end
