# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'delegate'
require 'fileutils'
require 'tmpdir'

# Support for specs that copy real file trees (`filesystem: true`).
#
# CEEDLING_TEST_FS_ROOT names a directory on another filesystem, such as a tmpfs, a vfat
# image, a UNC share, or a VHD volume. These specs then build their trees there instead of
# the system temp directory, so CI can run one suite on several filesystems.
module FileTreeHelper
  ROOT_ENV = 'CEEDLING_TEST_FS_ROOT'

  # A stat result that claims a directory. Reproduces a filesystem whose `lstat` reports a
  # regular file as a directory.
  class LyingStat < SimpleDelegator
    def directory?
      true
    end

    def file?
      false
    end

    def symlink?
      false
    end

    def ftype
      'directory'
    end

    def mode
      (__getobj__.mode & ~0o170000) | 0o040000
    end
  end

  # A temporary directory on the filesystem under test, removed afterwards
  def with_tree_root
    root = ENV[ROOT_ENV].to_s
    dir = root.empty? ? Dir.mktmpdir( 'tree' ) : Dir.mktmpdir( 'tree', root )
    yield File.realpath( dir )
  ensure
    FileUtils.rm_rf( dir ) if dir
  end

  def write(path, content = File.basename( path ))
    FileUtils.mkdir_p( File.dirname( path ) )
    File.binwrite( path, content )
  end

  def symlink_or_skip(target, link)
    File.symlink( target, link )
  rescue NotImplementedError, SystemCallError => e
    skip "symlinks are unavailable here (#{e.class})"
  end

  # Every entry below `dir`, dotfiles included, as sorted relative paths
  def tree_of(dir)
    Dir.glob( '**/*', File::FNM_DOTMATCH, base: dir ).reject { |path| path == '.' || path.end_with?( '/.' ) }.sort
  end

  # Makes `File.lstat` lie, claiming a directory, for each path matching `pattern`
  def lie_about_lstat(pattern)
    allow(File).to receive(:lstat).and_wrap_original do |original, path, *rest|
      status = original.call( path, *rest )
      path.to_s.match?( pattern ) ? LyingStat.new( status ) : status
    end
  end

  # Fails any `File.lstat` call, proving code under test never classifies by it
  def forbid_lstat
    allow(File).to receive(:lstat).and_raise( RuntimeError, 'File.lstat must not be called' )
  end

  # The publish step FileWrapper#replace_file performs: a whole copy renamed into place
  PUBLISH = lambda do |source, destination|
    temp = "#{destination}.publishing"
    FileUtils.cp( source, temp )
    File.rename( temp, destination )
  end
end
