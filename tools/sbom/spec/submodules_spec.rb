# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Specs for parsing `git submodule status --recursive` into paths and commits.
#
# The sample below is real output from this repository. It is small and changes only
# when a submodule pin moves, so embedding it costs little and carries the fact that
# matters most: Ceedling ships two Unity source trees at different commits.
#
# `git submodule status --recursive` is the command because `git ls-tree -r HEAD`
# does not recurse into submodules. That spelling returns the three top-level
# gitlinks and nothing for the nested pair, which would silently drop two components
# from every document.

require_relative '../submodules'

describe Sbom::Submodules do

  # Real output. The leading column is status, not part of the commit.
  STATUS_OUTPUT = <<~TEXT
     923835236bd235b62f56bd5fe1b4c185c80325da vendor/c_exception (heads/master)
     f2a70b41bb06c63f8957444ab8c3e32f89f8099e vendor/cmock (v2.7.0-4-gf2a70b4)
     923835236bd235b62f56bd5fe1b4c185c80325da vendor/cmock/vendor/c_exception (remotes/origin/HEAD)
     2b67b99a4a87db87ff8c28a3b7e405c3e56d65f0 vendor/cmock/vendor/unity (v2.7.0-14-g2b67b99)
     2b80d1a357271b20f15c9f2573ddab164a626132 vendor/unity (v2.7.0-20-g2b80d1a)
  TEXT

  describe '.parse' do
    it 'finds every gitlink, nested ones included' do
      paths = Sbom::Submodules.parse( STATUS_OUTPUT ).map( &:path )

      expect( paths ).to eq([
        'vendor/c_exception',
        'vendor/cmock',
        'vendor/cmock/vendor/c_exception',
        'vendor/cmock/vendor/unity',
        'vendor/unity'
      ])
    end

    it 'separates the two Unity trees by commit' do
      unity = Sbom::Submodules.parse( STATUS_OUTPUT ).select { |e| e.path.end_with?( 'unity' ) }

      expect( unity.map( &:commit ) ).to eq([
        '2b67b99a4a87db87ff8c28a3b7e405c3e56d65f0',
        '2b80d1a357271b20f15c9f2573ddab164a626132'
      ])
      expect( unity.map( &:commit ).uniq.size ).to eq(2)
    end

    it 'reads the same commit for both CException trees, which genuinely match' do
      cexception = Sbom::Submodules.parse( STATUS_OUTPUT ).select { |e| e.path.include?( 'c_exception' ) }

      expect( cexception.map( &:commit ).uniq ).to eq(['923835236bd235b62f56bd5fe1b4c185c80325da'])
    end

    it 'keeps the describe field where git supplies one' do
      cmock = Sbom::Submodules.parse( STATUS_OUTPUT ).find { |e| e.path == 'vendor/cmock' }
      expect( cmock.describe ).to eq('v2.7.0-4-gf2a70b4')
    end

    it 'treats an in-sync entry as initialized' do
      expect( Sbom::Submodules.parse( STATUS_OUTPUT ) ).to all( be_initialized )
    end

    it 'ignores blank lines' do
      expect( Sbom::Submodules.parse( "\n#{STATUS_OUTPUT}\n\n" ).size ).to eq(5)
    end
  end

  describe 'an uninitialized submodule' do
    # A '-' prefix means the submodule is not checked out. Its commit is still
    # recorded, but no header version can be read from it, so a document generated
    # from such a tree would be quietly incomplete.
    UNINITIALIZED = "-2b80d1a357271b20f15c9f2573ddab164a626132 vendor/unity\n"

    it 'is parsed, with its commit intact' do
      entry = Sbom::Submodules.parse( UNINITIALIZED ).first
      expect( entry.path ).to eq('vendor/unity')
      expect( entry.commit ).to eq('2b80d1a357271b20f15c9f2573ddab164a626132')
    end

    it 'reports itself as not initialized so a caller can refuse to proceed' do
      expect( Sbom::Submodules.parse( UNINITIALIZED ).first ).not_to be_initialized
    end
  end

  describe 'a submodule holding a commit other than the recorded one' do
    # A '+' prefix means the working tree sits at a different commit than the
    # superproject records. The SBOM must describe what is present.
    MODIFIED = "+aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa vendor/unity (v2.7.0-21-gaaaaaaa)\n"

    it 'reports the commit that is checked out' do
      expect( Sbom::Submodules.parse( MODIFIED ).first.commit ).to eq('a' * 40)
    end

    it 'is still initialized' do
      expect( Sbom::Submodules.parse( MODIFIED ).first ).to be_initialized
    end
  end

end
