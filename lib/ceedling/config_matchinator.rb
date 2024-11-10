# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# :<section>:
#   :<context>:
#     :<optional operation>:
#       :<optional matcher>:
#         - <Value 1>
#         - <Value 2>
#         - ...

class ConfigMatchinator

  constructor :configurator, :loginator, :reportinator

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
      error = ":#{primary} ↳ :#{secondary} present in project configuration but does not contain :#{tertiary}."
      raise CeedlingException.new( error )

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
      error = ":#{primary} ↳ :#{secondary} in project configuration is neither a list nor hash."
      raise CeedlingException.new( error )
    end

    return nil
  end

  # Note: This method only relevant if hash includes test filepath matching keys
  def matches?(hash:, filepath:, section:, context:, operation:nil)
    _values = []

    # Sanity check
    if filepath.nil?
      path = generate_matcher_path(section, context, operation)
      error = "#{path} ↳ #{matcher} matching provided nil #{filepath}"
      raise CeedlingException.new(error)
    end

    # Iterate through every hash touple [matcher key, values array]
    # In prioritized order match test filepath against each matcher key.
    # This order matches on special patterns first to ensure no funny business with simple substring matching 
    #  1. All files wildcard ('*')
    #  2. Regex (/.../)
    #  3. Wildcard filepath matching (e.g. 'name*')
    #  4. Any filepath matching (substring matching)
    #
    # Each element of the collected _values array will be an array of values.

    hash.each do |matcher, values|
      mtached = false
      _matcher = matcher.to_s.strip

      # 1. Try gross wildcard matching -- return values for all test filepaths if '*' is the matching key
      if ('*' == _matcher)
        matched = true

      # 2. Try regular expression matching against all values matching keys that are regexes (ignore if not a valid regex)
      #    Note: We use logical AND here so that we get a meaningful fall-through condition.
      #          Nesting the actual regex matching beneath validity checking improperly catches unmatched regexes
      elsif (regex?(_matcher)) and (!(form_regex(_matcher).match(filepath)).nil?)
        matched = true

      # 3. Try wildcard matching -- return values for any test filepath that matches with '*' expansion
      #    Treat matcher as a regex:
      #      1. Escape any regex characters (e.g. '-')
      #      2. Convert any now escaped '\*'s into '.*'
      #      3. Match filepath against regex-ified matcher
      elsif (filepath =~ /#{Regexp.escape(matcher).gsub('\*', '.*')}/)
        matched = true

      # 4. Try filepath literal matching (including substring matching) with each matching key
      #    Note: (3) will do this if the matcher key lacks a '*', but this is a just-in-case backup
      elsif (filepath.include?(_matcher))
        matched = true
      end        

      if matched
        _values += values
        matched_notice(section:section, context:context, operation:operation, matcher:_matcher, filepath:filepath)
      else # No match
        path = generate_matcher_path(section, context, operation)
        @loginator.log("#{path} ↳ `#{matcher}` did not match #{filepath}", Verbosity::DEBUG)
      end
    end

    # Flatten to handle list-nested YAML aliasing (should have already been flattened during validation)
    return _values.flatten
  end

  ### Private ###

  private

  def matched_notice(section:, context:, operation:, matcher:, filepath:)
    path = generate_matcher_path(section, context, operation)
    @loginator.log("#{path} ↳ #{matcher} matched #{filepath}", Verbosity::OBNOXIOUS)
  end

  def generate_matcher_path(*keys)
    return @reportinator.generate_config_walk(keys)
  end

  # Assumes expr is a string and has been stripped
  def regex?(expr)
    valid = true

    if !expr.start_with?('/')
      return false
    end

    if !expr.end_with? ('/')
      return false
    end

    begin
      Regexp.new(expr[1..-2])
    rescue RegexpError
      valid = false
    end

    return valid
  end

  # Assumes expr is /.../
  def form_regex(expr)
    return Regexp.new(expr[1..-2])
  end

end
