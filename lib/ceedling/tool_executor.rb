require 'ceedling/constants'
require 'ceedling/exceptions'
require 'benchmark'

class ToolExecutor

  constructor :configurator, :tool_executor_helper, :streaminator, :verbosinator, :system_wrapper

  # build up a command line from yaml provided config

  # @param extra_params is an array of parameters to append to executable (prepend to rest of command line)
  def build_command_line(tool_config, extra_params, *args)
    command = {}

    command[:name] = tool_config[:name]
    command[:executable] = tool_config[:executable]

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

    command[:options] = {
      :stderr_redirect => @tool_executor_helper.stderr_redirection( tool_config, @configurator.project_logging )
      }

    @streaminator.stdout_puts( "Command: #{command}", Verbosity::DEBUG )

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

    time = Benchmark.realtime do
      shell_result = @system_wrapper.shell_capture3( command:command_line, boom:options[:boom] )
    end
    shell_result[:time] = time

    # Scrub the string for illegal output
    unless shell_result[:output].nil?
      shell_result[:output] = shell_result[:output].scrub if "".respond_to?(:scrub)
      shell_result[:output].gsub!(/\033\[\d\dm/,'')
    end

    @tool_executor_helper.print_happy_results( command_line, shell_result, options[:boom] )
    @tool_executor_helper.print_error_results( command_line, shell_result, options[:boom] )

    # Go boom if exit code is not 0 and we want to debug (in some cases we don't want a non-0 exit code to raise)
    if ((shell_result[:exit_code] != 0) and options[:boom])
      raise ShellExecutionException.new(
        shell_result: shell_result,
        # Titleize the command's name--each word is capitalized and any underscores replaced with spaces
        message: "'#{command[:name].split(/ |\_/).map(&:capitalize).join(" ")}' (#{command[:executable]}) exited with an error"
        )
    end

    return shell_result
  end


  private #############################


  def build_arguments(tool_name, config, *args)
    build_string = ''

    return nil if (config.nil?)

    # Iterate through each argument

    # The yaml blob array needs to be flattened so that yaml substitution is handled
    # correctly as it creates a nested array when an anchor is dereferenced
    config.flatten.each do |element|
      argument = ''

      case(element)
        # if we find a simple string then look for string replacement operators
        #  and expand with the parameters in this method's argument list
        when String then argument = expandify_element(tool_name, element, *args)
        # if we find a hash, then we grab the key as a substitution string and expand the
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
        error = "ERROR: Tool '#{tool_name}' expected valid argument data to accompany replacement operator #{$1}."
        raise CeedlingException.new(error)
      end

      match = /#{Regexp.escape($1)}/
      to_process = args[args_index]
    end

    # simple string argument: replace escaped '\$' and strip
    element.sub!(/\\\$/, '$')
    element.strip!

    # handle inline ruby execution
    if (element =~ RUBY_EVAL_REPLACEMENT_PATTERN)
      puts("HERE")
      element.replace(eval($1))
    end

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
      error = "ERROR: Tool '#{tool_name}' could not expand nil elements for substitution string '#{substitution}'."
      raise CeedlingException.new(error)
    end

    # array-ify expansion input if only a single string
    expansion = ((expand.class == String) ? [expand] : expand)

    expansion.each do |item|
      # code eval substitution
      if (item =~ RUBY_EVAL_REPLACEMENT_PATTERN)
        elements << eval($1)
      # string eval substitution
      elsif (item =~ RUBY_STRING_REPLACEMENT_PATTERN)
        elements << @system_wrapper.module_eval(item)
      # global constants
      elsif (@system_wrapper.constants_include?(item))
        const = Object.const_get(item)
        if (const.nil?)
          error = "ERROR: Tool '#{tool_name}' found constant '#{item}' to be nil."
          raise CeedlingException.new(error)
        else
          elements << const
        end
      elsif (item.class == Array)
        elements << item
      elsif (item.class == String)
        error = "ERROR: Tool '#{tool_name}' cannot expand nonexistent value '#{item}' for substitution string '#{substitution}'."
        raise CeedlingException.new(error)
      else
        error = "ERROR: Tool '#{tool_name}' cannot expand value having type '#{item.class}' for substitution string '#{substitution}'."
        raise CeedlingException.new(error)
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

end
