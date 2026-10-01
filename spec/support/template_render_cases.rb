# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/defaults'

# The report templates and the render inputs behind the golden fixtures in
# spec/support/fixtures/templates/.
#
# Shared so the generator that produced those fixtures and the spec that checks
# against them read from one definition. Two copies would drift, and a drifted
# case would silently stop comparing what it claims to compare.
#
# Cases are chosen to reach every branch across the four templates: empty runs,
# passing runs, failures and ignores with empty, single line, and multi line
# messages, stdout capture, a non-test context that prepends a header, a failure
# message that does not match the gtest-style Expected/Was pattern, and each
# shape of missing coverage data.
module TemplateRenderCases

  ROOT = File.expand_path( '../../..', __FILE__ )

  FIXTURES_PATH = File.join( ROOT, 'spec', 'support', 'fixtures', 'templates' )

  # Name => template string. The ide template is a constant rather than an asset
  # file, which is why it is read differently from the other three.
  #
  # Every template is normalized to line feeds. The fixtures record what ERB
  # produced from the canonical template content, so the comparison has to be about
  # rendering rather than about how a checkout happened to store the templates.
  # Git converts line endings per .gitattributes, Ruby's text mode converts again
  # when reading on Windows, and the ide template arrives from a Ruby source file
  # subject to both. Without this the same rendering logic would be measured
  # against three different inputs depending on platform and git settings.
  #
  # Rendering of carriage returns is not skipped by doing this. It is pinned
  # directly in templateinator_spec.rb, by an example whose template is an inline
  # string and therefore immune to any of the above.
  def self.templates
    return {
      'pretty'    => read_template( 'plugins', 'report_tests_pretty_stdout', 'assets', 'test_results.template' ),
      'gtestlike' => read_template( 'plugins', 'report_tests_gtestlike_stdout', 'assets', 'test_results.template' ),
      'bullseye'  => read_template( 'plugins', 'bullseye', 'assets', 'coverage.template' ),
      'ide'       => normalize_newlines( DEFAULT_TESTS_RESULTS_REPORT_TEMPLATE ),
    }
  end

  # Read as bytes, then labeled UTF-8 rather than left at whatever the platform's
  # default external encoding happens to be. Templates are UTF-8 in the repo, and a
  # template string carrying a different label would fail to concatenate with the
  # compiler's own literals the moment one held a non-ASCII character.
  def self.read_template(*path_parts)
    bytes = File.binread( File.join( ROOT, *path_parts ) )
    return normalize_newlines( bytes.force_encoding( Encoding::UTF_8 ) )
  end

  def self.normalize_newlines(template)
    return template.gsub( "\r\n", "\n" )
  end

  MULTILINE_MESSAGE = "Expected 1 Was 2.\nsecond line\nthird line"

  # Every case carries both :results and :coverage so all four templates can render
  # all of them. The templates each ignore what they do not use.
  def self.cases
    return {
      'empty'                   => build( total: 0 ),

      'all_pass'                => build( passed: 2 ),

      'one_failure_matching'    => build( passed: 1, failures: [ failure( 'Expected 1 Was 2.' ) ] ),

      'one_failure_nonmatching' => build( passed: 1, failures: [ failure( 'Something else entirely' ) ] ),

      'one_failure_multiline'   => build( passed: 1, failures: [ failure( MULTILINE_MESSAGE ) ] ),

      'one_failure_no_message'  => build( passed: 1, failures: [ failure( '' ) ] ),

      'one_ignore_with_message' => build( passed: 1, ignores: [ ignore( 'not ready yet' ) ] ),

      'one_ignore_no_message'   => build( passed: 1, ignores: [ ignore( '' ) ] ),

      'stdout_only'             => build( passed: 1, stdout: [ stdout_entry ] ),

      'mixed_all'               => build(
                                     passed: 2,
                                     failures: [ failure( MULTILINE_MESSAGE ), failure( 'Expected 3 Was 4.', file: 'test/TestBar.c' ) ],
                                     ignores:  [ ignore( 'skipped' ) ],
                                     stdout:   [ stdout_entry ]
                                   ),

      # A non-test context prepends a header to every banner and adds a line of its
      # own in the gtest-style template.
      'gcov_context'            => build(
                                     context: :gcov,
                                     passed: 1,
                                     failures: [ failure( MULTILINE_MESSAGE ) ],
                                     ignores:  [ ignore( 'skipped' ) ],
                                     stdout:   [ stdout_entry ]
                                   ),

      'coverage_functions_only' => build( passed: 1, coverage: { functions: 91, branches: nil } ),

      'coverage_branches_only'  => build( passed: 1, coverage: { functions: nil, branches: 7 } ),

      'coverage_none'           => build( passed: 1, coverage: { functions: nil, branches: nil } ),
    }
  end

  ### Private ###

  def self.failure(message, file: 'test/TestFoo.c')
    return {
      source: { file: file },
      collection: [ { test: 'test_fails', line: 30, message: message } ]
    }
  end

  def self.ignore(message, file: 'test/TestFoo.c')
    return {
      source: { file: file },
      collection: [ { test: 'test_ignored', line: 40, message: message } ]
    }
  end

  def self.stdout_entry(file: 'test/TestFoo.c')
    return {
      source: { file: file },
      collection: [ 'debug line one', 'debug line two' ]
    }
  end

  def self.build(context: TEST_SYM, total: nil, passed: 0, failures: [], ignores: [], stdout: [],
                 coverage: { functions: 91, branches: 72 })
    failed  = failures.sum { |entry| entry[:collection].length }
    ignored = ignores.sum  { |entry| entry[:collection].length }

    successes = passed.zero? ? [] : [ {
      source: { file: 'test/TestFoo.c' },
      collection: (1..passed).map { |i| { test: "test_passes_#{i}", line: i, message: '' } }
    } ]

    return {
      context: context,
      coverage: coverage,
      results: {
        counts: {
          total:   total.nil? ? (passed + failed + ignored) : total,
          passed:  passed,
          failed:  failed,
          ignored: ignored,
          stdout:  stdout.sum { |entry| entry[:collection].length }
        },
        successes: successes,
        failures:  failures,
        ignores:   ignores,
        stdout:    stdout,
        times:     { 'test/TestFoo.c' => 0.0123, 'test/TestBar.c' => 0.5 }
      }
    }
  end

end
