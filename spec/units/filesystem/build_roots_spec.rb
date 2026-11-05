# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'digest/sha2'
require 'ceedling/filesystem/build_roots'
require 'ceedling/filesystem/build_subpath'

# GH #1387: a long configured root's location is replaced by a short marker in build paths.
# Roots are spelled relative to the working directory, so nothing here reads the disk.
describe BuildRoots do
  KEIL_INCLUDE = "#{'../' * 7}Keil_v5/ARM/PACK/ARM/CMSIS/5.9.0/CMSIS/RTOS2/Include".freeze

  # The marker the module documents: the root's name, then 8 hex digits of its encoded spelling
  def expected_marker(root, name, windows: false)
    key = BuildSubpath.encode( root )
    key = key.downcase if windows
    return "_#{name}_#{Digest::SHA256.hexdigest( key )[0, 8].upcase}"
  end

  describe '.table' do
    it 'shortens a root outside the project, whose climb and location no build step reads' do
      table = described_class.table( [KEIL_INCLUDE] )

      expect(table.marker_for( KEIL_INCLUDE )).to eq( expected_marker( KEIL_INCLUDE, 'Include' ) )
      expect(table.root_for( table.marker_for( KEIL_INCLUDE ) )).to eq( KEIL_INCLUDE )
    end

    it 'shortens a deep root inside the project' do
      root = 'vendor/acme/sdk/v3/drivers/hal'
      expect(described_class.table( [root] ).marker_for( root )).to eq( expected_marker( root, 'hal' ) )
    end

    it 'leaves a root alone when its marker would be no shorter than its own spelling' do
      table = described_class.table( ['src', 'src2/a', '.', '..'] )

      expect(table.entries).to be_empty
    end

    it 'shortens a root once its marker is shorter, however slightly' do
      root = 'foo/bar/baz/abc' # 15 characters, and its marker 13

      expect(described_class.table( [root] ).marker_for( root ).length).to eq( 13 )
    end

    it 'drops leading underscores from the name, so a marker begins with exactly one' do
      private_root = 'vendor/acme/sdk/v3/drivers/_private'
      blank_root   = 'vendor/acme/sdk/v3/drivers/___'
      table        = described_class.table( [private_root, blank_root] )

      expect(table.marker_for( private_root )).to eq( expected_marker( private_root, 'private' ) )
      expect(table.marker_for( blank_root )).to eq( expected_marker( blank_root, 'root' ) )
    end

    it 'gives a marker the shape decoding recognizes' do
      expect(described_class.table( [KEIL_INCLUDE] ).marker_for( KEIL_INCLUDE )).to match( BuildRoots::MARKER )
    end

    it 'gives two same-named roots different markers' do
      other = "#{'../' * 7}Keil_v5/ARM/PACK/ARM/CMSIS/5.9.0/CMSIS/Core/Include"
      table = described_class.table( [KEIL_INCLUDE, other] )

      expect(table.marker_for( KEIL_INCLUDE )).to_not eq( table.marker_for( other ) )
    end

    it 'gives a root the same marker every time' do
      expect(described_class.table( [KEIL_INCLUDE] ).marker_for( KEIL_INCLUDE )).to eq( described_class.table( [KEIL_INCLUDE] ).marker_for( KEIL_INCLUDE ) )
    end

    # A whole tree shares one marker and keeps its own structure below it
    it 'considers only the outermost of nested roots' do
      outer = 'vendor/acme/sdk/v3'
      inner = 'vendor/acme/sdk/v3/drivers/hal/include'
      table = described_class.table( [inner, outer] )

      expect(table.entries.map(&:first)).to eq( [outer] )
    end

    it 'shortens nothing below a shallow outermost root, even a deep root inside it' do
      expect(described_class.table( ['src', 'src/a/b/c/d/e/f'] ).entries).to be_empty
    end

    it 'finds the shortened root holding a directory, if any' do
      table = described_class.table( [KEIL_INCLUDE, 'src'] )

      expect(table.containing( ProjectPaths.absolute( "#{KEIL_INCLUDE}/os" ) )).to eq( KEIL_INCLUDE )
      expect(table.containing( ProjectPaths.absolute( KEIL_INCLUDE ) )).to eq( KEIL_INCLUDE )
      expect(table.containing( ProjectPaths.absolute( 'src/drv' ) )).to be_nil
    end

    # macOS and Windows file systems fold case, and Windows spellings of one place may differ in it
    it 'keys its hash on a case-folded spelling on Windows, so two spellings of one root get one marker' do
      lower = KEIL_INCLUDE.downcase
      upper = described_class.table( [KEIL_INCLUDE], windows: true ).marker_for( KEIL_INCLUDE )

      expect(upper).to eq( expected_marker( KEIL_INCLUDE, 'Include', windows: true ) )
      expect(described_class.table( [lower], windows: true ).marker_for( lower ).delete_prefix( '_include' )).to eq( upper.delete_prefix( '_Include' ) )
    end

    it 'holds a digest that tells two tables apart' do
      expect(described_class.table( [KEIL_INCLUDE] ).digest).to_not eq( described_class.table( [] ).digest )
      expect(described_class.table( [KEIL_INCLUDE] ).digest).to eq( described_class.table( [KEIL_INCLUDE] ).digest )
    end
  end

  describe '.collisions' do
    it 'reports two roots that would share a marker' do
      other = "#{'../' * 7}Keil_v5/Other/Include"
      allow(Digest::SHA256).to receive(:hexdigest).and_return( 'ab' * 32 )

      expect(described_class.collisions( [KEIL_INCLUDE, other] )).to eq( [[KEIL_INCLUDE, other]] )
    end

    it 'reports nothing for roots with distinct markers' do
      expect(described_class.collisions( [KEIL_INCLUDE, 'vendor/acme/sdk/v3/drivers/hal'] )).to be_empty
    end
  end
end
