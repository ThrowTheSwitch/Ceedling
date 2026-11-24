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

end
