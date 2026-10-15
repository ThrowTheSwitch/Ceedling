# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'json'

$LOAD_PATH.unshift( File.expand_path( '../../../plugins/report_build_warnings_log/lib', __dir__ ) )

require 'ceedling/exceptions'
require 'warning_collector'
require 'warning_reports'

describe WarningReports do

  # A compile's GCC warning with a function context, and a link's warning in no known format
  WARNING_REPORTS_COMPILE = <<~OUT.freeze
    src/a.c: In function 'a':
    src/a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]
        2 | int a( void ) { int spare; return 0; }
          |                     ^~~~~
  OUT
  WARNING_REPORTS_LINK = "ld: warning: object file was built for a newer OS\n".freeze

  let(:records) { [WARNING_REPORTS_COMPILE, WARNING_REPORTS_LINK].flat_map { |output| WarningCollector.new.warnings( output ) } }

  def report(name)
    return described_class.load( [name], version: '9.9.9' ).first
  end

  describe '.load' do
    it 'is the text report alone when no reports are configured' do
      [nil, []].each do |entries|
        expect(described_class.load( entries, version: '1' ).map( &:extension )).to eq( ['log'] )
      end
    end

    it 'takes symbols or strings in any letter case, each report once' do
      expect(described_class.load( [:sarif, 'JSON', 'sarif', :text], version: '1' ).map( &:extension )).to eq( %w[sarif json log] )
    end

    it 'refuses an unknown report, naming it and the choices' do
      expect { described_class.load( [:text, :xml], version: '1' ) }
        .to raise_error( CeedlingException, /`xml`.*:text, :sarif, :json/ )
    end

    it 'refuses an entry that is neither a symbol nor a string' do
      expect { described_class.load( [42], version: '1' ) }.to raise_error( CeedlingException, /`42`/ )
    end
  end

  describe '.basename' do
    it 'drops any extension from the configured filename' do
      expect(%w[warnings warnings.log more.better.ext].map { |name| described_class.basename( name ) })
        .to eq( %w[warnings warnings more.better] )
    end
  end

  describe 'text report' do
    it 'is each warning as the tools printed it' do
      expect(report( :text ).render( :test, records )).to eq( WARNING_REPORTS_COMPILE + WARNING_REPORTS_LINK )
    end

    it 'is not written for a build context without warnings' do
      expect(report( :text ).write_empty?).to be false
    end
  end

  describe 'JSON report' do
    it 'lists each warning with its parsed fields under its build context' do
      json = JSON.parse( report( :json ).render( :test, records ) )

      expect(json['context']).to eq( 'test' )
      expect(json['warnings'].first).to eq(
        'file' => 'src/a.c', 'line' => 2, 'column' => 21, 'severity' => 'warning', 'flag' => '-Wunused-variable',
        'message' => "unused variable 'spare'", 'context' => ["src/a.c: In function 'a':"],
        'text' => "src/a.c: In function 'a':\nsrc/a.c:2:21: warning: unused variable 'spare' [-Wunused-variable]\n" \
                  "    2 | int a( void ) { int spare; return 0; }\n      |                     ^~~~~\n"
      )
      expect(json['warnings'].last).to include( 'file' => nil, 'message' => 'ld: warning: object file was built for a newer OS' )
    end

    it 'is written, with no warnings, for a build context without any' do
      expect(report( :json ).write_empty?).to be true
      expect(JSON.parse( report( :json ).render( :release, [] ) )).to eq( 'context' => 'release', 'warnings' => [] )
    end
  end

  describe 'SARIF report' do
    let(:sarif) { JSON.parse( report( :sarif ).render( :test, records ) ) }
    let(:run)   { sarif['runs'].first }

    it 'is one SARIF 2.1.0 run by Ceedling, identified by its build context' do
      expect(sarif).to include( 'version' => '2.1.0', '$schema' => 'https://json.schemastore.org/sarif-2.1.0.json' )
      expect(sarif['runs'].size).to eq( 1 )
      expect(run['tool']['driver']).to include( 'name' => 'Ceedling', 'version' => '9.9.9' )
      expect(run['tool']['driver']['rules']).to eq( [{ 'id' => '-Wunused-variable' }] )
      expect(run['automationDetails']).to eq( 'id' => 'test/' )
    end

    it 'makes a GCC warning a result with its flag as rule, its level, message, and location' do
      expect(run['results'].first).to eq(
        'ruleId'     => '-Wunused-variable',
        'level'      => 'warning',
        'message'    => { 'text' => "unused variable 'spare'" },
        'locations'  => [{ 'physicalLocation' => {
          'artifactLocation' => { 'uri' => 'src/a.c', 'uriBaseId' => '%SRCROOT%' },
          'region'           => { 'startLine' => 2, 'startColumn' => 21 }
        } }],
        'properties' => { 'context' => ["src/a.c: In function 'a':"], 'text' => records.first.text }
      )
    end

    it 'makes output in another format a result with only its message' do
      expect(run['results'].last).to eq(
        'message'    => { 'text' => 'ld: warning: object file was built for a newer OS' },
        'properties' => { 'context' => [], 'text' => "ld: warning: object file was built for a newer OS\n" }
      )
    end

    it 'gives each severity its SARIF level' do
      output = "a.c:1:1: remark: r\na.c:2:1: note: n\nb.c:3:1: warning: w\n"
      levels = WarningCollector.new( patterns: [/./] ).warnings( output ).then { |all| JSON.parse( report( :sarif ).render( :test, all ) ) }
                                .dig( 'runs', 0, 'results' ).map { |result| result['level'] }

      expect(levels).to eq( %w[note warning] )
    end

    it 'locates a path as a project URI with forward slashes and no leading ./, and an absolute path as a file URI' do
      output  = "src\\sub dir\\a.c:4:2: warning: w\nC:\\proj\\b.c:5:1: warning: x\n/home/me/c.c:6:1: warning: y\n./inc/d.h:7:1: warning: z\n"
      results = JSON.parse( report( :sarif ).render( :test, WarningCollector.new.warnings( output ) ) ).dig( 'runs', 0, 'results' )

      expect(results.map { |result| result.dig( 'locations', 0, 'physicalLocation', 'artifactLocation' ) }).to eq( [
        { 'uri' => 'src/sub%20dir/a.c', 'uriBaseId' => '%SRCROOT%' },
        { 'uri' => 'file:///C:/proj/b.c' },
        { 'uri' => 'file:///home/me/c.c' },
        { 'uri' => 'inc/d.h', 'uriBaseId' => '%SRCROOT%' }
      ] )
    end

    it 'is written, with no results, for a build context without warnings' do
      expect(report( :sarif ).write_empty?).to be true
      expect(JSON.parse( report( :sarif ).render( :test, [] ) ).dig( 'runs', 0, 'results' )).to eq( [] )
    end
  end

end
