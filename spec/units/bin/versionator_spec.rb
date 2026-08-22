# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

# versionator.rb's bare `require 'exceptions'`/`require 'constants'` statements only
# resolve when lib/ceedling/ is directly on the load path -- true in the real
# bin/ceedling bootstrap but not in this spec harness's load path setup. `require
# 'version'` similarly needs lib/ on the load path.
here = File.dirname(__FILE__)
$: << File.join(here, '../../../lib/ceedling')
$: << File.join(here, '../../../lib')

require 'versionator'

describe Versionator do
  # Builds a throwaway vendor/ tree with just enough of each dependency's version
  # header for Versionator to parse -- the real files live in vendor/<project>/,
  # but Versionator only cares about the three VERSION_* macro lines.
  def write_version_header(vendor_path, project, relative_path, major:, minor:, build:)
    header_dir, name = File.split( relative_path )
    dir = File.join( vendor_path, project, header_dir )
    FileUtils.mkdir_p( dir )
    macro_prefix = project.upcase.sub('C_EXCEPTION', 'CEXCEPTION')
    File.write( File.join( dir, name ), <<~HEADER )
      #define #{macro_prefix}_VERSION_MAJOR #{major}
      #define #{macro_prefix}_VERSION_MINOR #{minor}
      #define #{macro_prefix}_VERSION_BUILD #{build}
    HEADER
  end

  describe 'Ceedling tag and build string' do
    it 'sets the Ceedling tag from the Version module' do
      Dir.mktmpdir do |root|
        versionator = described_class.new( root )

        expect(versionator.ceedling_tag).to eq( Ceedling::Version::TAG )
      end
    end

    it 'builds without a commit SHA suffix when no SHA file is present' do
      Dir.mktmpdir do |root|
        versionator = described_class.new( root )

        expect(versionator.ceedling_build).to eq( Ceedling::Version::TAG )
      end
    end

    it 'appends the commit SHA to the build string when the SHA file is present' do
      Dir.mktmpdir do |root|
        File.write( File.join( root, GIT_COMMIT_SHA_FILENAME ), "abc1234\n" )

        versionator = described_class.new( root )

        expect(versionator.ceedling_build).to eq( "#{Ceedling::Version::TAG}-abc1234" )
      end
    end
  end

  describe 'framework version gathering' do
    it 'skips framework tags entirely when no vendor path is given' do
      Dir.mktmpdir do |root|
        versionator = described_class.new( root )

        expect(versionator.unity_tag).to be_nil
        expect(versionator.cmock_tag).to be_nil
        expect(versionator.cexception_tag).to be_nil
      end
    end

    it 'parses version tags out of each vendored framework header' do
      Dir.mktmpdir do |root|
        Dir.mktmpdir do |vendor|
          write_version_header( vendor, 'unity', File.join('src', 'unity.h'), major: 2, minor: 7, build: 1 )
          write_version_header( vendor, 'cmock', File.join('src', 'cmock.h'), major: 2, minor: 7, build: 0 )
          write_version_header( vendor, 'c_exception', File.join('lib', 'CException.h'), major: 1, minor: 3, build: 4 )

          versionator = described_class.new( root, vendor )

          expect(versionator.unity_tag).to eq('2.7.1')
          expect(versionator.cmock_tag).to eq('2.7.0')
          expect(versionator.cexception_tag).to eq('1.3.4')
        end
      end
    end

    it 'raises a CeedlingException when a framework header cannot be read' do
      Dir.mktmpdir do |root|
        Dir.mktmpdir do |vendor|
          # No headers written -- vendor is empty, so every read fails.
          expect {
            described_class.new( root, vendor )
          }.to raise_error( CeedlingException, /Could not collect version information/ )
        end
      end
    end
  end
end
