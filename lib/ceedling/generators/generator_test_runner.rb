# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'generate_test_runner' # Unity's test runner generator
require 'ceedling/parsing_parcels'
require 'ceedling/includes/includes'

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
      # Unity's own generator emits a string verbatim if it contains '<' and otherwise
      # wraps it in double quotes -- each entry here must therefore already be in its
      # final, exact form.
      #
      # System includes only: use the full, bracketed spelling (include_path, a
      # reconciled SystemInclude's original as-written directive text -- e.g.
      # "sys/stat.h" -- when set, else the directory-preserving filepath). A bare
      # filename here drops both the directory component and the '<>' delimiters a
      # system header's own search path depends on (issue #1236).
      #
      # User includes: bare filename, same as always. Unlike mocks (whose subdirectory
      # is a real, dedicated build/test/mocks/<test>/ path -- hence their own
      # directory-preserving filepath usage above) or a system header (whose directory
      # is meaningful to the system include search path), a project's own directories
      # are exposed to the compiler as a flat list of -I search paths, not nested to
      # match whatever directory component a captured UserInclude's filepath happens to
      # carry -- rendering the full path here breaks resolution instead of fixing it.
      includes.map do |include|
        if include.is_a?(SystemInclude)
          "<#{include.include_path || include.filepath}>"
        else
          include.filename
        end
      end
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

    # For external use, reduce down to test name, runtime C symbol, and line number.
    # A parameterized test (`:args` populated) is expanded into one entry per TEST_CASE /
    # TEST_RANGE / TEST_MATRIX row, since Unity's generated runner registers each invocation
    # under its own name (matching `generate_test_runner.rb`'s `"#{test}(#{args})"` naming) and
    # runs it through its own wrapper function (`runner_args<N>_<test>`). Collapsing these to a
    # single bare-name entry breaks exact-match test case isolation (crash handling) for
    # parameterized tests.
    @test_cases = @test_cases_internal.flat_map do |hash|
      if hash[:args].nil? || hash[:args].empty?
        [ { test: hash[:test], symbol: hash[:test], line_number: hash[:line_number] } ]
      else
        hash[:args].each_with_index.map do |args, idx|
          {
            test:        "#{hash[:test]}(#{args})",
            symbol:      "runner_args#{idx + 1}_#{hash[:test]}",
            line_number: hash[:line_number]
          }
        end
      end
    end
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
