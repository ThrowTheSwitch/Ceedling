# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'generate_test_runner' # Unity's test runner generator

class GeneratorTestRunner

  attr_accessor :test_cases

  #
  # This class is not within any DIY context.
  # It is instantiated on demand for each test file processed in a build.
  #

  def initialize(config:, test_file_contents:, preprocessed_file_contents:nil)
    @unity_runner_generator = UnityTestRunnerGenerator.new( config )
    
    # Reduced information set
    @test_cases = []

    # Full information set used for runner generation
    @test_cases_internal = []

    parse_test_file( test_file_contents, preprocessed_file_contents )
  end

  def generate(module_name:, runner_filepath:, mock_list:, test_file_includes:, header_extension:)
    # Actually build the test runner using Unity's test runner generator.
    @unity_runner_generator.generate(
      module_name,
      runner_filepath,
      @test_cases_internal,
      mock_list.map{ |mock| mock + header_extension },
      test_file_includes.map{|f| File.basename(f,'.*') + header_extension}
    )
  end

  ### Private ###

  private

  def parse_test_file(test_file_contents, preprocessed_file_contents)
    # If there's a preprocessed file, align test case line numbers with original file contents
    if (!preprocessed_file_contents.nil?)
      # Save the test case structure to be used in generation
      @test_cases_internal = @unity_runner_generator.find_tests( preprocessed_file_contents )
      
      # Configure the runner generator around `setUp()` and `tearDown()`
      @unity_runner_generator.find_setup_and_teardown( preprocessed_file_contents )

      # Modify line numbers to match the original, non-preprocessed file
      source_lines = test_file_contents.split("\n")
      source_index = 0;
      @test_cases_internal.size.times do |i|
        source_lines[source_index..-1].each_with_index do |line, index|
          if (line =~ /#{@test_cases_internal[i][:test]}/)
            source_index += index
            @test_cases_internal[i][:line_number] = source_index + 1
            break
          end
        end
      end

    # Just look for the test cases within the original test file
    else
      # Save the test case structure to be used in generation
      @test_cases_internal = @unity_runner_generator.find_tests( test_file_contents )

      # Configure the runner generator around `setUp()` and `tearDown()`
      @unity_runner_generator.find_setup_and_teardown( test_file_contents )
    end

    # Unity's `find_tests()` produces an array of hashes with the following keys...
    # { test:, args:, call:, params:, line_number: }

    # For external use of test case names and line numbers, keep only those pieces of info
    @test_cases = @test_cases_internal.map {|hash| hash.slice( :test, :line_number )}
  end

end
