# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'contract/runner'

describe Contract::Runner do

  def row( extra = {} )
    data = {
      'id'    => 'RES-901',
      'title' => 'A small project',
      'modes' => ['none'],
      'tree'  => {
        'src/a.h'       => "int a_twice(int x);\n",
        'src/a.c'       => "#include \"a.h\"\nint a_twice(int x) { return 2 * x; }\n",
        'src/b.h'       => "int b_get(void);\n",
        'test/test_a.c' => "#include \"unity.h\"\n#include \"a.h\"\n#include \"mock_b.h\"\n" \
                           "void setUp(void) {}\nvoid tearDown(void) {}\n" \
                           "void test_a(void) { b_get_ExpectAndReturn(3); TEST_ASSERT_EQUAL(6, a_twice(b_get())); }\n"
      },
      'project' => { paths: { include: ['src'] } }
    }
    return Contract::Loader.parse( data.merge( extra ), source: 'spec' )
  end

  def run( row )
    return described_class.new( row ).run( row.variants.first )
  end

  it 'merges the base project, the row, the leg and the mode, and enables the probe' do
    leg_row = row( 'legs' => { 'cov' => { 'plugins' => ['gcov'], 'project' => { gcov: { summaries: false } } } } )
    Contract::Workspace.create do |workspace|
      project = described_class.new( leg_row ).project_for( leg_row.variants.first, workspace, '/probe' )

      expect( project[:project] ).to include( use_test_preprocessor: :none, which_ceedling: Contract::CHECKOUT, build_root: 'build' )
      expect( project[:paths] ).to eq( test: ['test/**'], source: ['src/**'], include: ['src'] )
      expect( project[:plugins] ).to eq( load_paths: ['/probe'], enabled: ['contract_probe', 'gcov'] )
      expect( project[:gcov] ).to eq( summaries: false )
    end
  end

  context 'with a project that builds and passes' do
    before( :all ) do
      @result = run( row( 'modes' => ['tests'] ) )
      @build  = @result.builds.first
      @report = @build.report
    end

    it 'reports one build of its task, passing' do
      expect( @result.builds.map( &:task ) ).to eq( ['test:all'] )
      expect( @report['outcome'] ).to include( 'status' => 'pass', 'stage' => nil, 'error' => nil )
      expect( @report['outcome']['stages']['Building Objects'] ).to include( 'Compiling test_a.c...' )
    end

    it 'reports what Ceedling resolved for each test include' do
      expect( @report['resolved'] ).to include(
        'test/test_a.c "mock_b.h"' => 'src/b.h',
        'test/test_a.c "a.h"'      => 'src/a.h',
        'test/test_a.c "a.h" source' => ['src/a.c']
      )
    end

    it 'reports search paths, placements and the link set as normalized paths' do
      expect( @report['search_paths']['tests']['test/test_a']['test'] ).to include( 'src' )
      expect( @report['placements']['mocks'] ).to include( 'build/test/mocks/test/test_a/_t_/mock_b.h' )
      expect( @report['placements']['generated']['mocks'] ).to eq( ['src/b.h'] )
      expect( @report['link_set'].values.first ).to include( 'test/test_a.c', 'src/a.c' )
    end

    it "reports the headers each object's .d file lists, raw beside normalized" do
      listed = @report['entered']['dependencies']['test/test_a test/test_a.c']
      expect( listed ).to include( { 'raw' => 'src/a.h', 'path' => 'src/a.h' } )
    end

    it 'reports that the first build preprocesses the test through a stand-in at the mock path' do
      expect( @report['entered']['mocks_read'] ).to eq( 'test/test_a' => { 'build/test/mocks/test/test_a/_t_/mock_b.h' => 'stand-in' } )
    end

    it 'asks the oracle about the same tree' do
      expect( @build.compiler ).to include( 'test/test_a.c "a.h"' => 'src/a.h', 'test/test_a.c "mock_b.h"' => 'missing', 'src/a.c "a.h"' => 'src/a.h' )
    end
  end

  it 'pairs a source with a plain include by its spelling where test preprocessing is off' do
    resolved = run( row ).builds.first.report['resolved']
    expect( resolved ).to include( 'test/test_a.c "a.h" source' => ['src/a.c'] )
    expect( resolved ).not_to include( 'test/test_a.c "a.h"' )
  end

  it 'reports a failed compile as an observation, with its stage and first error line' do
    broken = row( 'tree' => row.tree.merge( 'src/a.c' => "#include \"a.h\"\nint a_twice(int x) { return 2 * y; }\n" ) )
    report = run( broken ).builds.first.report

    expect( report['outcome']['status'] ).to eq( 'fail' )
    expect( report['outcome']['stage'] ).to eq( 'Building Objects' )
    expect( report['outcome']['error'] ).to match( %r{\Asrc/a\.c:2:.*error:.*'y'} )
  end

  it 'applies write steps between builds, and the oracle sees the tree each build saw' do
    steps = [
      { 'build' => 'test:all' },
      { 'write' => { 'src/sub/a.h' => "int a_twice(int x);\n" } },
      { 'build' => 'test:all' }
    ]
    shadowed = row( 'steps' => steps, 'project' => { paths: { include: ['src/sub', 'src'] } } )
    builds = run( shadowed ).builds

    expect( builds.map { |build| build.compiler['test/test_a.c "a.h"'] } ).to eq( ['src/a.h', 'src/sub/a.h'] )
  end

  it 'skips a leg whose tool this machine lacks' do
    absent = row( 'legs' => { 'odd' => { 'requires' => ['no-such-tool-contract'] } } )
    result = run( absent )

    expect( result.skipped ).to match( /needs no-such-tool-contract/ )
    expect( result.builds ).to be_empty
  end

end
