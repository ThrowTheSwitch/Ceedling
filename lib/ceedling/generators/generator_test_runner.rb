# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'generate_test_runner' # Unity's test runner generator
require 'ceedling/parsing_parcels'

class GeneratorTestRunner

  attr_accessor :test_cases

  #
  # This class is not within any DIY context.
  # It is instantiated on demand for each test file processed in a build.
  #

  def initialize(config:, test_file_contents:, preprocessed_file_contents: nil, parsing_parcels:)
    @unity_runner_generator = UnityTestRunnerGenerator.new( config )
    @parsing_parcels = parsing_parcels

    # Reduced information set
    @test_cases = []

    # Full information set used for runner generation
    @test_cases_internal = []

    parse_test_file( test_file_contents, preprocessed_file_contents )
  end

  def generate(module_name:, runner_filepath:, mocks:, includes:)
    # Actually build the test runner using Unity's test runner generator.
    @unity_runner_generator.generate(
      module_name,
      runner_filepath,
      @test_cases_internal,
      # Small hack for mock subdirectory support until include paths fully supported
      mocks.map{ |include| include.filepath },
      includes.map{ |include| include.filename }
    )
  end

  ### Private ###

  private

  def parse_test_file(test_file_contents, preprocessed_file_contents)
    # If there's a preprocessed file, align test case line numbers with original file contents
    if (!preprocessed_file_contents.nil?)
      @test_cases_internal = extract_test_cases( preprocessed_file_contents )

      # Modify line numbers to match the original, non-preprocessed file
      remap_line_numbers!( @test_cases_internal, test_file_contents )

    # Just look for the test cases within the original test file
    else
      @test_cases_internal = extract_test_cases( test_file_contents )
    end

    # Unity's runner generator `find_tests()` produces an array of hashes with the following keys...
    # { test:, args:, call:, params:, line_number: }

    # For external use of test case names and line numbers, keep only those pieces of info
    @test_cases = @test_cases_internal.map {|hash| hash.slice( :test, :line_number )}
  end

  def extract_test_cases(source_contents)
    # Save the test case structure to be used in generation
    test_cases = @unity_runner_generator.find_tests( source_contents )

    # Configure the runner generator around `setUp()` and `tearDown()`
    @unity_runner_generator.find_setup_and_teardown( source_contents )

    return test_cases
  end

  def remap_line_numbers!(test_cases, original_file_contents)
    remaining = test_cases.dup

    # Use `ParsingParcels` to walk the original, non-preprocessed source line by line.
    # This sanitizes encoding oddities (rather than raising mid-match, unpredictably by
    # platform default encoding) and strips comments (rather than false-matching a test
    # name that merely appears inside a comment).
    @parsing_parcels.code_lines_with_num( original_file_contents ) do |line, line_num|
      break if remaining.empty?

      next_case = remaining.first
      if (line =~ /#{next_case[:test]}/)
        next_case[:line_number] = line_num
        remaining.shift
      end
    end
  end

end
