# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/report_build_warnings_log/lib', __dir__ ) )

require 'ceedling/exceptions'
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
    expect(collector.warnings( CLANG ).map( &:text )).to eq( [
      "a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]\nint a( void ) { int spare; return 0; }\n                    ^\n",
      "In file included from a.c:1:\n./shared.h:1:12: warning: unused function 'unused_helper' [-Wunused-function]\nstatic int unused_helper( void ) { return 1; }\n           ^\n"
    ] )
  end

  it 'keeps a function context line and a following note with their warning' do
    warnings = collector.warnings( GCC ).map( &:text )

    expect(warnings.size).to eq( 2 )
    expect(warnings.first).to start_with( "a.c: In function 'a':\na.c:2:21: warning: unused variable" )
    expect(warnings.last).to include( "note: 'x' was declared here", '   |       ^' )
  end

  it 'leaves out a compiler summary line that only counts warnings' do
    expect(collector.warnings( "1 warning generated.\n3 warnings and 1 error generated.\n" )).to be_empty
  end

  it 'leaves out errors, keeping a warning that follows one' do
    output = "a.c:1:1: error: unknown type name 'foo'\nfoo x;\n^\na.c:2:5: warning: unused variable 'y'\nint y;\n    ^\n"

    expect(collector.warnings( output ).map( &:text )).to eq( ["a.c:2:5: warning: unused variable 'y'\nint y;\n    ^\n"] )
  end

  it 'takes single lines from output in other formats' do
    output = "ld: warning: object file was built for a newer OS\n\"main.c\",3  Warning[Pe177]: variable \"x\" was declared but never referenced\nLinking...\n"

    expect(collector.warnings( output ).map( &:text )).to eq( [
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

  describe 'warning records' do
    it 'parses a GCC diagnostic into its location, severity, message, flag, and context' do
      warning = collector.warnings( GCC ).first

      expect(warning.to_h).to eq(
        file: 'a.c', line: 2, column: 21, severity: 'warning', message: "unused variable 'spare'",
        flag: '-Wunused-variable', context: ["a.c: In function 'a':"],
        text: "a.c: In function 'a':\na.c:2:21: warning: unused variable 'spare' [-Wunused-variable]\n" \
              "    2 | int a( void ) { int spare; return 0; }\n      |                     ^~~~~\n"
      )
    end

    it 'keeps every context line before a header warning' do
      expect(collector.warnings( CLANG ).last.context).to eq( ['In file included from a.c:1:'] )
    end

    it 'reads a Windows path with its drive letter and a diagnostic with no column or flag' do
      warning = collector.warnings( "C:\\proj\\src\\a.c:7: warning: implicit declaration\n" ).first

      expect([warning.file, warning.line, warning.column, warning.flag, warning.message])
        .to eq( ['C:\\proj\\src\\a.c', 7, nil, nil, 'implicit declaration'] )
    end

    it 'takes as its flag only a bracketed option, leaving older GCC notes in the message' do
      warning = collector.warnings( "a.c:3:1: warning: 'f' declared but never defined [enabled by default]\n" ).first

      expect([warning.flag, warning.message]).to eq( [nil, "'f' declared but never defined [enabled by default]"] )
    end

    it 'gives output in another format only its text and message' do
      warning = collector.warnings( "ld: warning: object file was built for a newer OS\n" ).first

      expect(warning.to_h).to eq(
        file: nil, line: nil, column: nil, severity: nil, message: 'ld: warning: object file was built for a newer OS',
        flag: nil, context: [], text: "ld: warning: object file was built for a newer OS\n"
      )
    end
  end

  describe '.compile' do
    it 'makes regular expressions of configured strings' do
      expect(described_class.compile( [': remark:', '(?i)WARN'], setting: ':patterns' )).to eq( [/: remark:/, /(?i)WARN/] )
    end

    it 'refuses an invalid expression, naming its setting and itself' do
      expect { described_class.compile( ['ok', 'bad('], setting: ':report_build_warnings_log ↳ :excludes' ) }
        .to raise_error( CeedlingException, /:excludes.*`bad\(`/ )
    end

    it 'refuses an entry that is not a string' do
      expect { described_class.compile( [42], setting: ':patterns' ) }.to raise_error( CeedlingException, /`42`/ )
    end
  end

  # GCC 14 reports a header's warning after a function's warning with an `At top level`
  # line it leaves out when nothing came before
  it 'gives a warning the same identity whatever scope line GCC puts before it' do
    after_function = <<~OUT
      a.c: In function ‘a’:
      a.c:2:21: warning: unused variable ‘spare’ [-Wunused-variable]
          2 | int a( void ) { int spare; return 0; }
            |                     ^~~~~
      In file included from a.c:1:
      shared.h: At top level:
      shared.h:1:12: warning: ‘unused_helper’ defined but not used [-Wunused-function]
          1 | static int unused_helper( void ) { return 1; }
            |            ^~~~~~~~~~~~~
    OUT
    alone = <<~OUT
      In file included from b.c:1:
      shared.h:1:12: warning: ‘unused_helper’ defined but not used [-Wunused-function]
          1 | static int unused_helper( void ) { return 1; }
            |            ^~~~~~~~~~~~~
    OUT

    expect(collector.identity( collector.warnings( after_function ).last )).to eq( collector.identity( collector.warnings( alone ).last ) )
  end

  describe 'configured matching' do
    it 'collects what custom patterns match instead of warnings' do
      remarks = described_class.new( patterns: [/: remark:/] )
      output  = "a.c:3:1: remark: loop not vectorized\na.c:4:1: warning: unused variable 'z'\n"

      expect(remarks.warnings( output ).map( &:text )).to eq( ["a.c:3:1: remark: loop not vectorized\n"] )
    end

    it 'drops warnings any exclude matches, anywhere in their text' do
      excluding = described_class.new( excludes: [/unused_helper/, %r{third_party/}] )
      output    = CLANG + "In file included from b.c:1:\nthird_party/lib.h:9:1: warning: deprecated\n"

      expect(excluding.warnings( output ).map( &:text ).map( &:lines ).map( &:first )).to eq( ["a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]\n"] )
    end
  end

end
