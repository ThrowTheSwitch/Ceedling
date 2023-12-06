require 'ceedling/exceptions'

# :<section>:
#   :<context>:
#     :<optional operation>:
#       :<optional matcher>:
#         - <Value 1>
#         - <Value 2>
#         - ...

class ConfigMatchinator

  constructor :configurator, :streaminator

  def config_include?(primary:, secondary:, tertiary:nil)
    # Create configurator accessor method
    accessor = (primary.to_s + '_' + secondary.to_s).to_sym

    # If no entry in configuration for secondary in primary, bail out
    return false if not @configurator.respond_to?( accessor )

    # If tertiary undefined, we've progressed as far as we need and already know the config is present
    return true if tertiary.nil?

    # Get element associated with this context
    elem = @configurator.send( accessor )

    # If [primary][secondary] is a simple array
    if elem.is_a?(Array)
      # A list instead of a hash, means [tertiary] is not present
      return false

    # If [primary][secondary] is a hash
    elsif elem.is_a?(Hash)
      return elem.include?( tertiary )
    end

    # Otherwise, [primary][secondary] is something that cannot contain a [tertiary] sub-hash
    return false
  end

  def get_config(primary:, secondary:, tertiary:nil)
    # Create configurator accessor method
    accessor = (primary.to_s + '_' + secondary.to_s).to_sym

    # If no entry in configuration for secondary in primary, bail out
    return nil if not @configurator.respond_to?( accessor )

    # Get config element associated with this secondary
    elem = @configurator.send( accessor )

    # If [primary][secondary] is a simple array
    if elem.class == Array
      # If no tertiary specified, then a simple array makes sense
      return elem if tertiary.nil?

      # Otherwise, if an tertiary is specified but we have an array, go boom
      error = "ERROR: [#{primary}][#{secondary}] present in project configuration but does not contain [#{tertiary}]."
      raise CeedlingException.new(error)

    # If [primary][secondary] is a hash
    elsif elem.class == Hash
      if not tertiary.nil?
        # Bail out if we're looking for an [tertiary] sub-hash, but it's not present
        return nil if not elem.include?( tertiary )

        # Return array or hash at tertiary
        return elem[tertiary]

      # If tertiary is not being queried, but we have a hash, return the hash
      else
        return elem
      end

    # If [primary][secondary] is nothing we expect--something other than an array or hash
    else
      error = "ERROR: [#{primary}][#{secondary}] in project configuration is neither a list nor hash."
      raise CeedlingException.new(error)
    end

    return nil
  end

  def validate_matchers(hash:, section:, context:, operation:nil)
    # Look for matcher keys with missing values
    hash.each do |k, v|
      if v == nil
        operation = operation.nil? ? '' : "[#{operation}]"
        error = "ERROR: Missing list of values for [#{section}][#{context}]#{operation}[#{k}] matcher in project configuration."
        raise CeedlingException.new(error)
      end
    end
  end

  # Note: This method only relevant if hash includes test filepath matching keys
  def matches?(hash:, filepath:, section:, context:, operation:nil)
    _values = []

    # Sanity check
    if filepath.nil?
      error = "ERROR: [#{section}][#{context}]#{operation} > '#{matcher}' matching provided nil #{filepath}"
      raise CeedlingException.new(error)
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
