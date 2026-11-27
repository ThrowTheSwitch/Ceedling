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

  it 'drops a recorded section for a variant the row no longer has, on every platform' do
    Dir.mktmpdir do |dir|
      recorder = described_class.new( row, dir: dir )
      recorder.write( { 'id' => row.id, 'current' => { 'linux' => { 'all' => ['stale'] }, 'windows' => { 'none' => ['kept'], 'all' => ['stale'] } } } )

      merged = recorder.merged( 'linux', [result( 'none', report, compiler )] )
      expect( merged['current']['linux'].keys ).to eq( ['none'] )
      expect( merged['current']['windows'] ).to eq( 'none' => ['kept'] )
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
    let( :headers ) { ['top.h', 'src/lock/lock.h', 'src/log/log.h'] }

    # Generated, vendor and derived paths are Ceedling's own, and a directory with no
    # header at or below it can answer no include, so neither counts
    it "passes the oracle's order when Ceedling searches the header directories the same way" do
      ceedling = ['build/test/mocks/t', '.', 'src', 'src/empty', 'src/lock', 'src/log', 'src/derived', '%{ceedling}/vendor/unity/src']
      oracle   = ['test', '.', 'src', 'src/empty', 'src/lock', 'src/log']

      expect { described_class.search_order!( oracle, ceedling, derived: ['src/derived'], headers: headers, what: 'row' ) }.not_to raise_error
    end

    it 'fails when Ceedling searches two header directories in another order, naming both orders' do
      ceedling = ['.', 'src', 'src/log', 'src/lock']
      oracle   = ['.', 'src', 'src/lock', 'src/log']

      expect { described_class.search_order!( oracle, ceedling, derived: [], headers: headers, what: 'row' ) }.to raise_error(
        Contract::Mismatch, %r{row searches its header directories in another order than the oracle:\n  Ceedling \[".", "src", "src/log", "src/lock"\]\n  oracle   \[".", "src", "src/lock", "src/log"\]}
      )
    end

    it 'fails when the oracle searches a header directory Ceedling does not' do
      expect { described_class.search_order!( ['src', 'src/lock'], ['src'], derived: [], headers: headers, what: 'row' ) }.to raise_error( Contract::Mismatch )
    end

    # `.` holds no header of its own, but it answers "src/drivers/bar.h" by joining
    it 'counts a directory that holds a header only below it, so a moved -I . fails' do
      joined = ['src/drivers/bar.h']

      expect { described_class.search_order!( ['.', 'src/drivers'], ['src/drivers', '.'], derived: [], headers: joined, what: 'row' ) }.to raise_error( Contract::Mismatch, /Ceedling \["src\/drivers", "\."\]/ )
      expect { described_class.search_order!( ['.', 'src/drivers'], ['.', 'src/drivers'], derived: [], headers: joined, what: 'row' ) }.not_to raise_error
    end

    # A check over two empty lists proves nothing
    it 'fails when no directory on either side can answer an include' do
      expect { described_class.search_order!( ['test'], ['test'], derived: [], headers: ['src/a.h'], what: 'row' ) }.to raise_error( Contract::Mismatch, /no searched directory holds a header/ )
    end
  end

  describe '.target!' do
    let( :live ) do
      [{ 'outcome' => { 'status' => 'pass' }, 'link_set' => { 'a.out' => ['old.c'] } },
       { 'outcome' => { 'status' => 'pass' }, 'link_set' => { 'a.out' => ['new.c'] } }]
    end

    it "compares each build by the sections its own target promises" do
      target = [{ 'outcome' => { 'status' => 'pass' } }, { 'link_set' => { 'a.out' => ['new.c'] } }]
      expect { described_class.target!( target, live, 'row' ) }.not_to raise_error
    end

    it 'fails a later build whose promised section differs' do
      target = [{ 'outcome' => { 'status' => 'pass' } }, { 'link_set' => { 'a.out' => ['old.c'] } }]
      expect { described_class.target!( target, live, 'row' ) }.to raise_error( Contract::Mismatch, /\[1\] > link_set/ )
    end

    it 'fails a target that promises a different number of builds' do
      expect { described_class.target!( [{ 'outcome' => { 'status' => 'pass' } }], live, 'row' ) }.to raise_error( Contract::Mismatch, /promises 1 build, and 2 ran/ )
    end

    # A real report holds more keys than a target names, such as each stage's progress lines
    context 'with a full report' do
      let( :report ) do
        [{
          'outcome'    => { 'status' => 'pass', 'stage' => nil, 'error' => nil, 'stages' => { 'Building Objects' => ['Compiling a.c...'] } },
          'placements' => { 'mocks' => ['m/mock_a.h', 'm/mock_b.h'], 'objects' => { 't a.c' => 'o/a.o', 't b.c' => 'o/b.o' } }
        }]
      end

      it 'compares only the keys a mapping names, at every depth' do
        target = [{ 'outcome' => { 'status' => 'pass' }, 'placements' => { 'objects' => { 't a.c' => 'o/a.o' } } }]
        expect { described_class.target!( target, report, 'row' ) }.not_to raise_error
      end

      it 'fails a named key whose value differs' do
        target = [{ 'placements' => { 'objects' => { 't a.c' => 'o/x.o' } } }]
        expect { described_class.target!( target, report, 'row' ) }.to raise_error( Contract::Mismatch, /\[0\] > placements > objects > t a\.c: recorded "o\/x\.o", observed "o\/a\.o"/ )
      end

      it 'fails a named key the report lacks' do
        target = [{ 'placements' => { 'objects' => { 't c.c' => 'o/c.o' } } }]
        expect { described_class.target!( target, report, 'row' ) }.to raise_error( Contract::Mismatch, /objects > t c\.c: recorded but not observed/ )
      end

      it 'compares a list whole' do
        target = [{ 'placements' => { 'mocks' => ['m/mock_a.h'] } }]
        expect { described_class.target!( target, report, 'row' ) }.to raise_error( Contract::Mismatch, /placements > mocks: recorded \["m\/mock_a\.h"\]/ )
      end
    end

    # One target serves every platform, though Windows names an executable `.exe`
    it "reads %{exe} as the platform's executable extension" do
      target = [{ 'link_set' => { 'o/t%{exe}' => ['t.c'] } }]
      live   = [{ 'link_set' => { 'o/t.exe' => ['t.c'] } }]

      expect { described_class.target!( target, live, 'row', exe: '.exe' ) }.not_to raise_error
      expect { described_class.target!( target, live, 'row', exe: '.out' ) }.to raise_error( Contract::Mismatch, /link_set > o\/t\.out: recorded but not observed/ )
    end
  end

end
