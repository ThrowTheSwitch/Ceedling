# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/includes/includes'

class IncludeFactory

  constructor :configurator

  def user_include_from_directive(directive)
    results = directive.match(PATTERNS::USER_INCLUDE_DIRECTIVE_FILENAME)
    return user_include_from_filepath( results[1] ) if !results.nil?
    return nil
  end

  def user_include_from_filepath(filepath, test: nil)
    if File.basename(filepath).start_with?( @configurator.cmock_mock_prefix )
      return MockInclude.new( strip_mock_test_subdir( filepath, test ) )
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

  private

  # A resolved mock include's filepath may carry a leading build directory path that
  # snuck in from discovering an empty mock stand-in or an already-generated mock file.
  # That leading path is the current test's own mock subdirectory -- which mirrors the
  # test's path below its configured :paths -> :test root, so it can be more than one
  # segment deep (e.g. `adc/TestFoo`) -- followed by however many further segments mirror
  # the mocked header's own relative directory (e.g. `calculators/`). Knowing the current
  # test's identity lets exactly the first part be removed, leaving any header-mirroring
  # segments after it untouched. Without that identity, fall back to stripping everything
  # up through the last segment, the best a caller lacking test context can do.
  def strip_mock_test_subdir(filepath, test)
    if test
      prefix = File.join( @configurator.cmock_mock_path, test.to_s ) + '/'
      return filepath.start_with?( prefix ) ? filepath[prefix.length..] : filepath
    end
    return filepath.sub( /^#{Regexp.escape( @configurator.cmock_mock_path )}\/.+\//, '' )
  end

end