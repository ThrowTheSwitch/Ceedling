# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'
require 'ceedling/filesystem/win_long_paths'

# Touches no filesystem and runs no process. The disk is an in-memory fake that records
# each call, and the registry query returns canned output. The real disk and `reg query`
# are exercised in spec/integration/win_long_paths_probe_spec.rb and
# spec/integration/windows_registry_query_tool_spec.rb.
module WinLongPathsSpec
  # `reg query` output as a hosted Windows runner prints it, with long paths enabled
  ENABLED_OUTPUT = "\r\nHKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\FileSystem\r\n" \
                   "    LongPathsEnabled    REG_DWORD    0x1\r\n\r\n".freeze
  DISABLED_OUTPUT = ENABLED_OUTPUT.sub( '0x1', '0x0' ).freeze

  # Records every call. A method named in `raises` raises that error. `glob_result`
  # stands in for a glob that silently leaves entries out, as Ruby 3.0's does.
  class FakeDisk
    attr_reader :calls

    def initialize(raises: {}, glob_result: nil)
      @raises      = raises
      @glob_result = glob_result
      @files       = {}
      @calls       = []
    end

    def mkdir_p(path)  = record( :mkdir_p, path ) { nil }
    def write(path, c) = record( :write, path ) { @files[path] = c }
    def read(path)     = record( :read, path ) { @files.fetch( path ) }
    def delete(path)   = record( :delete, path ) { @files.delete( path ) }
    def rmdir(path)    = record( :rmdir, path ) { nil }

    def children(path)
      record( :children, path ) { @files.keys.select { |f| File.dirname( f ) == path }.map { |f| File.basename( f ) } }
    end

    def glob(pattern)
      record( :glob, pattern ) { @glob_result || @files.keys.select { |f| File.fnmatch( pattern, f ) } }
    end

    private

    def record(name, path)
      @calls << [name, path]
      raise @raises[name] if @raises.key?( name )

      return yield
    end
  end
end

