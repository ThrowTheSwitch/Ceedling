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
  # the harness and the Testable
  def extract(tree, test, defines: [])
    with_source_tree( tree ) do |dir|
      Dir.chdir( dir ) do
        harness  = IntegrationSpecHelpers::TestIncludesHarness.new( directives_only: @directives_only )
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
