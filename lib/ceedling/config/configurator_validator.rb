# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/config/config_matchinator'


class ConfiguratorValidator

  constructor :config_walkinator, :loginator, :reportinator, :tool_validator

  # Walk into config hash verify existence of data at key depth
  def exists?(config, *keys)
    hash, _ = @config_walkinator.fetch_value( *keys, hash:config )
    return true unless hash.nil?

    log_error( "Required config file entry #{@reportinator.generate_config_walk( keys )} does not exist." )
    return false
  end

  def validate_tool(config:, key:, respect_optional:true)
    # Get tool
    walk = [:tools, key]
    tool, _ = @config_walkinator.fetch_value( *walk, hash:config )

    arg_hash = {
      tool: tool,
      name: @reportinator.generate_config_walk( walk ),
      extension: config[:extension][:executable],
      respect_optional: respect_optional
    }

    return @tool_validator.validate( **arg_hash )
  end


  # Raises with the reason a matcher is malformed
  def validate_matcher(matcher)
    return validate_regex_matcher( matcher ) if ConfigMatchinator.regex_form?( matcher )

    # A substring or wildcard matcher allows only these characters
    invalid = matcher.gsub( /[a-z0-9 \/\.\-_\*]/i, '' ).chars.uniq
    return if invalid.empty?

    raise "invalid substring or wildcard characters #{invalid.map { |char| "'#{char}'" }.join( ', ' )}"
  end

  ### Private ###

  private

  def validate_regex_matcher(matcher)
    Regexp.compile( matcher[1..-2] )
  rescue RegexpError => ex
    raise "invalid regular expression: #{ex.message}"
  end

  def log_error(message)
    @loginator.log( message, Verbosity::ERRORS )
  end

end
