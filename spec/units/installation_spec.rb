# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'ceedling/installation'

describe Installation do
  # Each 1.x release shape of lib/version.rb, as published (stamped DEV) or built locally
  VERSION_1_1 = <<~RUBY
    module Ceedling
      module Version
        GEM = '1.1.10'
        TAG = GEM
        puts( TAG ) if (__FILE__ == $0)
      end
    end
  RUBY

  VERSION_1_2 = <<~RUBY
    module Ceedling
      module Version
        BASE = '1.2.0'
        DEV = '.dev'
        GEM = BASE.end_with?( DEV ) ? BASE : "\#{BASE}\#{DEV}"
        TAG = GEM
        puts( TAG ) if (__FILE__ == $0)
      end
    end
  RUBY

  def write_version(root, text)
    FileUtils.mkdir_p( File.join( root, 'lib' ) )
    File.write( File.join( root, 'lib', 'version.rb' ), text )
  end

  describe '#version' do
    it 'reads the GEM/TAG format of 1.0 and 1.1' do
      Dir.mktmpdir do |root|
        write_version( root, VERSION_1_1 )

        expect(described_class.new( root ).version).to eq( '1.1.10' )
      end
    end

    it 'reads the BASE/DEV format of 1.2 for a local build' do
      Dir.mktmpdir do |root|
        write_version( root, VERSION_1_2 )

        expect(described_class.new( root ).version).to eq( '1.2.0.dev' )
      end
    end

    it 'reads a release whose pipeline emptied DEV' do
      Dir.mktmpdir do |root|
        write_version( root, VERSION_1_2.sub( "DEV = '.dev'", "DEV = ''" ) )

        expect(described_class.new( root ).version).to eq( '1.2.0' )
      end
    end

    # GH #1365: the loaded constant belongs to whichever installation loaded first
    it 'ignores the Ceedling::Version already loaded and leaves it untouched' do
      Dir.mktmpdir do |root|
        write_version( root, VERSION_1_1 )
        stub_const( 'Ceedling::Version::TAG', '9.9.9' )

        expect(described_class.new( root ).version).to eq( '1.1.10' )
        expect(Ceedling::Version::TAG).to eq( '9.9.9' )
      end
    end

    it 'is nil when the installation has no lib/version.rb' do
      Dir.mktmpdir do |root|
        expect(described_class.new( root ).version).to be_nil
      end
    end

    it 'is nil when lib/version.rb defines no Ceedling::Version::TAG' do
      Dir.mktmpdir do |root|
        write_version( root, "module Other; end\n" )

        expect(described_class.new( root ).version).to be_nil
      end
    end

    it 'is nil when lib/version.rb cannot be evaluated' do
      Dir.mktmpdir do |root|
        write_version( root, "module Ceedling\n" )

        expect(described_class.new( root ).version).to be_nil
      end
    end
  end

  describe 'paths' do
    it 'expands its root and derives the launcher and rakefile beneath it' do
      Dir.mktmpdir do |root|
        installation = described_class.new( File.join( root, 'x', '..' ) )

        expect(installation.root).to eq( File.expand_path( root ) )
        expect(installation.bin_path).to eq( File.join( File.expand_path( root ), 'bin', 'ceedling' ) )
        expect(installation.rakefile_path).to eq( File.join( File.expand_path( root ), 'lib', 'ceedling', 'rakefile.rb' ) )
      end
    end
  end

  describe '#==' do
    it 'treats a symlinked path and a trailing slash as the same installation' do
      Dir.mktmpdir do |dir|
        real = File.join( dir, 'real' )
        link = File.join( dir, 'link' )
        FileUtils.mkdir_p( real )
        File.symlink( real, link )

        expect(described_class.new( link )).to eq( described_class.new( real + '/' ) )
      end
    end

    it 'distinguishes different directories' do
      Dir.mktmpdir do |a|
        Dir.mktmpdir do |b|
          expect(described_class.new( a )).not_to eq( described_class.new( b ) )
        end
      end
    end

    it 'compares a path that does not exist by its expanded form' do
      expect(described_class.new( '/no/such/ceedling' )).to eq( described_class.new( '/no/such/ceedling/' ) )
      expect(described_class.new( '/no/such/ceedling' )).not_to eq( described_class.new( '/no/such/other' ) )
    end

    it 'ignores case on Windows only' do
      a = described_class.new( '/no/such/Ceedling' )
      b = described_class.new( '/no/such/ceedling' )

      allow(described_class).to receive(:windows?).and_return( true )
      expect(a).to eq( b )

      allow(described_class).to receive(:windows?).and_return( false )
      expect(a).not_to eq( b )
    end

    it 'is never equal to something other than an Installation' do
      expect(described_class.new( '/no/such/ceedling' )).not_to eq( '/no/such/ceedling' )
    end
  end

  describe '#describe' do
    it 'names the version and root' do
      Dir.mktmpdir do |root|
        write_version( root, VERSION_1_1 )

        expect(described_class.new( root ).describe).to eq( "Ceedling 1.1.10 at #{File.expand_path( root )}/" )
      end
    end

    it 'leaves out a version it cannot read' do
      Dir.mktmpdir do |root|
        expect(described_class.new( root ).describe).to eq( "Ceedling at #{File.expand_path( root )}/" )
      end
    end

    it 'takes a different leading noun' do
      Dir.mktmpdir do |root|
        expect(described_class.new( root ).describe( 'Ceedling launcher' )).to eq( "Ceedling launcher at #{File.expand_path( root )}/" )
      end
    end
  end
end
