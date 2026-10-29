# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'open3'
require 'spec_helper'
require 'file_tree_helper'
require 'ceedling/filesystem/file_tree'

# GH #1376: Windows reparse points. A junction is a link to a directory, and Ruby reports it
# as one. A file compressed by the Windows Overlay Filter (WOF) carries a reparse point that
# is not a link, like a deduplicated file. Each example skips itself when its runner cannot
# make the reparse point, saying why, and prints a canary line recording how Ruby classifies
# it. Hosted CI runners make no WOF file on any volume tried, so the WOF example skips there.
describe 'FileTree on Windows reparse points', filesystem: true, if: Gem.win_platform? do
  include FileTreeHelper

  around(:each) do |example|
    with_tree_root do |root|
      @root = root
      @src  = File.join( root, 'src' )
      @dst  = File.join( root, 'dst' )
      example.run
    end
  end

  def windows(path)
    path.tr( '/', '\\' )
  end

  # Whether a command succeeded, and a line saying how it ended, for a skip to report
  def run(*command)
    output, status = Open3.capture2e( *command )
    return status.success?, "`#{command.join( ' ' )}` exited #{status.exitstatus}: #{output.split.join( ' ' )[0, 300]}"
  rescue SystemCallError => e
    return false, "`#{command.first}` could not run: #{e.message}"
  end

  def canary(label, path)
    $stdout.puts "\n[canary] #{label}: symlink?=#{File.symlink?( path )} lstat.ftype=#{File.lstat( path ).ftype} stat.ftype=#{File.stat( path ).ftype}"
  end

  it 'descends a junction to a directory' do
    skip 'Windows makes junctions only on local NTFS volumes, not on a UNC share' if @root.start_with?( '//', '\\\\' )

    write( File.join( @root, 'elsewhere/inner.c' ), 'int x;' )
    FileUtils.mkdir_p( @src )
    made, detail = run( 'cmd', '/c', 'mklink', '/J', windows( File.join( @src, 'junction' ) ), windows( File.join( @root, 'elsewhere' ) ) )
    skip "could not make a junction: #{detail}" unless made

    # The canary: records how Ruby classifies a junction. It asserts nothing.
    canary( 'junction', File.join( @src, 'junction' ) )

    FileTree.sync( @src, @dst, publish: FileTreeHelper::PUBLISH )

    expect( File.read( File.join( @dst, 'junction/inner.c' ) ) ).to eq( 'int x;' )
  end

  it 'copies a WOF-compressed file as a regular file of its full size' do
    path = File.join( @src, 'unity.c' )
    write( path, 'x' * 100_000 )
    compressed, detail = run( 'compact', '/c', '/exe:lzx', '/f', windows( path ) )
    skip "compact /exe failed: #{detail}; WOF driver: #{run( 'sc', 'query', 'wof' ).last}" unless compressed
    tagged, query = run( 'fsutil', 'reparsepoint', 'query', windows( path ) )
    skip "the file did not become a WOF reparse point: #{query}" unless tagged && query.match?( /0x80000017/i )

    # The canary: records how Ruby classifies a non-link reparse point. It asserts nothing.
    canary( 'WOF file', path )

    FileTree.sync( @src, @dst, publish: FileTreeHelper::PUBLISH )

    expect( File.file?( File.join( @dst, 'unity.c' ) ) ).to be( true )
    expect( File.size( File.join( @dst, 'unity.c' ) ) ).to eq( 100_000 )
  end
end
