

# :<section>:
#   :<context>:
#     :<optional operation>:
#       :<optional matcher>:
#         - <Value 1>
#         - <Value 2>
#         - ...

class ConfigMatchinator

  constructor :configurator, :streaminator

  def config_include?(section:, context:, operation:nil)
    # Create configurator accessor method
    accessor = (section.to_s + '_' + context.to_s).to_sym

    # If no entry in configuration for context in this section, bail out
    return false if not @configurator.respond_to?( accessor )

    # If operation undefined, we've progressed as far as we need and already know the config is present
    return true if operation.nil?

    # Get element associated with this context
    elem = @configurator.send( accessor )

    # If [section][context] is a simple array
    if elem.is_a?(Array)
      # A list instead of a hash, means [operation] is not present
      return false

    # If [section][context] is a hash
    elsif elem.is_a?(Hash)
      return elem.include?( operation )
    end

    # Otherwise, [section][context] is something that cannot contain an [operation] sub-hash
    return false
  end

  def get_config(section:, context:, operation:nil)
    # Create configurator accessor method
    accessor = (section.to_s + '_' + context.to_s).to_sym

    # If no entry in configuration for context in this section, bail out
    return nil if not @configurator.respond_to?( accessor )

    # Get config element associated with this context
    elem = @configurator.send( accessor )

    # If [section][context] is a simple array
    if elem.class == Array
      # If no operation specified, then a simple array makes sense
      return elem if operation.nil?

      # Otherwise, if an operation is specified but we have an array, go boom
      error = "ERROR: [#{section}][#{context}] present in project configuration but does not contain [#{operation}]."
      @streaminator.stderr_puts(error, Verbosity::ERRORS)
      raise

    # If [section][context] is a hash
    elsif elem.class == Hash
      if not operation.nil?
        # Bail out if we're looking for an [operation] sub-hash, but it's not present
        return nil if not elem.include?( operation )

        # Return array or hash at operation
        return elem[operation]

      # If operation is not being queried, but we have a hash, return the hash
      else
        return elem
      end

    # If [section][context] is nothing we expect--something other than an array or hash
    else
      error = "ERROR: [#{section}][#{context}] in project configuration is neither a list nor hash."
      @streaminator.stderr_puts(error, Verbosity::ERRORS)
      raise
    end

    return nil
  end

  def validate_matchers(hash:, section:, context:, operation:nil)
    # Look for matcher keys with missing values
    hash.each do |k, v|
      if v == nil
        operation = operation.nil? ? '' : "[#{operation}]"
        error = "ERROR: Missing list of values for [#{section}][#{context}]#{operation}[#{k}] matcher in project configuration."
        @streaminator.stderr_puts(error, Verbosity::ERRORS)
        raise
      end
    end
  end

  # Note: This method only relevant if hash includes test filepath matching keys
  def matches?(hash:, filepath:, section:, context:, operation:nil)
    _values = []

    # Sanity check
    if filepath.nil?
      @streaminator.stderr_puts("NOTICE: [#{section}][#{context}]#{operation} > '#{matcher}' matching provided nil #{filepath}", Verbosity::ERROR)
      raise
    end

    # Iterate through every hash touple [matcher key, values array]
    # In prioritized order match test filepath against each matcher key...
    #  1. Wildcard
    #  2. Any filepath matching
    #  3. Regex
    #
    # Wildcard and filepath matching can look like valid regexes, so they must be evaluated first.
    #
    # Each element of the collected _values array will be an array of values.

    hash.each do |matcher, values|
      # 1. Try wildcard matching -- return values for every test filepath if '*' is found in values matching key
      if ('*' == matcher.to_s.strip)
        _values += values

      # 2. Try filepath literal matching (including substring matching) with each values matching key
      elsif (filepath.include?(matcher.to_s.strip))
        _values += values

      # 3. Try regular expression matching against all values matching keys that are regexes (ignore if not a valid regex)
      # Note: We use logical AND here so that we get a meaningful fall-through to the else reporting condition.
      #       Nesting the actual regex matching beneath validity checking improperly catches unmatched regexes
      elsif (regex?(matcher.to_s.strip)) and (!(filepath =~ /#{matcher.to_s.strip}/).nil?)
        _values += values

      else
        operation = operation.nil? ? '' : "[#{operation}]"
        @streaminator.stderr_puts("NOTICE: [#{section}][#{context}]#{operation} > '#{matcher}' did not match #{filepath}", Verbosity::DEBUG)
      end        
    end

    return _values.flatten # Flatten to handle YAML aliases
  end

  private

  def regex?(expr)
    valid = true

    begin
      Regexp.new(expr)
    rescue RegexpError
      valid = false
    end

    return valid
  end

end
