# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'

$: << File.expand_path('../../../../plugins/report_tests_ide_stdout/lib', __FILE__)
require 'ide_report_lines'

# The patterns IDEs match build output against, as each publishes them
module IdeParsers
  # Eclipse CDT's GCC error parser, in its evaluation order. Each line goes to the first
  # pattern matching the whole line.
  CDT_PATTERNS = {
    ReportedOnlyOnce:             [ :ignore,  /(.*?):(\d+):(\d+:)? .*\(Each undeclared identifier is reported only once.*/ ],
    ForEachFunctionItAppearsIn:   [ :ignore,  /(.*?):(\d+):(\d+:)? .*for each function it appears in.\).*/ ],
    ReportedOnlyOncePerInputFile: [ :ignore,  /(.*?):(\d+):(\d+:)? .*this will be reported only once per input file.*/ ],
    ErrorUndeclared:              [ :error,   /(.*?):(\d+):(\d+:)? [Ee]rror: ([`'"](.*)['"] undeclared .*)/ ],
    ErrorConflictingTypesFor:     [ :error,   /(.*?):(\d+):(\d+:)? [Ee]rror: (conflicting types for .*[`'"](.*)['"].*)/ ],
    ParseErrorBefore:             [ :error,   /(.*?):(\d+):(\d+:)? (parse error before.*[`'"](.*)['"].*)/ ],
    DefinedButNotUsed:            [ :warning, /(.*?):(\d+):(\d+:)? [Ww]arning: ([`'"](.*)['"] defined but not used.*)/ ],
    WarningConflictingTypesFor:   [ :warning, /(.*?):(\d+):(\d+:)? [Ww]arning: (conflicting types for .*[`'"](.*)['"].*)/ ],
    WarningDangerousFunction:     [ :warning, /(.*?):(\d+):(\d+:)? ([Ww]arning:)?\s*(the use of [`'"](.*)['"] is dangerous, better use [`'"](.*)['"].*)/ ],
    InstantiatedFromHere:         [ :info,    /(.*?):(\d+):(\d+:)?\s*(.*((instantiated)|(required)) from .*)/ ],
    SkippingInstantiationContexts: [ :info,   /(.*?):(\d+):(\d+:)?\s*(\[\s*skipping \d+ instantiation context.*)/ ],
    InConstexprExpansion:         [ :info,    /(.*?):(\d+):(\d+:)?\s*(in 'constexpr' expansion of.*)/ ],
    GenericError:                 [ :error,   /(.*?):(\d+):(\d+:)?\s*(([Ee]rror)|(ERROR)): (.*)/ ],
    InvocationError:              [ :error,   /(.*?): (([Ee]rror)|(ERROR)): (.*)/ ],
    GenericWarning:               [ :warning, /(.*?):(\d+):(\d+:)?\s*(([Ww]arning)|(WARNING)): (.*)/ ],
    GenericInfo:                  [ :info,    /(.*?):(\d+):(\d+:)?\s*(([Nn]ote)|(NOTE)|([Ii]nfo)|(INFO)|(remark)): (.*)/ ],
    OtherError:                   [ :error,   /(.*?):(\d+):(\d+:)? (.*)/ ]
  }.freeze

  # Java's matches() takes the whole line
  def self.cdt(line)
    CDT_PATTERNS.each do |name, (severity, pattern)|
      match = /\A(?:#{pattern})\z/.match( line )
      return { name: name, severity: severity, file: match[1], line: match[2] } if match
    end
    return nil
  end

  # The $gcc problem matcher from VS Code's C/C++ extension
  VSCODE_GCC = /^(.*?):(\d+):(\d*):?\s+(?:fatal\s+)?(warning|error):\s+(.*)$/

  # The Ceedling for VS Code extension's gcc preset, in its order
  CEEDLING_EXTENSION_GCC = {
    warning: /^(.*):(\d+):(\d+):\s+warning:\s+(.*)$/,
    error:   /^(.*):(\d+):(\d+):\s+error:\s+(.*)$/,
    other:   /^(.*):(\d+):(?:\([^)]*\):)?\s+(?!(warning:|error:|note:))(.*)$/
  }.freeze

  # CLion's output filter $FILE_PATH$:$LINE$:$COLUMN$.*, where a file path must be absolute
  CLION_FILTER = %r{\A((?:[A-Za-z]:)?[/\\][^:]*):(\d+):(\d+).*\z}
end

describe IdeReportLines do
  def lines(config, outcome: :failed, file: 'test/TestFoo.c', message: "Expected 1 Was 2")
    return described_class.load( config ).lines( file, { test: 'test_c', line: 30, message: message }, outcome )
  end

  describe 'gcc lines' do
    let(:gcc) { { format: :gcc } }

    it 'locates a failure as an error, column 1, naming the test before its message' do
      expect(lines( gcc )).to eq( "test/TestFoo.c:30:1: error: test_c: Expected 1 Was 2\n" )
    end

    it 'locates an ignored test as a warning' do
      expect(lines( gcc, outcome: :ignored, message: 'not ready' )).to eq( "test/TestFoo.c:30:1: warning: test_c: not ready\n" )
    end

    it 'names only the test when there is no message' do
      expect(lines( gcc, message: '' )).to eq( "test/TestFoo.c:30:1: error: test_c\n" )
    end

    # One problem per test in an IDE, with the whole message still in the console
    it 'indents the continuation lines of a multi-line message' do
      expect(lines( gcc, message: "Expected 1\nWas 2\n" )).to eq( "test/TestFoo.c:30:1: error: test_c: Expected 1\n    Was 2\n" )
    end

    it 'expands the path against the working directory when paths are absolute' do
      expect(lines( gcc.merge( absolute_paths: true ) )).to eq( "#{File.expand_path( 'test/TestFoo.c' )}:30:1: error: test_c: Expected 1 Was 2\n" )
    end
  end

  describe 'legacy lines' do
    let(:legacy) { { format: :legacy } }

    it 'repeats the file, line, and test before every line of a quoted message' do
      expect(lines( legacy, message: "Expected 1\nWas 2" )).to eq( %(test/TestFoo.c:30:test_c: "Expected 1\ntest/TestFoo.c:30:test_c: Was 2"\n) )
    end

    it 'names only the test when there is no message' do
      expect(lines( legacy, message: '' )).to eq( "test/TestFoo.c:30:test_c\n" )
    end

    it 'expands the path when paths are absolute' do
      expect(lines( legacy.merge( absolute_paths: true ) )).to start_with( "#{File.expand_path( 'test/TestFoo.c' )}:30:test_c: " )
    end
  end

  describe 'configuration' do
    let(:relative) { "test/TestFoo.c:30:1: error: test_c: Expected 1 Was 2\n" }
    let(:absolute) { "#{File.expand_path( 'test/TestFoo.c' )}:30:1: error: test_c: Expected 1 Was 2\n" }

    # Each named IDE is a gcc configuration with the path form that IDE reads
    it 'expands :vscode and :eclipse to gcc lines with relative paths' do
      expect(lines( { format: :vscode } )).to eq( relative )
      expect(lines( { format: :eclipse } )).to eq( relative )
    end

    it 'expands :clion to gcc lines with absolute paths' do
      expect(lines( { format: :clion } )).to eq( absolute )
    end

    it 'lets :absolute_paths override a named IDE that reads either path form' do
      expect(lines( { format: :eclipse, absolute_paths: true } )).to eq( absolute )
      expect(lines( { format: :clion, absolute_paths: true } )).to eq( absolute )
      expect(lines( { format: :vscode, absolute_paths: true } )).to eq( absolute )
    end

    # CLion's output filters find only absolute paths
    it 'rejects relative paths for :clion' do
      expect { lines( { format: :clion, absolute_paths: false } ) }.to raise_error(
        CeedlingException, /:report_tests_ide_stdout ↳ :absolute_paths cannot be FALSE with :format :clion/
      )
    end

    it 'reads a format as a symbol or string in any letter case' do
      expect(lines( { format: 'GCC' } )).to eq( relative )
      expect(lines( { format: :CLion } )).to eq( absolute )
    end

    it 'rejects an unknown format, listing the choices' do
      expect { lines( { format: 'msvc' } ) }.to raise_error(
        CeedlingException, /:report_tests_ide_stdout ↳ :format `msvc` is not a format. Choose from :gcc, :legacy, :vscode, :eclipse, :clion./
      )
    end

    it 'rejects a format that is not a symbol or string' do
      expect { lines( { format: nil } ) }.to raise_error( CeedlingException, /:report_tests_ide_stdout ↳ :format/ )
    end

    # A quoted 'true' would otherwise read as a setting it is not
    it 'rejects an :absolute_paths that is not a boolean' do
      expect { lines( { format: :gcc, absolute_paths: 'true' } ) }.to raise_error(
        CeedlingException, /:report_tests_ide_stdout ↳ :absolute_paths must be TRUE or FALSE/
      )
    end
  end

  # Every generated line is one problem, located at the test. A continuation line holds
  # message text, which a parser reads as a problem only if that text looks like one.
  describe 'IDE parsers' do
    def extension(line)
      IdeParsers::CEEDLING_EXTENSION_GCC.each do |severity, pattern|
        match = pattern.match( line )
        return { severity: severity, file: match[1], line: match[2], message: match[4] } if match
      end
      return nil
    end

    # A sanitizer's stack frame names a file and line too
    let(:message) { "Expected 1 Was 2\n#0 0x4011 in main test/TestFoo.c:12:5" }

    def problem(outcome, config = { format: :gcc }, file: 'test/TestFoo.c')
      return lines( config, outcome: outcome, file: file, message: message ).lines( chomp: true )
    end

    it "gives Eclipse CDT a failure as a GenericError and an ignored test as a GenericWarning" do
      expect(IdeParsers.cdt( problem( :failed ).first )).to eq( name: :GenericError, severity: :error, file: 'test/TestFoo.c', line: '30' )
      expect(IdeParsers.cdt( problem( :ignored ).first )).to eq( name: :GenericWarning, severity: :warning, file: 'test/TestFoo.c', line: '30' )
    end

    it "gives VS Code's $gcc matcher the file, line, severity, and message" do
      match = IdeParsers::VSCODE_GCC.match( problem( :failed ).first )

      expect(match.captures).to eq( [ 'test/TestFoo.c', '30', '1', 'error', 'test_c: Expected 1 Was 2' ] )
      expect(IdeParsers::VSCODE_GCC.match( problem( :ignored ).first )[4]).to eq( 'warning' )
    end

    it "gives the Ceedling for VS Code extension's gcc preset an error and a warning" do
      expect(extension( problem( :failed ).first )).to eq( severity: :error, file: 'test/TestFoo.c', line: '30', message: 'test_c: Expected 1 Was 2' )
      expect(extension( problem( :ignored ).first )[:severity]).to eq( :warning )
    end

    it "gives CLion's output filter the absolute path, line, and column for :clion" do
      match = IdeParsers::CLION_FILTER.match( problem( :failed, { format: :clion } ).first )

      expect(match.captures).to eq( [ File.expand_path( 'test/TestFoo.c' ), '30', '1' ] )
    end

    # The reason :clion needs absolute paths
    it "gives CLion's output filter nothing to find in a relative path" do
      expect(IdeParsers::CLION_FILTER.match( problem( :failed ).first )).to be_nil
    end

    it 'leaves continuation lines to no parser' do
      continuation = problem( :failed ).last

      expect(continuation).to eq( '    #0 0x4011 in main test/TestFoo.c:12:5' )
      expect(IdeParsers.cdt( continuation )).to be_nil
      expect(IdeParsers::VSCODE_GCC.match( continuation )).to be_nil
      expect(extension( continuation )).to be_nil
    end

    it 'keeps a Windows drive letter, or a space, in the path each parser reads' do
      [ 'C:/Project Files/test/TestFoo.c', 'test dir/TestFoo.c' ].each do |file|
        line = problem( :failed, file: file ).first

        expect(IdeParsers.cdt( line )[:file]).to eq( file )
        expect(IdeParsers::VSCODE_GCC.match( line )[1]).to eq( file )
        expect(extension( line )[:file]).to eq( file )
      end

      expect(IdeParsers::CLION_FILTER.match( problem( :failed, file: 'C:/Project Files/test/TestFoo.c' ).first )[1]).to eq( 'C:/Project Files/test/TestFoo.c' )
    end

    # The legacy line is no problem to CDT, which only a space after the line number changes
    it 'gives Eclipse CDT nothing to find in a legacy line' do
      expect(IdeParsers.cdt( problem( :failed, { format: :legacy } ).first )).to be_nil
    end
  end
end
