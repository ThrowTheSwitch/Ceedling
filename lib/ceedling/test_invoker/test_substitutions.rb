# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

# Knows which real headers a test substitutes and where Ceedling's own content lives.
#
# Sibling-header isolation and the build step doctor's collision diagnoses both weigh a
# test's reachable headers against these two answers (see HEADER_COLLISIONS.md). The
# class keeps no state, so one instance serves every thread.
class TestSubstitutions

  constructor :configurator

  # `{ basename => real path }` for every real header this test substitutes: each
  # CMock mock of a real header, and each Partialized module's header. A mock Partial's
  # `source` is its generated interface header, not a project header, so it is left out.
  def real_headers(testable)
    return mocked_headers( testable ).merge( partialized_headers( testable ) )
  end

  # Whether `real_path` is a header this test Partializes, rather than mocks
  def partialized?(testable, real_path)
    return partialized_headers( testable ).value?( real_path )
  end

  # Directory roots holding only Ceedling's generated or vendored content for this test.
  # Several files routinely share each one, such as a Partial's types, interface, and
  # implementation headers, so sharing a directory there is no quote-include risk.
  def generated_dirs(testable)
    return [
      testable.paths[:mocks],
      testable.paths[:partials],
      PROJECT_BUILD_VENDOR_UNITY_PATH,
      PROJECT_BUILD_VENDOR_CMOCK_PATH,
      PROJECT_BUILD_VENDOR_CEXCEPTION_PATH,
      @configurator.project_build_vendor_ceedling_path
    ].compact
  end

  ### Private ###

  private

  def mocked_headers(testable)
    sources = (testable.mocks || {}).each_value.reject( &:partial ).filter_map( &:source )
    return by_basename( sources )
  end

  def partialized_headers(testable)
    return by_basename( testable.partials.configs.each_value.filter_map { |config| config.header.filepath } )
  end

  def by_basename(filepaths)
    return filepaths.to_h { |filepath| [File.basename( filepath ), filepath] }
  end
end
