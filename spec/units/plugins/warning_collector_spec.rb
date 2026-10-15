# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/report_build_warnings_log/lib', __dir__ ) )

require 'warning_collector'

describe WarningCollector do

  # Clang, as Apple's toolchain prints a header warning and a local one
  CLANG = <<~OUT
    a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]
    int a( void ) { int spare; return 0; }
                        ^
    In file included from a.c:1:
    ./shared.h:1:12: warning: unused function 'unused_helper' [-Wunused-function]
    static int unused_helper( void ) { return 1; }
               ^
    2 warnings generated.
  OUT

  # GCC, with its function context, numbered source lines, and a note
  GCC = <<~OUT
    a.c: In function 'a':
    a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]
        2 | int a( void ) { int spare; return 0; }
          |                     ^~~~~
    a.c:9:3: warning: 'x' may be used uninitialized [-Wmaybe-uninitialized]
        9 |   return x;
          |   ^~~~~~
    a.c:8:7: note: 'x' was declared here
        8 |   int x;
          |       ^
  OUT

  let(:collector) { described_class.new }

  it 'keeps each warning with the context lines that belong to it' do
    expect(collector.warnings( CLANG )).to eq( [
      "a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]\nint a( void ) { int spare; return 0; }\n                    ^\n",
      "In file included from a.c:1:\n./shared.h:1:12: warning: unused function 'unused_helper' [-Wunused-function]\nstatic int unused_helper( void ) { return 1; }\n           ^\n"
    ] )
  end

  it 'keeps a function context line and a following note with their warning' do
    warnings = collector.warnings( GCC )

    expect(warnings.size).to eq( 2 )
    expect(warnings.first).to start_with( "a.c: In function 'a':\na.c:2:21: warning: unused variable" )
    expect(warnings.last).to include( "note: 'x' was declared here", '   |       ^' )
  end

  it 'leaves out a compiler summary line that only counts warnings' do
    expect(collector.warnings( "1 warning generated.\n3 warnings and 1 error generated.\n" )).to be_empty
  end

  it 'leaves out errors, keeping a warning that follows one' do
    output = "a.c:1:1: error: unknown type name 'foo'\nfoo x;\n^\na.c:2:5: warning: unused variable 'y'\nint y;\n    ^\n"

    expect(collector.warnings( output )).to eq( ["a.c:2:5: warning: unused variable 'y'\nint y;\n    ^\n"] )
  end

  it 'takes single lines from output in other formats' do
    output = "ld: warning: object file was built for a newer OS\n\"main.c\",3  Warning[Pe177]: variable \"x\" was declared but never referenced\nLinking...\n"

    expect(collector.warnings( output )).to eq( [
      "ld: warning: object file was built for a newer OS\n",
      "\"main.c\",3  Warning[Pe177]: variable \"x\" was declared but never referenced\n"
    ] )
  end

  it 'finds nothing in output without warnings' do
    expect(collector.warnings( "Compiling a.c...\n" )).to be_empty
  end

  it 'gives a warning the same identity whichever file included its header' do
    via_b = CLANG.sub( 'In file included from a.c:1:', 'In file included from b.c:1:' )
    header_warning = ->( output ) { collector.warnings( output ).last }

    expect(collector.identity( header_warning.call( via_b ) )).to eq( collector.identity( header_warning.call( CLANG ) ) )
    expect(collector.identity( header_warning.call( CLANG ) )).not_to include( 'In file included from' )
  end

  describe 'configured matching' do
    it 'collects what custom patterns match instead of warnings' do
      remarks = described_class.new( patterns: [/: remark:/] )
      output  = "a.c:3:1: remark: loop not vectorized\na.c:4:1: warning: unused variable 'z'\n"

      expect(remarks.warnings( output )).to eq( ["a.c:3:1: remark: loop not vectorized\n"] )
    end

    it 'drops warnings any exclude matches, anywhere in their text' do
      excluding = described_class.new( excludes: [/unused_helper/, %r{third_party/}] )
      output    = CLANG + "In file included from b.c:1:\nthird_party/lib.h:9:1: warning: deprecated\n"

      expect(excluding.warnings( output ).map( &:lines ).map( &:first )).to eq( ["a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]\n"] )
    end
  end

end
