# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/rake_app/test_task_name'

# Every per-file test task (test:, gen:mocks:, gcov:, valgrind:, sanitize:, bullseye:) turns
# its task name into the test name file lookup needs. A directory ahead of the name
# distinguishes same-named tests, so only the basename is prefixed (GH #1362).
describe TestTaskName do
  def name(task, root: 'gcov:')
    TestTaskName.test_name( task, root: root, extensions: ['.c', '.cpp'], prefix: 'test_' )
  end

  it 'prefixes a bare name' do
    expect( name( 'gcov:calculator.c' ) ).to eq( 'test_calculator' )
  end

  it 'leaves a name that already has the prefix' do
    expect( name( 'gcov:test_calculator.c' ) ).to eq( 'test_calculator' )
  end

  it 'keeps a directory, prefixing only the file name' do
    expect( name( 'gcov:test/calculator.c' ) ).to eq( 'test/test_calculator' )
    expect( name( 'gcov:test/test_calculator.c' ) ).to eq( 'test/test_calculator' )
    expect( name( 'gcov:test/unit/test_calculator.c' ) ).to eq( 'test/unit/test_calculator' )
  end

  it 'normalizes backslashes in a directory' do
    expect( name( 'gcov:test\\unit\\calculator.c' ) ).to eq( 'test/unit/test_calculator' )
  end

  it 'strips any configured source extension, and leaves a name without one' do
    expect( name( 'gcov:calculator.cpp' ) ).to eq( 'test_calculator' )
    expect( name( 'gcov:calculator' ) ).to eq( 'test_calculator' )
  end

  it 'strips the given task root, whatever the task' do
    expect( name( 'valgrind:test/calculator.c', root: 'valgrind:' ) ).to eq( 'test/test_calculator' )
    expect( name( 'gen:mocks:test/calculator.c', root: 'gen:mocks:' ) ).to eq( 'test/test_calculator' )
    expect( name( '  test:calculator.c  ', root: 'test:' ) ).to eq( 'test_calculator' )
  end
end
