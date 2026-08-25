# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/generators/generator_test_runner'
require 'ceedling/parsing_parcels'
require 'ceedling/includes/includes'

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

      expect( runner.test_cases ).to eq( [ { test: 'test_ShouldDoSomething', symbol: 'test_ShouldDoSomething', line_number: 2 } ] )
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

      expect( runner.test_cases ).to eq( [ { test: 'test_ShouldDoSomething', symbol: 'test_ShouldDoSomething', line_number: 3 } ] )
    end

    it 'expands a parameterized test into one entry per TEST_CASE, carrying the runtime name and wrapper symbol' do
      source = <<~SOURCE
        void setUp(void) {}
        void tearDown(void) {}

        TEST_CASE(101, 1)
        TEST_CASE(-1, 1)
        void test_value_out_of_range_good(int a, int expected) {}
      SOURCE

      runner = described_class.new(
        config: { use_param_tests: true },
        test_file_contents: source,
        parsing_parcels: @parsing_parcels
      )

      expect( runner.test_cases ).to eq(
        [
          { test: 'test_value_out_of_range_good(101, 1)', symbol: 'runner_args1_test_value_out_of_range_good', line_number: 6 },
          { test: 'test_value_out_of_range_good(-1, 1)',   symbol: 'runner_args2_test_value_out_of_range_good', line_number: 6 }
        ]
      )
    end
  end

  # ===========================================================================
  describe '#generate' do
  # ===========================================================================
    # Regression coverage for https://github.com/ThrowTheSwitch/Ceedling/issues/1236:
    # a system #include with a directory component (e.g. <sys/stat.h>) was rendered
    # into the generated runner as a bare, unbracketed basename ("stat.h"), losing
    # both the directory and the user/system distinction, breaking runner compilation.
    #
    # @unity_runner_generator is a real UnityTestRunnerGenerator, constructed directly
    # inside #initialize rather than injected -- swapped out for a double here so these
    # specs assert on exactly what GeneratorTestRunner itself hands off, independent of
    # Unity's own generated file formatting.
    def build_and_capture_includes(includes:, mocks: [])
      runner = build_runner( test_file_contents: "void test_Thing(void) {}\n" )

      captured = nil
      fake_generator = double('unity_runner_generator')
      allow(fake_generator).to receive(:generate) do |*args|
        captured = args[4]
      end
      runner.instance_variable_set(:@unity_runner_generator, fake_generator)

      runner.generate(
        module_name: 'test_thing',
        runner_filepath: '/build/test/runners/test_thing_runner.c',
        mocks: mocks,
        includes: includes
      )

      return captured
    end

    it 'renders a system include with a directory component in angle brackets, directory intact' do
      captured = build_and_capture_includes( includes: [ SystemInclude.new('sys/stat.h') ] )

      expect( captured ).to eq( ['<sys/stat.h>'] )
    end

    it 'prefers a reconciled system include\'s include_path over its resolved filepath' do
      # Mirrors what Includes.reconcile actually produces: filepath is the real,
      # resolved (possibly absolute) location; include_path is the original,
      # as-written directive text that must be what's rendered.
      reconciled = SystemInclude.new('/usr/include/sys/stat.h', include_path: 'sys/stat.h')

      captured = build_and_capture_includes( includes: [ reconciled ] )

      expect( captured ).to eq( ['<sys/stat.h>'] )
    end

    it 'renders a user include with a directory component down to its bare filename, unchanged from prior behavior' do
      # Unlike a system header, a project's own directories are exposed to the
      # compiler as a flat list of -I search paths -- rendering a user include's
      # own directory component here breaks resolution rather than fixing anything,
      # so this behavior is intentionally unchanged by the issue #1236 fix.
      captured = build_and_capture_includes( includes: [ UserInclude.new('sub/header.h') ] )

      expect( captured ).to eq( ['header.h'] )
    end

    it 'renders a mixed list of system and user includes each in their own correct form' do
      captured = build_and_capture_includes(
        includes: [ SystemInclude.new('sys/stat.h'), UserInclude.new('sub/header.h') ]
      )

      expect( captured ).to eq( ['<sys/stat.h>', 'header.h'] )
    end
  end
end
