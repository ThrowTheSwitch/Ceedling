# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'contract/runner'
require 'contract/recorder'

describe Contract::Recorder do

  let( :row ) do
    Contract::Loader.parse( {
      'id'    => 'RES-901',
      'title' => 'A recorded row',
      'modes' => ['none', 'tests'],
      'tree'  => { 'test/test_a.c' => "#include \"a.h\"\n" }
    }, source: 'spec' )
  end

  let( :report ) do
    {
      'outcome'  => { 'status' => 'pass' },
      'resolved' => { 'test/test_a.c "a.h"' => 'src/a.h' },
      'link_set' => { 'build/test/out/test_a.out' => ['test/test_a.c', 'src/a.c'] }
    }
  end

  let( :compiler ) { { 'test/test_a.c "a.h"' => 'src/a.h' } }

  def result( key, report, compiler )
    variant = row.variants.find { |item| item.key == key }
    build   = Contract::Runner::Build.new( task: 'test:all', report: report, compiler: compiler )
    return Contract::Runner::Result.new( variant: variant, builds: [build], seconds: 1.0 )
  end

  it 'records this platform and the compiler column, keeping other platforms' do
    Dir.mktmpdir do |dir|
      recorder = described_class.new( row, dir: dir )
      recorder.write( { 'id' => row.id, 'current' => { 'windows' => { 'none' => ['kept'] } } } )

      merged = recorder.merged( 'linux', [result( 'none', report, compiler )] )
      recorder.write( merged )

      expect( recorder.current( 'windows', 'none' ) ).to eq( ['kept'] )
      expect( recorder.current( 'linux', 'none' ) ).to eq( [{ 'task' => 'test:all' }.merge( report )] )
      expect( recorder.current( 'linux', 'tests' ) ).to be_nil
      expect( recorder.compiler ).to eq( [compiler] )
    end
  end

  it 'leaves a skipped variant as recorded' do
    Dir.mktmpdir do |dir|
      recorder = described_class.new( row, dir: dir )
      recorder.write( { 'id' => row.id, 'current' => { 'linux' => { 'tests' => ['kept'] } } } )
      skipped  = Contract::Runner::Result.new( variant: row.variants.last, builds: [], seconds: 0.0, skipped: 'no tool' )

      merged = recorder.merged( 'linux', [result( 'none', report, compiler ), skipped] )
      expect( merged['current']['linux']['tests'] ).to eq( ['kept'] )
    end
  end

end

describe Contract::Check do

  let( :recorded ) do
    [{ 'task' => 'test:all', 'link_set' => { 'build/test/out/test_a.out' => ['test/test_a.c', 'src/a.c'] } }]
  end

  it 'passes a report equal to its recording' do
    expect { described_class.equal!( recorded, Marshal.load( Marshal.dump( recorded ) ), 'row' ) }.not_to raise_error
  end

  # A checker is trusted only once it is seen to fail on a known wrong input
  it 'fails a recorded column with one wrong path, naming where' do
    wrong = Marshal.load( Marshal.dump( recorded ) )
    wrong[0]['link_set']['build/test/out/test_a.out'][1] = 'src/b/a.c'

    expect { described_class.equal!( wrong, recorded, 'row' ) }.to raise_error( Contract::Mismatch, %r{\[0\] > link_set > build/test/out/test_a.out: recorded .*src/b/a\.c} )
  end

  it 'fails a section recorded but no longer observed' do
    expect { described_class.equal!( [{ 'task' => 'x', 'gone' => 1 }], [{ 'task' => 'x' }], 'row' ) }.to raise_error( Contract::Mismatch, /gone: recorded but not observed/ )
  end

  it 'finds each entry where Ceedling and the compiler both answer, and differ' do
    resolved = { 'a "x.h"' => 'src/x.h', 'a "mock_y.h"' => 'src/y.h', 'a "x.h" source' => ['src/x.c'] }
    compiler = { 'a "x.h"' => 'src/x.h', 'a "mock_y.h"' => 'missing' }

    expect( described_class.divergences( resolved, compiler ) ).to eq( 'a "mock_y.h"' => ['src/y.h', 'missing'] )
  end

  it 'fails an undeclared divergence, and passes a declared one' do
    found = { 'a "mock_y.h"' => ['src/y.h', 'missing'] }

    expect { described_class.declared!( found, [], 'row' ) }.to raise_error( Contract::Mismatch, /undeclared divergence:\n  resolved a "mock_y.h": Ceedling "src\/y.h", compiler "missing"/ )
    expect { described_class.declared!( found, ['a "mock_y.h"'], 'row' ) }.not_to raise_error
  end

  describe '.search_order!' do
    let( :header_dirs ) { ['.', 'src', 'src/lock', 'src/log'] }

    # Generated, vendor and derived paths are Ceedling's own, and a directory without a
    # header can answer no include, so neither counts
    it "passes the oracle's order when Ceedling searches the header directories the same way" do
      ceedling = ['build/test/mocks/t', '.', 'src', 'src/empty', 'src/lock', 'src/log', 'src/derived', '%{ceedling}/vendor/unity/src']
      oracle   = ['test', '.', 'src', 'src/empty', 'src/lock', 'src/log']

      expect { described_class.search_order!( oracle, ceedling, derived: ['src/derived'], header_dirs: header_dirs, what: 'row' ) }.not_to raise_error
    end

    it 'fails when Ceedling searches two header directories in another order, naming both orders' do
      ceedling = ['.', 'src', 'src/log', 'src/lock']
      oracle   = ['.', 'src', 'src/lock', 'src/log']

      expect { described_class.search_order!( oracle, ceedling, derived: [], header_dirs: header_dirs, what: 'row' ) }.to raise_error(
        Contract::Mismatch, %r{row searches its header directories in another order than the oracle:\n  Ceedling \[".", "src", "src/log", "src/lock"\]\n  oracle   \[".", "src", "src/lock", "src/log"\]}
      )
    end

    it 'fails when the oracle searches a header directory Ceedling does not' do
      expect { described_class.search_order!( ['src', 'src/lock'], ['src'], derived: [], header_dirs: header_dirs, what: 'row' ) }.to raise_error( Contract::Mismatch )
    end
  end

end
