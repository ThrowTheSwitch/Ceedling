# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/module_generator/lib', __dir__ ) )

require 'module_generator_test_file'

describe ModuleGeneratorTestFile do

  def test_file(**overrides)
    return described_class.new(
      **{ module_name: 'widget', header: 'widget.h', includes: [], boilerplate: nil, test_define: 'TEST', test_guard: 'ifdef' }.merge( overrides )
    )
  end

  let(:new_file) do
    <<~C
      #ifdef TEST

      #include "unity.h"

      #include "widget.h"

      void setUp(void)
      {
      }

      void tearDown(void)
      {
      }

      void test_shorty_NeedToImplement(void)
      {
          TEST_IGNORE_MESSAGE("Need to Implement shorty");
      }

      void test_tiny_NeedToImplement(void)
      {
          TEST_IGNORE_MESSAGE("Need to Implement tiny");
      }

      #endif // TEST
    C
  end

  it 'writes a new test file with an ignored test for each function' do
    result = test_file.render( %w[shorty tiny] )

    expect(result.content).to eq( new_file )
    expect(result.added).to eq( %w[shorty tiny] )
  end

  it 'starts with the boilerplate, naming the module, and includes configured headers first' do
    content = test_file( boilerplate: '/* Tests for %1$s */', includes: ['defs.h'] ).render( %w[shorty] ).content

    expect(content).to start_with( "/* Tests for widget */\n#ifdef TEST\n" )
    expect(content).to include( "#include \"unity.h\"\n\n#include \"defs.h\"\n#include \"widget.h\"\n" )
  end

  it 'guards with #if and a configured test define' do
    content = test_file( test_define: 'UNIT_TEST', test_guard: 'if' ).render( %w[shorty] ).content

    expect(content).to start_with( "#if UNIT_TEST\n" )
    expect(content).to end_with( "#endif // UNIT_TEST\n" )
  end

  it 'adds tests only for functions an existing file does not test, ahead of its closing guard' do
    existing = new_file.sub( /\nvoid test_tiny.*?\}\n/m, '' )
    result   = test_file.render( %w[shorty tiny], existing: existing )

    expect(result.added).to eq( %w[tiny] )
    expect(result.content).to eq( new_file )
  end

  it 'counts a test the user named for a function as testing it' do
    existing = "void test_shorty_returns_zero(void)\n{\n}\n"
    result   = test_file.render( %w[shorty tiny], existing: existing )

    expect(result.added).to eq( %w[tiny] )
    expect(result.content).to start_with( existing )
  end

  it 'appends new tests to an existing file with no closing guard' do
    result = test_file.render( %w[tiny], existing: "/* mine */\n" )

    expect(result.content).to eq( "/* mine */\n\nvoid test_tiny_NeedToImplement(void)\n{\n    TEST_IGNORE_MESSAGE(\"Need to Implement tiny\");\n}\n" )
  end

  it 'leaves an existing file unchanged when every function is tested' do
    result = test_file.render( %w[shorty tiny], existing: new_file )

    expect(result.added).to be_empty
    expect(result.content).to eq( new_file )
  end

end
