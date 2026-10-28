# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# GH #1371: `upgrade` never refreshed documentation that `new --docs` exported, because it
# looked for a file exports stopped writing in 1.1.0. For a 1.0.x export, which it did
# find, it removed all of docs/, the project's own files included.
#
# These run the real launcher against real projects. Nothing compiles, so no toolchain is
# needed.

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'rbconfig'

describe '`upgrade` and exported documentation' do
  REPO = File.expand_path( '../..', __dir__ )
  UNITY_PAGE = File.join( 'unity', 'UnityGettingStartedGuide.md' )

  def ceedling(*args)
    stdout, stderr, status = Open3.capture3(
      {'CEEDLING_DECORATORS' => 'false'}, RbConfig.ruby, File.join( REPO, 'bin', 'ceedling' ), *args, chdir: @tmp
    )
    raise "`ceedling #{args.join( ' ' )}` failed:\n#{stdout}#{stderr}" unless status.success?
  end

  def docs(*entry)
    return File.join( @tmp, 'proj', 'docs', *entry )
  end

  def write(entry, text='')
    FileUtils.mkdir_p( File.dirname( docs( entry ) ) )
    File.write( docs( entry ), text )
  end

  around(:each) do |example|
    Dir.mktmpdir( 'upgrade_docs' ) { |dir| @tmp = dir; example.run }
  end

  it 'refreshes an export of 1.1.0 or later and keeps the project\'s own files' do
    ceedling( 'new', '--local', '--docs', 'proj' )
    write( 'notes.md', 'mine' )
    write( File.join( 'unity', 'stale.md' ) )
    write( UNITY_PAGE, 'edited' )

    ceedling( 'upgrade', 'proj' )

    expect(File.exist?( docs( 'unity', 'stale.md' ) )).to be( false )
    expect(File.read( docs( UNITY_PAGE ) )).to eq( File.read( File.join( REPO, 'vendor', 'unity', 'docs', 'UnityGettingStartedGuide.md' ) ) )
    expect(File.read( docs( 'notes.md' ) )).to eq( 'mine' )
  end

  it 'replaces a 1.0.x export with the current layout and keeps the project\'s own files' do
    ceedling( 'new', '--local', 'proj' )
    write( 'CeedlingPacket.md' )
    write( 'Changelog.md' )
    write( File.join( 'plugins', 'gcov.md' ) )
    write( File.join( 'unity', 'stale.md' ) )
    write( 'license.txt' )
    write( 'notes.md', 'mine' )

    ceedling( 'upgrade', 'proj' )

    ['CeedlingPacket.md', 'Changelog.md', 'plugins', File.join( 'unity', 'stale.md' )].each do |entry|
      expect(File.exist?( docs( entry ) )).to be( false ), entry
    end
    expect(File.exist?( docs( UNITY_PAGE ) )).to be( true )
    expect(File.read( docs( 'notes.md' ) )).to eq( 'mine' )
  end

  it 'leaves a docs/ holding only the project\'s own files alone' do
    ceedling( 'new', '--local', 'proj' )
    write( 'notes.md', 'mine' )

    ceedling( 'upgrade', 'proj' )

    expect(Dir.children( docs )).to eq( ['notes.md'] )
  end
end
