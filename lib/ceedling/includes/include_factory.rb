# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# ========================================================================='

require 'ceedling/constants'
require 'ceedling/includes/includes'

class IncludeFactory

  constructor :configurator

  def user_include_from_directive(directive)
    results = directive.match(PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME)
    return user_include_from_filepath( results[1] ) if !results.nil?
    return nil
  end

  def user_include_from_filepath(filepath)
    if File.basename(filepath).start_with?( @configurator.cmock_mock_prefix )
      # Remove any build directory path that snuck into mock handling.
      # This can happen from discovering an empty mock stand-in or previously generated mock files.
      # This regex matches the base build mocks directory and any test name subdirectory beneath it.
      _filepath = filepath.sub( /^#{Regexp.escape( @configurator.cmock_mock_path )}\/[^\/]+\//, '' )
      return MockInclude.new(_filepath)
    end
    return UserInclude.new(filepath)
  end

  def system_include_from_directive(directive)
    results = directive.match(PATTERNS::SYSTEM_INCLUDE_DIRECTIVE_FILENAME)
    return system_include_from_filepath( results[1] ) if !results.nil?
    return nil
  end

  def system_include_from_filepath(filepath)
    # Just a light wrapper anticipating more complexities later on
    return SystemInclude.new(filepath)
  end

end