# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The Build Warnings Log plugin with real compiler output and real file writing. gcc
# compiles small C files in a temporary project, the plugin's compile hook receives each
# compilation's output as a build would hand it over, and the build's end writes the log.

require 'spec_helper'
require 'spec_integration_helper'
require 'tmpdir'
require 'open3'
require 'json'
require 'ceedling/constants'
require 'ceedling/plugins/plugin'
require 'ceedling/file_wrapper'

$LOAD_PATH.unshift( File.expand_path( '../../plugins/report_build_warnings_log/lib', __dir__ ) )

require 'report_build_warnings_log'

describe 'Build Warnings Log plugin (integration)' do
  include_context 'requires gcc'

  # A header warning every file including it repeats, and an unused variable
  BUILD_WARNINGS_FILES = {
    'shared.h' => "static int unused_helper( void ) { return 1; }\n",
    'a.c'      => "#include \"shared.h\"\nint a( void ) { int spare; return 0; }\n",
    'b.c'      => "#include \"shared.h\"\nint b( void ) { return 0; }\n"
  }.freeze

  let(:logged) { [] }

  def plugin(excludes: [], reports: [])
    loginator = double( 'loginator' ).tap { |log| allow(log).to receive(:log) { |message, *| logged << message } }
    objects   = {
      configurator: double( 'configurator', report_build_warnings_log_filename: 'warnings', report_build_warnings_log_reports: reports,
                            report_build_warnings_log_patterns: [], report_build_warnings_log_excludes: excludes ),
      file_wrapper: FileWrapper.new( { loginator: loginator, verbosinator: double( 'verbosinator', should_output?: false ) } ),
      loginator:    loginator,
      reportinator: double( 'reportinator', generate_heading: '', generate_progress: '' )
    }
    return ReportBuildWarningsLog.new( objects, 'report_build_warnings_log', '/plugins/report_build_warnings_log' )
  end

  def compile(file)
    output, = Open3.capture2e( 'gcc', '-Wall', '-c', file, '-o', File.basename( file, '.c' ) + '.o' )
    return { output: output }
  end

  def in_project
    Dir.mktmpdir( 'warnings' ) do |root|
      Dir.chdir( root ) do
        BUILD_WARNINGS_FILES.each { |name, text| File.write( name, text ) }
        stub_const( 'PROJECT_BUILD_ARTIFACTS_ROOT', 'build/artifacts' )
        yield
      end
    end
  end

  def log_for(context)
    return File.read( "build/artifacts/#{context}/warnings.log" )
  end

  it 'writes the warnings of each build context to its own log' do
    in_project do
      warnings = plugin
      warnings.post_compile_execute( context: :test, shell_result: compile( 'a.c' ) )
      warnings.post_compile_execute( context: :release, shell_result: compile( 'b.c' ) )
      warnings.post_build( 0 )

      expect(log_for( :test )).to include( 'spare' )
      expect(log_for( :release )).to include( 'unused_helper' )
      expect(log_for( :release )).not_to include( 'spare' )
    end
  end

  it 'leaves out warnings a configured exclude matches' do
    in_project do
      warnings = plugin( excludes: ['unused_helper'] )
      warnings.post_compile_execute( context: :test, shell_result: compile( 'a.c' ) )
      warnings.post_build( 0 )

      expect(log_for( :test )).to include( 'spare' )
      expect(log_for( :test )).not_to include( 'unused_helper' )
    end
  end

  it 'writes nothing and says so for a build without warnings' do
    in_project do
      warnings = plugin
      warnings.post_compile_execute( context: :test, shell_result: { output: "Compiling foo.c...\n" } )
      warnings.post_build( 0 )

      expect(Dir.exist?( 'build/artifacts' )).to be false
      expect(logged).to include( "Build produced no warnings.\n" )
    end
  end

  it 'writes its log when the build ends in error too' do
    in_project do
      warnings = plugin
      warnings.post_link_execute( context: :test, shell_result: { output: "ld: warning: object file built for newer OS\n" } )
      warnings.post_error( 0 )

      expect(log_for( :test )).to include( 'ld: warning:' )
    end
  end

  it 'keeps the source and caret lines that belong to each warning' do
    in_project do
      warnings = plugin
      warnings.post_compile_execute( context: :test, shell_result: compile( 'a.c' ) )
      warnings.post_build( 0 )

      expect(log_for( :test )).to include( 'int spare;', '^' )
    end
  end

  it 'logs a warning from a shared header once' do
    in_project do
      warnings = plugin
      %w[a.c b.c].each { |file| warnings.post_compile_execute( context: :test, shell_result: compile( file ) ) }
      warnings.post_build( 0 )

      expect(log_for( :test ).scan( /warning: .*unused_helper/ ).size).to eq( 1 )
    end
  end

  # Structured reports of the same build agree with its text log
  it 'writes SARIF and JSON reports of the warnings in the text log' do
    in_project do
      warnings = plugin( reports: %i[text sarif json] )
      %w[a.c b.c].each { |file| warnings.post_compile_execute( context: :test, shell_result: compile( file ) ) }
      warnings.post_build( 0 )

      json    = JSON.parse( File.read( 'build/artifacts/test/warnings.json' ) )
      sarif   = JSON.parse( File.read( 'build/artifacts/test/warnings.sarif' ) )
      results = sarif.dig( 'runs', 0, 'results' )

      expect(json['warnings'].map { |warning| warning['text'] }.join).to eq( log_for( :test ) )
      expect(json['warnings'].map { |warning| [warning['file'].delete_prefix( './' ), warning['line'], warning['flag']] })
        .to contain_exactly( ['a.c', 2, '-Wunused-variable'], ['shared.h', 1, '-Wunused-function'] )

      expect(sarif).to include( 'version' => '2.1.0' )
      expect(sarif.dig( 'runs', 0, 'tool', 'driver', 'name' )).to eq( 'Ceedling' )
      expect(results.map { |result| result['ruleId'] }).to contain_exactly( '-Wunused-variable', '-Wunused-function' )
      results.each do |result|
        expect(result).to include( 'level' => 'warning', 'message' => hash_including( 'text' ) )
        expect(result.dig( 'locations', 0, 'physicalLocation', 'region', 'startLine' )).to be_a( Integer )
        expect(result.dig( 'locations', 0, 'physicalLocation', 'artifactLocation', 'uri' )).to eq( 'a.c' ).or eq( 'shared.h' )
      end
    end
  end

  it 'writes empty structured reports, and no text log, for a build without warnings' do
    in_project do
      warnings = plugin( reports: %i[text sarif json] )
      warnings.post_compile_execute( context: :test, shell_result: { output: "Compiling foo.c...\n" } )
      warnings.post_build( 0 )

      expect(Dir.children( 'build/artifacts/test' )).to contain_exactly( 'warnings.sarif', 'warnings.json' )
      expect(JSON.parse( File.read( 'build/artifacts/test/warnings.sarif' ) ).dig( 'runs', 0, 'results' )).to eq( [] )
    end
  end

end
