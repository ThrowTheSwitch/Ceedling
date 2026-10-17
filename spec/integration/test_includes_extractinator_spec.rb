# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# A test file's #include extraction, stages 2 through 4, with GCC running for real.
#
# Each example lays a small project on disk, runs the real text scan, search path
# composition, and stage 4 against it, and checks which #includes and mocks the rest
# of the build would use. What a test can include depends on GCC's own evaluation of
# its #if branches and on what the directives-only pass can find on the search path,
# which no unit spec can show. Examples needing directives-only output skip on a
# toolchain without it.

require 'spec_helper'
require 'spec_integration_helper'
require 'test_includes_harness'

describe 'Test file #include extraction (integration)' do
  include_context 'requires gcc'

  before(:all) { @directives_only = directives_only_supported? }

  def needs_directives_only
    skip 'gcc ignores -fdirectives-only, so nothing is reconciled' unless @directives_only
  end

  # Runs stages 2 through 4 for test/<test> in a project laid out from `tree`, and yields
  # the harness and the Testable. `directives_only: false` forces whole-run fallback, which
  # every toolchain can run.
  def extract(tree, test, defines: [], directives_only: @directives_only)
    with_source_tree( tree ) do |dir|
      Dir.chdir( dir ) do
        harness  = IntegrationSpecHelpers::TestIncludesHarness.new( directives_only: directives_only )
        testable = harness.run( "test/#{test}", defines: defines )
        yield harness, testable
      end
    end
  end

  # Issue #1083, Case 1: only the branch that is on can build, and the other branches'
  # headers don't exist
  CASE_1_TREE = {
    'src/Gpt.h'          => "void Gpt_StartTimer(void);\n",
    'test/test_Case_01.c' => <<~C
      #if defined(UNITTEST_HW_DEPENDANT_MOCK_NEEDED)
        #if (TARGET_BOARD_HARDWARE == HW_TYPE_1)
          #include "mock_Gpt_HwType1.h"
        #else
          #include "mock_Gpt_HwType2.h"
        #endif
      #else
        #include "mock_Gpt.h"
      #endif
    C
  }.freeze

  it 'mocks only the branch that is on, when the other branches have no headers' do
    needs_directives_only

    extract( CASE_1_TREE, 'test_Case_01.c' ) do |harness, _testable|
      expect(harness.mocks( 'test/test_Case_01.c' )).to eq( ['mock_Gpt.h'] )
    end
  end

  # A branch can name its mock in letter case its header doesn't have
  CASE_SLIP_TREE = {
    'src/Gpt.h'                  => "void Gpt_StartTimer(void);\n",
    'test/test_Case_01_legacy.c' => "#ifdef LEGACY_NAMES\n#include \"mock_gpt.h\"\n#else\n#include \"mock_Gpt.h\"\n#endif\n"
  }.freeze

  it 'says nothing of a mis-cased mock in a branch that is off' do
    needs_directives_only

    extract( CASE_SLIP_TREE, 'test_Case_01_legacy.c' ) do |harness, _testable|
      expect(harness.mocks( 'test/test_Case_01_legacy.c' )).to eq( ['mock_Gpt.h'] )
    end
  end

  it 'stops on a mis-cased mock in a branch that is on, naming the header it found' do
    needs_directives_only

    expect { extract( CASE_SLIP_TREE, 'test_Case_01_legacy.c', defines: ['LEGACY_NAMES'] ) { nil } }
      .to raise_error( CeedlingException, /different capitalization was found: 'src\/Gpt\.h'/ )
  end

  # GCC's bare list, which evaluated the branch, decides this before any reconciliation
  it 'stops on a mis-cased mock in a branch that is on, in fallback' do
    expect { extract( CASE_SLIP_TREE, 'test_Case_01_legacy.c', defines: ['LEGACY_NAMES'], directives_only: false ) { nil } }
      .to raise_error( CeedlingException, /different capitalization was found: 'src\/Gpt\.h'/ )
  end

  it 'gives a mock that a macro names, with its header in a subdirectory, a search path' do
    needs_directives_only
    tree = {
      'src/drivers/widget.h' => "int widget_read(void);\n",
      'test/test_reader.c'   => "#define WIDGET_MOCK \"mock_widget.h\"\n#include WIDGET_MOCK\n"
    }

    extract( tree, 'test_reader.c' ) do |harness, testable|
      expect(harness.mocks( 'test/test_reader.c' )).to eq( ['mock_widget.h'] )
      expect(testable.mock_search_paths).to eq( ['build/mocks/test_reader/drivers'] )
    end
  end

  # Issue #1083, Case 2: the test picks its second mock with a macro its first mock's
  # header defines
  CASE_2_TREE = {
    'src/MyModuleConfig.h' => <<~C,
      #ifndef MY_MODULE_CONFIG_H
      #define MY_MODULE_CONFIG_H
      #define MODULE_1_ENABLED
      int Module0_FunctionToCall(void);
      #ifdef MODULE_1_ENABLED
      #include "MyModulePart1.h"
      #endif
      #endif
    C
    'src/MyModulePart1.h' => "int Module1_FunctionToCall(void);\n",
    'src/MyModulePart2.h' => "int Module2_FunctionToCall(void);\n",
    'test/test_Case_02.c' => <<~C
      #include "mock_MyModuleConfig.h"
      #ifdef MODULE_1_ENABLED
      #include "mock_MyModulePart1.h"
      #endif
      #ifdef MODULE_2_ENABLED
      #include "mock_MyModulePart2.h"
      #endif
    C
  }.freeze

  describe 'a mock chosen by a macro from a header' do
    it 'is kept when the macro arrives through another mock' do
      needs_directives_only

      extract( CASE_2_TREE, 'test_Case_02.c' ) do |harness, _testable|
        expect(harness.mocks( 'test/test_Case_02.c' )).to eq( ['mock_MyModuleConfig.h', 'mock_MyModulePart1.h'] )
      end
    end

    it 'is kept when the test includes the real header itself' do
      needs_directives_only
      tree = CASE_2_TREE.merge( 'test/test_Case_02.c' => "#include \"MyModuleConfig.h\"\n" + CASE_2_TREE['test/test_Case_02.c'] )

      extract( tree, 'test_Case_02.c' ) do |harness, _testable|
        expect(harness.mocks( 'test/test_Case_02.c' )).to eq( ['mock_MyModuleConfig.h', 'mock_MyModulePart1.h'] )
      end
    end

    # Issue #1083's Case 1 and Case 2 together: a branch that is off names a mock whose
    # header doesn't exist
    it 'is kept while a mock in a branch that is off, without a header, is dropped' do
      needs_directives_only
      tree = CASE_2_TREE.reject { |path, _| path == 'src/MyModulePart2.h' }

      extract( tree, 'test_Case_02.c' ) do |harness, _testable|
        expect(harness.mocks( 'test/test_Case_02.c' )).to eq( ['mock_MyModuleConfig.h', 'mock_MyModulePart1.h'] )
      end
    end
  end

  # A computed #include of a mock can't be resolved this way: no stand-in exists for it
  # before the directives-only pass, so that pass fails on it
  it 'keeps a real header that a macro from another header names' do
    needs_directives_only
    tree = {
      'src/config.h'     => "#define BOARD_HEADER \"board.h\"\n",
      'src/board.h'      => "int board_id(void);\n",
      'test/test_board.c' => "#include \"config.h\"\n#include BOARD_HEADER\n"
    }

    extract( tree, 'test_board.c' ) do |harness, _testable|
      expect(harness.includes( 'test/test_board.c' )).to eq( ['config.h', 'board.h'] )
    end
  end

  # The candidates include scanned mocks the preprocessor then discards; their
  # directories serve the directives-only pass and are dropped once it has decided
  it 'narrows mock search paths to the mocks the build uses' do
    needs_directives_only
    tree = CASE_1_TREE.merge( 'src/hw/Gpt_HwType1.h' => "void Gpt_StartTimer(void);\n" )

    extract( tree, 'test_Case_01.c' ) do |_harness, testable|
      expect(testable.mock_search_paths).to eq( ['build/mocks/test_Case_01'] )
      expect(testable.search_paths).to_not include( 'build/mocks/test_Case_01/hw' )
    end
  end

  describe 'a mock\'s stand-in' do
    let(:standin) { 'build/mocks/test_Case_01/mock_Gpt.h' }

    def place_before_run(contents)
      tree = CASE_1_TREE.merge( standin => contents )
      extract( tree, 'test_Case_01.c' ) { |_harness, _testable| yield File.read( standin ) }
    end

    it 'includes its real header, as the generated mock will' do
      extract( CASE_1_TREE, 'test_Case_01.c' ) do |_harness, _testable|
        expect(File.read( standin )).to eq( "#{StandinHeaderinator::MARKER}\n#include \"Gpt.h\"\n" )
      end
    end

    it 'is placed in fallback too' do
      extract( CASE_1_TREE, 'test_Case_01.c', directives_only: false ) do |_harness, _testable|
        expect(File.read( standin )).to eq( "#{StandinHeaderinator::MARKER}\n#include \"Gpt.h\"\n" )
      end
    end

    it 'replaces a blank stand-in an earlier version left' do
      place_before_run( "// Ceedling intentionally blank file\n\n" ) do |contents|
        expect(contents).to include( '#include "Gpt.h"' )
      end
    end

    it 'leaves a real mock alone' do
      place_before_run( "/* AUTOGENERATED FILE. DO NOT EDIT. */\n" ) do |contents|
        expect(contents).to eq( "/* AUTOGENERATED FILE. DO NOT EDIT. */\n" )
      end
    end
  end

  # When the directives-only pass fails for a file, its scanned #includes are checked
  # against GCC's bare list, which still evaluated the #if branches
  it 'still drops mocks in branches that are off when the directives-only pass fails' do
    needs_directives_only
    tree = CASE_1_TREE.merge(
      'src/stop.h'          => "#error stops the directives-only pass\n",
      'test/test_Case_01.c' => "#include \"stop.h\"\n" + CASE_1_TREE['test/test_Case_01.c']
    )

    extract( tree, 'test_Case_01.c' ) do |harness, testable|
      expect(testable.preprocess[:directives_only][:filepath]).to be_nil
      expect(harness.mocks( 'test/test_Case_01.c' )).to eq( ['mock_Gpt.h'] )
    end
  end
end