describe WinLongPaths do
  def query_returning(output, success: true)
    return -> { [output, success] }
  end

  let(:root) { '/build' }

  describe '.registry_enabled?' do
    it 'reads 0x1 as enabled' do
      expect(described_class.registry_enabled?( query: query_returning( WinLongPathsSpec::ENABLED_OUTPUT ) )).to be true
    end

    it 'reads 0x0 as disabled' do
      expect(described_class.registry_enabled?( query: query_returning( WinLongPathsSpec::DISABLED_OUTPUT ) )).to be false
    end

    it 'reads a missing value as disabled' do
      output = "\r\nHKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\FileSystem\r\n\r\n"
      expect(described_class.registry_enabled?( query: query_returning( output ) )).to be false
    end

    it 'reads a failed query as disabled' do
      output = "ERROR: The system was unable to find the specified registry key or value.\r\n"
      expect(described_class.registry_enabled?( query: query_returning( output, success: false ) )).to be false
    end

    # ToolExecutor raises a ShellException when the tool can't run at all
    it 'reads a query that could not run as disabled' do
      query = -> { raise ShellException.new( name: 'reg', message: 'reg.exe not found' ) }
      expect(described_class.registry_enabled?( query: query )).to be false
    end

    it 'has no query of its own' do
      expect { described_class.registry_enabled? }.to raise_error( ::ArgumentError, /query/ )
    end
  end

  describe '.probe' do
    def probe(disk, output = WinLongPathsSpec::ENABLED_OUTPUT, query: query_returning( output ))
      return described_class.probe( root, disk: disk, query: query )
    end

    def directories_made(disk)
      return disk.calls.select { |name, _| name == :mkdir_p }.map(&:last)
    end

    it 'reports full support when files and listings both work' do
      expect(probe( WinLongPathsSpec::FakeDisk.new )).to eq( { support: :full } )
    end

    it 'reports files only when listing a long directory raises, as on Ruby 3.1 to 3.4' do
      disk = WinLongPathsSpec::FakeDisk.new( raises: { children: Errno::ENAMETOOLONG.new } )
      expect(probe( disk )).to eq( { support: :files_only } )
    end

    it 'reports files only when a glob silently leaves the file out, as on Ruby 3.0' do
      disk = WinLongPathsSpec::FakeDisk.new( glob_result: [] )
      expect(probe( disk )).to eq( { support: :files_only } )
    end

    it 'blames the registry when writing fails and long paths are disabled' do
      disk = WinLongPathsSpec::FakeDisk.new( raises: { write: Errno::ENOENT.new } )
      expect(probe( disk, WinLongPathsSpec::DISABLED_OUTPUT )).to eq( { support: :none, cause: :registry_disabled } )
    end

    it 'blames the process when writing fails although long paths are enabled' do
      disk = WinLongPathsSpec::FakeDisk.new( raises: { write: Errno::ENOENT.new } )
      expect(probe( disk, WinLongPathsSpec::ENABLED_OUTPUT )).to eq( { support: :none, cause: :process_not_aware } )
    end

    it 'reports the query failure itself when the registry cannot be read' do
      disk   = WinLongPathsSpec::FakeDisk.new( raises: { mkdir_p: Errno::ENOENT.new } )
      result = probe( disk, query: -> { raise ShellException.new( name: 'reg', message: 'reg.exe not found' ) } )

      expect(result[:support]).to eq( :none )
      expect(result[:cause]).to eq( :probe_failed )
      expect(result[:error]).to match( /reg\.exe not found/ )
    end

    it 'has no registry query of its own' do
      expect { described_class.probe( root, disk: WinLongPathsSpec::FakeDisk.new ) }.to raise_error( ::ArgumentError, /query/ )
    end

    it 'never queries the registry when the file test passes' do
      query = -> { raise 'queried' }
      expect(probe( WinLongPathsSpec::FakeDisk.new, query: query )).to eq( { support: :full } )
    end

    # Each directory from `deep` up to `base`, deepest first. It stops at the top of the
    # path too, so a wrong base fails the example instead of climbing forever.
    def ancestry(deep, base)
      chain = [deep]
      chain << File.dirname( chain.last ) until chain.last == base || File.dirname( chain.last ) == chain.last
      return chain
    end

    # The probe expands its root, and on Windows that adds a drive letter. Stubbing the
    # expansion specifies both spellings on every OS.
    { 'a root without a drive' => '/build', 'a root with a drive letter' => 'D:/build' }.each do |kind, expanded|
      context "below #{kind}" do
        before(:each) do
          allow(File).to receive(:expand_path).and_call_original
          allow(File).to receive(:expand_path).with( root ).and_return( expanded )
        end

        it 'builds a path past 260 characters from segments well under 255' do
          disk = WinLongPathsSpec::FakeDisk.new
          probe( disk )

          deep = directories_made( disk ).first

          expect(deep).to start_with( "#{expanded}/" )
          expect(deep.length).to be > described_class::LIMITS[:max_path]
          expect(deep.delete_prefix( "#{expanded}/" ).split( '/' ).map(&:length).max).to be < 255
        end

        [
          ['every test passing',      {}],
          ['a listing failing',       { children: Errno::ENAMETOOLONG.new }],
          ['a write failing midway',  { write: Errno::ENOENT.new }]
        ].each do |description, raises|
          it "removes its file and every directory it made, deepest first, after #{description}" do
            disk = WinLongPathsSpec::FakeDisk.new( raises: raises )
            probe( disk )

            deep    = directories_made( disk ).first
            base    = File.join( expanded, deep.delete_prefix( "#{expanded}/" ).split( '/' ).first )
            removed = disk.calls.select { |name, _| name == :rmdir }.map(&:last)

            expect(disk.calls.map(&:first)).to include( :delete )
            expect(removed).to eq( ancestry( deep, base ) )
          end
        end
      end
    end

    it 'names its directory uniquely, so two probes never share one' do
      first  = WinLongPathsSpec::FakeDisk.new
      second = WinLongPathsSpec::FakeDisk.new
      probe( first )
      probe( second )

      expect(directories_made( first )).not_to eq( directories_made( second ) )
    end
  end
end
