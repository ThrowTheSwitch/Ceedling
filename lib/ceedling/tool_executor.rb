# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'benchmark'

class ToolExecutor

  constructor :configurator, :tool_executor_helper, :loginator, :verbosinator, :system_wrapper

  # build up a command line from yaml provided config

  # @param extra_params is an array of parameters to append to executable (prepend to rest of command line)
  def build_command_line(tool_config, extra_params, *args)
    command = {}

    command[:name] = tool_config[:name]
    command[:executable] = tool_config[:executable]

    command[:options] = {} # Blank to hold options set before `exec()` processes

    # Basic premise is to iterate top to bottom through arguments using '$' as
    # a string replacement indicator to expand globals or inline yaml arrays
    # into command line arguments via substitution strings.
    executable = @tool_executor_helper.osify_path_separators(
      expandify_element(tool_config[:name], tool_config[:executable], *args)
    )

    command[:line] = [
      executable,
      extra_params.join(' ').strip,
      build_arguments(tool_config[:name], tool_config[:arguments], *args),
      ].reject{|s| s.nil? || s.empty?}.join(' ').strip

    # Log command as is
    @loginator.log( "Command: #{command}", Verbosity::DEBUG )

    # Update executable after any expansion
    command[:executable] = executable

    return command
  end


  # shell out, execute command, and return response
  def exec(command, args=[])
    options = command[:options]

    options[:boom] = true if (options[:boom].nil?)
    options[:stderr_redirect] = StdErrRedirect::NONE if (options[:stderr_redirect].nil?)

    # Build command line
    command_line = [
      command[:line].strip,
      args,
      @tool_executor_helper.stderr_redirect_cmdline_append( options ),
      ].flatten.compact.join(' ')

    shell_result = {}

    # Wrap system level tool execution in exception handling
    begin
      time = Benchmark.realtime do
        shell_result = @system_wrapper.shell_capture3( command:command_line, boom:options[:boom] )
      end
      shell_result[:time] = time

    # Ultimately, re-raise the exception as ShellException populated with the exception message
    rescue => error
      raise ShellException.new( name:pretty_tool_name( command ), message: error.message )

    # Be sure to log what we can
    ensure
      # Scrub the string for illegal output
      unless shell_result[:output].nil?
        shell_result[:output] = shell_result[:output].scrub if "".respond_to?(:scrub)
        shell_result[:output].gsub!(/\033\[\d\dm/,'')
      end

      @tool_executor_helper.log_results( command_line, shell_result )
    end

    # Go boom if exit code is not 0 and that code means a fatal error
    # (Sometimes we don't want a non-0 exit code to cause an exception as the exit code may not mean a build-ending failure)
    if ((shell_result[:exit_code] != 0) and options[:boom])
      raise ShellException.new( shell_result:shell_result, name:pretty_tool_name( command ) )
    end

    return shell_result
  end

  private #############################


  def build_arguments(tool_name, config, *args)
    build_string = ''

    return nil if (config.nil?)

    # Iterate through each argument

    # The yaml blob array needs to be flattened so that yaml alias substitution is handled
    # correctly as it creates a nested array when an anchor is dereferenced
    config.flatten.each do |element|
      argument = ''

      case(element)
        # If we find a simple string then look for string replacement operators
        #  and expand with the parameters in this method's argument list
        when String then argument = expandify_element(tool_name, element, *args)
        # If we find a hash, then we grab the key as a substitution string and expand the
        #  hash's value(s) within that substitution string
        when Hash   then argument = dehashify_argument_elements(tool_name, element)
      end

      build_string.concat("#{argument} ") if (argument.length > 0)
    end

    build_string.strip!
    return build_string if (build_string.length > 0)
    return nil
  end


  # handle simple text string argument & argument array string replacement operators
  def expandify_element(tool_name, element, *args)
    match = //
    to_process = nil
    args_index = 0

    # handle ${#} input replacement
    if (element =~ TOOL_EXECUTOR_ARGUMENT_REPLACEMENT_PATTERN)
      args_index = ($2.to_i - 1)

      if (args.nil? or args[args_index].nil?)
        error = "Tool '#{tool_name}' expected valid argument data to accompany replacement operator #{$1}."
        raise CeedlingException.new( error )
      end

      match = /#{Regexp.escape($1)}/
      to_process = args[args_index]
    end

    # simple string argument: replace escaped '\$' and strip
    element.sub!(/\\\$/, '$')
    element.strip!

    build_string = ''

    # handle array or anything else passed into method to be expanded in place of replacement operators
    case (to_process)
      when Array then to_process.each {|value| build_string.concat( "#{element.sub(match, value.to_s)} " ) } if (to_process.size > 0)
      else build_string.concat( element.sub(match, to_process.to_s) )
    end

    # handle inline ruby string substitution
    if (build_string =~ RUBY_STRING_REPLACEMENT_PATTERN)
      build_string.replace(@system_wrapper.module_eval(build_string))
    end

    return build_string.strip
  end


  # handle argument hash: keys are substitution strings, values are data to be expanded within substitution strings
  def dehashify_argument_elements(tool_name, hash)
    build_string = ''
    elements = []

    # grab the substitution string (hash key)
    substitution = hash.keys[0].to_s
    # grab the string(s) to squirt into the substitution string (hash value)
    expand = hash[hash.keys[0]]

    if (expand.nil?)
      error = "Tool '#{tool_name}' could not expand nil elements for substitution string '#{substitution}'."
      raise CeedlingException.new( error )
    end

    # array-ify expansion input if only a single string
    expansion = ((expand.class == String) ? [expand] : expand)

    expansion.each do |item|
      # String eval substitution
      if (item =~ RUBY_STRING_REPLACEMENT_PATTERN)
        elements << @system_wrapper.module_eval(item)
      # Global constants
      elsif (@system_wrapper.constants_include?(item))
        const = Object.const_get(item)
        if (const.nil?)
          error = "Tool '#{tool_name}' found constant '#{item}' to be nil."
          raise CeedlingException.new( error )
        else
          elements << const
        end
      elsif (item.class == Array)
        elements << item
      elsif (item.class == String)
        error = "Tool '#{tool_name}' cannot expand nonexistent value '#{item}' for substitution string '#{substitution}'."
        raise CeedlingException.new( error )
      else
        error = "Tool '#{tool_name}' cannot expand value having type '#{item.class}' for substitution string '#{substitution}'."
        raise CeedlingException.new( error )
      end
    end

    # expand elements (whether string or array) into substitution string & replace escaped '\$'
    elements.flatten!
    elements.each do |element|
      build_string.concat( substitution.sub(/([^\\]*)\$/, "\\1#{element}") ) # don't replace escaped '\$' but allow us to replace just a lonesome '$'
      build_string.gsub!(/\\\$/, '$')
      build_string.concat(' ')
    end

    return build_string.strip
  end

  def pretty_tool_name(command)
    # Titleize command's name -- each word capitalized plus underscores replaced with spaces
    name = "#{command[:name].split(/ |\_/).map(&:capitalize).join(" ")}"

    executable = command[:executable].empty? ? '<no executable>' : command[:executable]

    # 'Name' (executable) 
    return "'#{name}' " + "(#{executable})"
  end

end
