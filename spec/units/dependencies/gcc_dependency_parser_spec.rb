# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/dependencies/gcc_dependency_parser'

describe GccDependencyParser do

  subject(:parser) { described_class.new }

  it 'returns an empty Hash for nil content' do
    expect( parser.parse( nil ) ).to eq( {} )
  end

  it 'returns an empty Hash for blank content' do
    expect( parser.parse( "   \n  \n" ) ).to eq( {} )
  end

  it 'parses a single-line target with several dependencies' do
    content = "foo.o: foo.c foo.h bar.h\n"

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c', 'foo.h', 'bar.h']
    )
  end

  it 'parses a target with no dependencies (bare colon, e.g. an -MP phony rule)' do
    content = "bar.h:\n"

    expect( parser.parse( content ) ).to eq( 'bar.h' => [] )
  end

  it 'joins backslash-newline line continuations into one logical line' do
    content = <<~DEPFILE
      foo.o: foo.c \\
        foo.h \\
        bar.h
    DEPFILE

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c', 'foo.h', 'bar.h']
    )
  end

  it 'handles Windows CRLF line continuations' do
    content = "foo.o: foo.c \\\r\n  foo.h\r\n"

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c', 'foo.h']
    )
  end

  it 'parses multiple targets, including -MP-style phony targets, from one blob' do
    content = <<~DEPFILE
      foo.o: foo.c foo.h bar.h

      foo.h:

      bar.h:
    DEPFILE

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c', 'foo.h', 'bar.h'],
      'foo.h' => [],
      'bar.h' => []
    )
  end

  it 'applies one prerequisite list to multiple targets sharing a single logical line' do
    content = "a.o b.o: common.h\n"

    expect( parser.parse( content ) ).to eq(
      'a.o' => ['common.h'],
      'b.o' => ['common.h']
    )
  end

  it 'unescapes escaped spaces within a single path token' do
    content = "foo.o: path\\ with\\ spaces.h\n"

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['path with spaces.h']
    )
  end

  it 'does not mistake a Windows drive-letter colon for the target separator' do
    content = "foo.o: C:\\proj\\foo.c C:\\proj\\foo.h\n"

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['C:\\proj\\foo.c', 'C:\\proj\\foo.h']
    )
  end

  it 'handles a Windows target path itself containing a drive letter' do
    content = "C:\\build\\foo.o: C:\\proj\\foo.c\n"

    expect( parser.parse( content ) ).to eq(
      'C:\\build\\foo.o' => ['C:\\proj\\foo.c']
    )
  end

  it 'deduplicates repeated dependencies for the same target' do
    content = "foo.o: foo.c foo.h foo.h foo.c\n"

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c', 'foo.h']
    )
  end

  it 'merges dependencies for the same target appearing on separate logical lines' do
    content = <<~DEPFILE
      foo.o: foo.c
      foo.o: foo.h
    DEPFILE

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c', 'foo.h']
    )
  end

  it 'ignores lines with no recognizable target/prerequisite separator' do
    content = "this is not a dependency line\nfoo.o: foo.c\n"

    expect( parser.parse( content ) ).to eq(
      'foo.o' => ['foo.c']
    )
  end

  it 'parses real-world multi-target gcc -MMD -MP style output' do
    content = <<~DEPFILE
      build/test/out/test_foo.o: \\
       test/test_foo.c \\
       src/foo.h \\
       vendor/unity/src/unity.h

      src/foo.h:

      vendor/unity/src/unity.h:
    DEPFILE

    expect( parser.parse( content ) ).to eq(
      'build/test/out/test_foo.o' => ['test/test_foo.c', 'src/foo.h', 'vendor/unity/src/unity.h'],
      'src/foo.h' => [],
      'vendor/unity/src/unity.h' => []
    )
  end

end
