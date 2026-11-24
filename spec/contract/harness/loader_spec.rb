# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'contract/loader'
require 'contract/tree_writer'

describe Contract::Loader do

  let( :minimal ) do
    {
      'id'    => 'RES-901',
      'title' => 'A minimal row',
      'modes' => ['none'],
      'tree'  => { 'test/test_a.c' => "#include \"unity.h\"\n" }
    }
  end

  def parse( data )
    return Contract::Loader.parse( data, source: 'spec' )
  end

  it 'fills each optional field with its default' do
    row = parse( minimal )

    expect( row.platforms ).to eq( %w[linux macos windows] )
    expect( row.plugins ).to eq( [] )
    expect( row.project ).to eq( {} )
    expect( row.steps.map( &:kind ) ).to eq( ['build'] )
    expect( row.steps.first.arg ).to eq( 'test:all' )
    expect( row.divergences ).to eq( [] )
    expect( row.target ).to be_nil
    expect( row.variants.map( &:key ) ).to eq( ['none'] )
  end

  it 'names a named leg in its variant key' do
    row = parse( minimal.merge( 'modes' => ['none', 'tests'], 'legs' => { 'gcov' => { 'plugins' => ['gcov'] } } ) )

    expect( row.variants.map( &:key ) ).to eq( ['none/gcov', 'tests/gcov'] )
    expect( row.variants.first.leg.plugins ).to eq( ['gcov'] )
  end

  it 'rejects an unknown row key, so a misspelled field fails loudly' do
    expect { parse( minimal.merge( 'divergence' => [] ) ) }.to raise_error( Contract::RowError, /unknown row key divergence/ )
  end

  it 'rejects an unknown key in a leg, a step and a divergence' do
    expect { parse( minimal.merge( 'legs' => { 'a' => { 'plugin' => ['gcov'] } } ) ) }.to raise_error( Contract::RowError, /unknown leg a key plugin/ )
    expect { parse( minimal.merge( 'steps' => [{ 'biuld' => 'test:all' }] ) ) }.to raise_error( Contract::RowError, /unknown step key biuld/ )
    divergence = { 'at' => 'resolved test/test_a.c "a.h"', 'kind' => 'defect', 'note' => 'n', 'why' => 'x' }
    expect { parse( minimal.merge( 'divergences' => [divergence] ) ) }.to raise_error( Contract::RowError, /unknown divergence key why/ )
  end

  it 'rejects an ID that names no behavior area' do
    expect { parse( minimal.merge( 'id' => 'AB-032' ) ) }.to raise_error( Contract::RowError, /not an area code/ )
    expect { parse( minimal.merge( 'id' => 'ISO-1' ) ) }.to raise_error( Contract::RowError, /not an area code/ )
  end

  it 'rejects a narrowed platform list without its reason' do
    expect { parse( minimal.merge( 'platforms' => ['linux'] ) ) }.to raise_error( Contract::RowError, /platform_note/ )
    expect( parse( minimal.merge( 'platforms' => ['linux'], 'platform_note' => 'GCC only' ) ).platforms ).to eq( ['linux'] )
  end

  it 'rejects a mode Ceedling does not have, and a row without modes' do
    expect { parse( minimal.merge( 'modes' => ['partials'] ) ) }.to raise_error( Contract::RowError, /modes names partials/ )
    expect { parse( minimal.reject { |key, _| key == 'modes' } ) }.to raise_error( Contract::RowError, /at least one/ )
  end

  it 'rejects a Partials row in any mode but all, since Partials force it' do
    project = { project: { use_partials: true } }
    expect { parse( minimal.merge( 'project' => project, 'modes' => ['tests'] ) ) }.to raise_error( Contract::RowError, /Partials force/ )
    expect( parse( minimal.merge( 'project' => project, 'modes' => ['all'] ) ).partials? ).to be( true )
  end

  it 'rejects a divergence that names no resolved entry, kind or note' do
    base = { 'at' => 'resolved test/test_a.c "a.h"', 'kind' => 'defect', 'note' => 'A note' }
    expect( parse( minimal.merge( 'divergences' => [base] ) ).divergences.first.at ).to eq( 'test/test_a.c "a.h"' )

    expect { parse( minimal.merge( 'divergences' => [base.merge( 'at' => 'test/test_a.c' )] ) ) }.to raise_error( Contract::RowError, /must name a resolved entry/ )
    expect { parse( minimal.merge( 'divergences' => [base.merge( 'kind' => 'accepted' )] ) ) }.to raise_error( Contract::RowError, /kind "accepted"/ )
    expect { parse( minimal.merge( 'divergences' => [base.merge( 'note' => ' ' )] ) ) }.to raise_error( Contract::RowError, /note/ )
  end

  it 'reads build, write, delete and clobber steps, and needs one build' do
    steps = [{ 'build' => 'test:all' }, { 'write' => { 'src/a.h' => "\n" } }, { 'delete' => ['src/b.h'] }, { 'clobber' => nil }, { 'build' => 'test:all' }]
    expect( parse( minimal.merge( 'steps' => steps ) ).steps.map( &:kind ) ).to eq( %w[build write delete clobber build] )

    expect { parse( minimal.merge( 'steps' => [{ 'write' => { 'a.h' => "\n" } }] ) ) }.to raise_error( Contract::RowError, /at least one build step/ )
  end

  it 'requires the ID to match the file name' do
    Dir.mktmpdir do |dir|
      path = File.join( dir, 'RES-902.yml' )
      File.write( path, YAML.dump( minimal ) )
      expect { Contract::Loader.load( path ) }.to raise_error( Contract::RowError, /does not match its filename/ )
    end
  end

  it 'loads every row file in the tier' do
    rows = Contract::Loader.all
    expect( rows ).not_to be_empty
    expect( rows.map( &:id ) ).to eq( rows.map( &:id ).uniq )
  end

end

describe Contract::TreeWriter do

  it 'writes project files, files beside the project and files far outside it' do
    Contract::Workspace.create do |workspace|
      Contract::TreeWriter.write( workspace, {
        'src/a.h'          => "int a;\n",
        '../shared/b.h'    => "int b;\n",
        '%{far}/c.h'       => "#include \"%{far}/d.h\"\n"
      } )

      expect( File.read( File.join( workspace.app, 'src', 'a.h' ) ) ).to eq( "int a;\n" )
      expect( File.read( File.join( workspace.root, 'shared', 'b.h' ) ) ).to eq( "int b;\n" )
      expect( File.read( File.join( workspace.far, 'c.h' ) ) ).to eq( "#include \"#{workspace.far}/d.h\"\n" )
      expect( workspace.far ).not_to start_with( workspace.root )
    end
  end

  it 'applies a delete step to a directory and everything below it' do
    tree = { 'src/a/x.h' => '', 'src/a/y.h' => '', 'src/ab.h' => '' }
    step = Contract::Step.new( kind: 'delete', arg: ['src/a'] )
    expect( Contract::TreeWriter.apply( tree, step ).keys ).to eq( ['src/ab.h'] )
  end

end
