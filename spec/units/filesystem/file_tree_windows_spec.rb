# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'file_tree_helper'
require 'ceedling/filesystem/file_tree'

# GH #1376: Windows reparse points. A junction is a link to a directory that Ruby does not
# report as a symlink. A file compressed by the Windows Overlay Filter (WOF) carries a
# reparse point that is not a link, like a deduplicated file. Each example skips itself when
# its runner cannot make the reparse point.
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

  it 'descends a junction to a directory' do
    write( File.join( @root, 'elsewhere/inner.c' ), 'int x;' )
    FileUtils.mkdir_p( @src )
    made = system( 'cmd', '/c', 'mklink', '/J', windows( File.join( @src, 'junction' ) ), windows( File.join( @root, 'elsewhere' ) ), out: File::NULL )
    skip 'could not make a junction' unless made

    FileTree.sync( @src, @dst, publish: FileTreeHelper::PUBLISH )

    expect( File.read( File.join( @dst, 'junction/inner.c' ) ) ).to eq( 'int x;' )
  end

  it 'copies a WOF-compressed file as a regular file of its full size' do
    path = File.join( @src, 'unity.c' )
    write( path, 'x' * 100_000 )
    compressed = system( 'compact', '/c', '/exe:lzx', '/f', windows( path ), out: File::NULL )
    skip 'compact /exe is unavailable on this volume' unless compressed
    skip 'the file did not become a WOF reparse point' unless `fsutil reparsepoint query "#{windows( path )}" 2>&1`.match?( /0x80000017/i )

    # The canary: records how Ruby classifies a non-link reparse point. It asserts nothing.
    $stdout.puts "\n[canary] WOF file: lstat.ftype=#{File.lstat( path ).ftype} stat.ftype=#{File.stat( path ).ftype}"

    FileTree.sync( @src, @dst, publish: FileTreeHelper::PUBLISH )

    expect( File.file?( File.join( @dst, 'unity.c' ) ) ).to be( true )
    expect( File.size( File.join( @dst, 'unity.c' ) ) ).to eq( 100_000 )
  end
end
