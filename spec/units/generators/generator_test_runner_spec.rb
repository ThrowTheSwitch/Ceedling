# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/generator_test_runner'
require 'ceedling/parsing_parcels'

describe GeneratorTestRunner do
  before(:each) do
    @parsing_parcels = ParsingParcels.new
  end

  def build_runner(test_file_contents:, preprocessed_file_contents: nil)
    described_class.new(
      config: {},
      test_file_contents: test_file_contents,
      preprocessed_file_contents: preprocessed_file_contents,
      parsing_parcels: @parsing_parcels
    )
  end

  describe '#extract_test_cases' do
    it 'finds test cases and configures setUp/tearDown presence' do
      source = <<~SOURCE
        void setUp(void) {}
        void tearDown(void) {}
        void test_ShouldDoSomething(void) {}
        void test_ShouldDoSomethingElse(void) {}
      SOURCE

      runner = build_runner( test_file_contents: source )
      test_cases = runner.send( :extract_test_cases, source )

      expect( test_cases.map { |t| t[:test] } ).to eq( ['test_ShouldDoSomething', 'test_ShouldDoSomethingElse'] )
    end
  end

  describe '#remap_line_numbers!' do
    it 'does not raise on invalid/undefined byte sequences (encoding safety)' do
      # A raw, invalid UTF-8 byte sequence embedded in a comment above the test function.
      # This is the *original*, non-preprocessed source -- the only input `remap_line_numbers!`
      # scans. Real preprocessed content never carries this, since gcc strips comments already.
      invalid_byte_sequence = "// \xFF\xFE garbage bytes in a comment\n".dup.force_encoding('UTF-8')
      source = invalid_byte_sequence + "void test_ShouldDoSomething(void) {}\n"

      runner = build_runner( test_file_contents: "void test_ShouldDoSomething(void) {}\n" )
      test_cases = [ { test: 'test_ShouldDoSomething', line_number: 0 } ]

      expect { runner.send( :remap_line_numbers!, test_cases, source ) }.not_to raise_error
      expect( test_cases.first[:line_number] ).to eq( 2 )
    end

    it 'skips a test name that only appears inside a comment, matching the real definition' do
      source = <<~SOURCE
        // void test_ShouldDoSomething(void) -- old note, not the real definition
        void setUp(void) {}
        void test_ShouldDoSomething(void) {}
      SOURCE

      runner = build_runner( test_file_contents: source, preprocessed_file_contents: source )
      test_cases = [ { test: 'test_ShouldDoSomething', line_number: 0 } ]

      runner.send( :remap_line_numbers!, test_cases, source )

      expect( test_cases.first[:line_number] ).to eq( 3 )
    end

    it 'ignores test names inside multi-line block comments and handles backslash continuations' do
      source = <<~SOURCE
        /* void test_ShouldDoSomething(void)
           multi-line block comment referencing the test name */
        void setUp(void) \\
          {}
        void test_ShouldDoSomething(void) {}
      SOURCE

      runner = build_runner( test_file_contents: source, preprocessed_file_contents: source )
      test_cases = [ { test: 'test_ShouldDoSomething', line_number: 0 } ]

      runner.send( :remap_line_numbers!, test_cases, source )

      expect( test_cases.first[:line_number] ).to eq( 5 )
    end
  end

  describe '#initialize / #test_cases' do
    it 'extracts test cases directly from source when no preprocessed content is given' do
      source = <<~SOURCE
        void setUp(void) {}
        void test_ShouldDoSomething(void) {}
      SOURCE

      runner = build_runner( test_file_contents: source )

      expect( runner.test_cases ).to eq( [ { test: 'test_ShouldDoSomething', line_number: 2 } ] )
    end

    it 'remaps line numbers back to the original file when preprocessed content is given' do
      original = <<~SOURCE
        // A leading comment line shifts everything down by one
        void setUp(void) {}
        void test_ShouldDoSomething(void) {}
      SOURCE

      # Simulated preprocessor output: the leading comment has been stripped.
      preprocessed = <<~SOURCE
        void setUp(void) {}
        void test_ShouldDoSomething(void) {}
      SOURCE

      runner = build_runner( test_file_contents: original, preprocessed_file_contents: preprocessed )

      expect( runner.test_cases ).to eq( [ { test: 'test_ShouldDoSomething', line_number: 3 } ] )
    end
  end
end
