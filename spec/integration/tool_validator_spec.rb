# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Integration coverage for ToolValidator against a real filesystem and a real PATH.
#
# Whether a candidate file exists, how a quoted path with spaces resolves, and what PATH
# a process actually searches are facts a doubled file layer cannot prove. A real
# FileWrapper and SystemWrapper run here against real temp directories, with PATH set
# per example. The unit spec at spec/units/tool_validator_spec.rb owns every decision
# observable through doubles alone.

require 'spec_helper'
require 'spec_integration_helper'
require 'fileutils'
require 'ceedling/tool_validator'
require 'ceedling/file_wrapper'
require 'ceedling/system_wrapper'
require 'ceedling/ruby_expandinator'
require 'ceedling/filename_extension'
require 'ceedling/constants'
require 'ceedling/exceptions'

describe 'ToolValidator (integration)' do
  before(:each) do
    @loginator = double('loginator')
    allow(@loginator).to receive(:log)
    verbosinator = double('verbosinator')
    allow(verbosinator).to receive(:should_output?).and_return(false)

    @validator = ToolValidator.new(
      {
        :file_wrapper      => FileWrapper.new( { :loginator => @loginator, :verbosinator => verbosinator } ),
        :loginator         => @loginator,
        :system_wrapper    => SystemWrapper.new,
        :ruby_expandinator => RubyExpandinator.new
      }
    )
  end

  let(:no_extension) { FilenameExtension.new('') }

  def validate(executable, extension: no_extension)
    @validator.validate( tool: { :name => 'probe', :executable => executable, :stderr_redirect => :none }, extension: extension )
  end

  # Prepends `dir` to PATH for the block, restoring the original afterward
  def with_path(dir)
    original = ENV['PATH']
    ENV['PATH'] = [dir, original].join( File::PATH_SEPARATOR )
    yield
  ensure
    ENV['PATH'] = original
  end

  describe 'a bare executable name' do
    it 'is found in a directory on PATH' do
      with_source_tree( { 'bin/probe_tool' => '' } ) do |dir|
        with_path( File.join( dir, 'bin' ) ) do
          expect( validate( 'probe_tool' ) ).to be(true)
        end
      end
    end

    it 'is reported missing when no directory on PATH holds it' do
      with_source_tree( { 'bin/probe_tool' => '' } ) do |dir|
        with_path( File.join( dir, 'bin' ) ) do
          expect(@loginator).to receive(:log).with( /does not exist in system search paths/, Verbosity::ERRORS )
          expect( validate( 'absent_probe_tool' ) ).to be(false)
        end
      end
    end

    it 'is found under a configured extension it was written without' do
      with_source_tree( { 'bin/probe_tool.sh' => '' } ) do |dir|
        with_path( File.join( dir, 'bin' ) ) do
          expect( validate( 'probe_tool', extension: FilenameExtension.new(['.sh']) ) ).to be(true)
        end
      end
    end
  end

  describe 'an explicit executable path' do
    it 'passes when written as an absolute path to a real file' do
      with_source_tree( { 'tools/cc' => '' } ) do |dir|
        expect( validate( File.join( dir, 'tools', 'cc' ) ) ).to be(true)
      end
    end

    it 'passes when written relative to the working directory' do
      with_source_tree( { 'tools/cc' => '' } ) do |dir|
        Dir.chdir( dir ) { expect( validate( 'tools/cc' ) ).to be(true) }
      end
    end

    it 'is reported missing on disk when the file does not exist' do
      with_source_tree( { 'tools/cc' => '' } ) do |dir|
        expect(@loginator).to receive(:log).with( /does not exist on disk/, Verbosity::ERRORS )
        expect( validate( File.join( dir, 'tools', 'absent' ) ) ).to be(false)
      end
    end

    it 'resolves a quoted path containing spaces, followed by arguments' do
      with_source_tree( { 'code cruncher/cc' => '' } ) do |dir|
        expect( validate( %("#{File.join( dir, 'code cruncher', 'cc' )}" --fast) ) ).to be(true)
      end
    end

    it 'is found under a configured extension it was written without' do
      with_source_tree( { 'tools/probe_tool.sh' => '' } ) do |dir|
        expect( validate( File.join( dir, 'tools', 'probe_tool' ), extension: FilenameExtension.new(['.sh']) ) ).to be(true)
      end
    end
  end

  # Backslash paths and an omitted .exe exist as real files only on a Windows host
  describe 'a Windows executable path', skip: (SystemWrapper.windows? ? false : 'Windows-only: backslash paths and .exe resolution') do
    it 'passes when written with backslashes' do
      with_source_tree( { 'tools/cc.exe' => '' } ) do |dir|
        expect( validate( File.join( dir, 'tools', 'cc.exe' ).tr( '/', '\\' ) ) ).to be(true)
      end
    end

    it 'finds the .exe file when written without its extension' do
      with_source_tree( { 'tools/cc.exe' => '' } ) do |dir|
        expect( validate( File.join( dir, 'tools', 'cc' ) ) ).to be(true)
      end
    end
  end
end
