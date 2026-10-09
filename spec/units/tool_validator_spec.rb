# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/tool_validator'
require 'ceedling/ruby_expandinator'
require 'ceedling/filename_extension'
require 'ceedling/exceptions'

# Unit coverage for ToolValidator through doubled file and system layers.
#
# Nothing here touches the filesystem or the environment. Whether a candidate path exists
# and which search paths and platform apply are stubbed per example. What a real
# filesystem and PATH make of the same rules is proven in
# spec/integration/tool_validator_spec.rb.
describe ToolValidator do
  before(:each) do
    @file_wrapper   = double('file_wrapper')
    @loginator      = double('loginator')
    @system_wrapper = double('system_wrapper')
    @ruby_expandinator = RubyExpandinator.new

    allow(@file_wrapper).to receive(:exist?).and_return(false)
    allow(@loginator).to receive(:log)
    allow(@system_wrapper).to receive(:search_paths).and_return(['/usr/bin'])
    allow(@system_wrapper).to receive(:windows?).and_return(false)

    @tool_validator = described_class.new(
      {
        :file_wrapper      => @file_wrapper,
        :loginator         => @loginator,
        :system_wrapper    => @system_wrapper,
        :ruby_expandinator => @ruby_expandinator
      }
    )
  end

  let(:no_extension) { FilenameExtension.new('') }

  # A tool with a valid redirect, so an example isolates the executable check
  def tool(executable, **extras)
    { :name => 'my_tool', :executable => executable, :stderr_redirect => :none }.merge(extras)
  end

  def validate(tool, extension: no_extension, **options)
    @tool_validator.validate( tool: tool, extension: extension, **options )
  end

  def exists(*paths)
    paths.each { |path| allow(@file_wrapper).to receive(:exist?).with(path).and_return(true) }
  end

  describe 'naming in messages' do
    it 'names the tool by the given name' do
      expect(@loginator).to receive(:log).with(/tools ↳ my_tool/, Verbosity::ERRORS)
      validate( tool('gcc'), name: 'tools ↳ my_tool' )
    end

    it "falls back to the tool's own name when none is given" do
      expect(@loginator).to receive(:log).with(/my_tool ↳ :executable/, Verbosity::ERRORS)
      validate( tool('gcc'), name: nil )
    end

    it "falls back to the tool's own name when the given name is empty" do
      expect(@loginator).to receive(:log).with(/my_tool ↳ :executable/, Verbosity::ERRORS)
      validate( tool('gcc'), name: '' )
    end
  end

  describe 'a missing :executable' do
    it 'logs the omission and returns false' do
      expect(@loginator).to receive(:log).with(/my_tool is missing :executable/, Verbosity::ERRORS)
      expect( validate( tool(nil) ) ).to be(false)
    end

    it 'raises under boom' do
      expect { validate( tool(nil), boom: true ) }.to raise_error(CeedlingException, /missing :executable/)
    end
  end

  describe 'an optional tool' do
    it 'is accepted without any lookup when optional is respected' do
      expect(@file_wrapper).to_not receive(:exist?)
      expect( validate( tool('gcc', :optional => true), respect_optional: true ) ).to be(true)
    end

    it 'is looked up when optional is not respected' do
      expect( validate( tool('gcc', :optional => true) ) ).to be(false)
    end
  end

  # The shell resolves an executable built from an argument at run time
  it 'accepts an argument replacement pattern without any lookup' do
    expect(@file_wrapper).to_not receive(:exist?)
    expect( validate( tool('${1}') ) ).to be(true)
  end

  describe 'a Ruby replacement pattern in :executable' do
    let(:ruby_tool) { tool('#{1+1}') }

    it 'raises (fail-fast, not deferred) when the feature is disabled and boom is true' do
      expect { validate( ruby_tool, boom: true ) }.to raise_error(CeedlingException, /my_tool/)
    end

    it 'logs and returns false when the feature is disabled and boom is false' do
      expect(@loginator).to receive(:log).with(/my_tool/, anything)
      expect( validate( ruby_tool ) ).to be(false)
    end

    it 'passes validation, deferring to the shell at run time, when the feature is enabled' do
      @ruby_expandinator.enable!
      expect( validate( ruby_tool, boom: true ) ).to be(true)
    end
  end

  describe 'parsing the executable from its command' do
    it 'checks an unquoted executable by its first token' do
      exists( '/usr/bin/gcc' )
      expect( validate( tool('gcc -Wall -c') ) ).to be(true)
    end

    it 'checks a quoted executable by its quoted text' do
      exists( '/opt/code cruncher/cc' )
      expect( validate( tool('"/opt/code cruncher/cc" --fast') ) ).to be(true)
    end
  end

  describe 'a bare executable name' do
    before(:each) { allow(@system_wrapper).to receive(:search_paths).and_return(['/first', '/second']) }

    it 'is found as named in any search path' do
      exists( '/second/gcc' )
      expect( validate( tool('gcc') ) ).to be(true)
    end

    it 'is found under any configured extension' do
      exists( '/first/tool.sh' )
      expect( validate( tool('tool'), extension: FilenameExtension.new(['.bat', '.sh']) ) ).to be(true)
    end

    it 'is found as .exe on Windows' do
      allow(@system_wrapper).to receive(:windows?).and_return(true)
      exists( '/first/gcc.exe' )
      expect( validate( tool('gcc') ) ).to be(true)
    end

    it 'is not found as .exe elsewhere' do
      exists( '/first/gcc.exe' )
      expect( validate( tool('gcc') ) ).to be(false)
    end

    # A drive-relative name carries no separator, so it is searched for like any bare name
    it 'treats a drive-relative name as bare' do
      exists( '/first/C:gcc.exe' )
      expect( validate( tool('C:gcc.exe') ) ).to be(true)
    end

    it 'logs that it does not exist in the search paths and returns false' do
      expect(@loginator).to receive(:log).with(/`gcc` does not exist in system search paths/, Verbosity::ERRORS)
      expect( validate( tool('gcc') ) ).to be(false)
    end

    it 'raises under boom when not found' do
      expect { validate( tool('gcc'), boom: true ) }.to raise_error(CeedlingException, /does not exist in system search paths/)
    end
  end

  describe 'an explicit executable path' do
    it 'passes when the file exists' do
      exists( 'tools/bin/gcc' )
      expect( validate( tool('tools/bin/gcc') ) ).to be(true)
    end

    it 'is never searched for in the search paths' do
      expect(@system_wrapper).to_not receive(:search_paths)
      validate( tool('tools/bin/gcc') )
    end

    it 'logs that it does not exist on disk and returns false' do
      expect(@loginator).to receive(:log).with(/`tools\/bin\/gcc` does not exist on disk/, Verbosity::ERRORS)
      expect( validate( tool('tools/bin/gcc') ) ).to be(false)
    end

    it 'raises under boom when missing' do
      expect { validate( tool('tools/bin/gcc'), boom: true ) }.to raise_error(CeedlingException, /does not exist on disk/)
    end
  end

  describe ':stderr_redirect' do
    before(:each) { exists( '/usr/bin/gcc' ) }

    StdErrRedirect.constants.each do |constant|
      it "accepts :#{constant.to_s.downcase}" do
        expect( validate( tool('gcc', :stderr_redirect => constant.to_s.downcase.to_sym) ) ).to be(true)
      end
    end

    it 'matches a recognized option regardless of case' do
      expect( validate( tool('gcc', :stderr_redirect => :AUTO) ) ).to be(true)
    end

    it 'accepts a custom redirect string' do
      expect( validate( tool('gcc', :stderr_redirect => '2>error.log') ) ).to be(true)
    end

    it 'logs the recognized options for an unrecognized one and returns false' do
      expect(@loginator).to receive(:log).with(/:bogus is not a recognized option \{.*:auto.*\}/, Verbosity::ERRORS)
      expect( validate( tool('gcc', :stderr_redirect => :bogus) ) ).to be(false)
    end

    it 'raises for an unrecognized option under boom' do
      expect { validate( tool('gcc', :stderr_redirect => :bogus), boom: true ) }.to raise_error(CeedlingException, /:bogus/)
    end

    # A value of the wrong type is a malformed configuration rather than a bad choice
    # among options, so it stops the build either way
    it 'raises for a value that is neither a Symbol nor a String, even without boom' do
      expect { validate( tool('gcc', :stderr_redirect => 2) ) }.to raise_error(CeedlingException, /neither a recognized value/)
    end
  end

  # Ceedling's own tools always get a redirect filled in, but a direct caller's may not
  it 'accepts a tool with no :stderr_redirect set' do
    exists( '/usr/bin/gcc' )
    expect( validate( { :name => 'my_tool', :executable => 'gcc' } ) ).to be(true)
  end

  describe 'a blank :executable' do
    it 'is reported as missing and returns false' do
      expect(@loginator).to receive(:log).with(/my_tool is missing :executable/, Verbosity::ERRORS)
      expect( validate( tool('') ) ).to be(false)
    end

    it 'is reported as missing under boom when only whitespace' do
      expect { validate( tool('   '), boom: true ) }.to raise_error(CeedlingException, /missing :executable/)
    end
  end

  describe 'a Windows-style explicit path' do
    # Command Hooks entries reach the validator without the backslash cleanup project
    # tools get at load time
    it 'is checked on disk when written with backslashes' do
      expect(@system_wrapper).to_not receive(:search_paths)
      exists( 'C:\\tools\\gcc.exe' )
      expect( validate( tool('C:\\tools\\gcc.exe') ) ).to be(true)
    end

    it 'is found as .exe on Windows when written without its extension' do
      allow(@system_wrapper).to receive(:windows?).and_return(true)
      exists( 'C:/tools/gcc.exe' )
      expect( validate( tool('C:/tools/gcc') ) ).to be(true)
    end
  end

  it 'finds an explicit path under a configured extension' do
    exists( 'tools/tool.sh' )
    expect( validate( tool('tools/tool'), extension: FilenameExtension.new(['.sh']) ) ).to be(true)
  end

  # EXTENSION_EXECUTABLE exists only once a project configuration is loaded
  it "uses the platform's executable extension when none is given and none is configured" do
    skip 'EXTENSION_EXECUTABLE is already defined in this process' if defined?(EXTENSION_EXECUTABLE)
    exists( '/usr/bin/gcc' )
    expect( @tool_validator.validate( tool: tool('gcc') ) ).to be(true)
  end

  describe '.executable_from' do
    it 'is nil for a missing, empty, or whitespace-only command' do
      expect( ToolValidator.executable_from( nil ) ).to be_nil
      expect( ToolValidator.executable_from( '' ) ).to be_nil
      expect( ToolValidator.executable_from( "  \t" ) ).to be_nil
    end

    it 'is the first token of an unquoted command' do
      expect( ToolValidator.executable_from( '  gcc -Wall -c ' ) ).to eq('gcc')
    end

    it 'is the quoted text of a quoted command' do
      expect( ToolValidator.executable_from( '"/opt/code cruncher/cc" --fast' ) ).to eq('/opt/code cruncher/cc')
    end

    it 'is the first token when a quote is never closed' do
      expect( ToolValidator.executable_from( '"/opt/cc --fast' ) ).to eq('"/opt/cc')
    end
  end

  describe '.candidates' do
    def candidates(executable, extension: FilenameExtension.new(['.sh']), windows: false, search_paths: ['/a', '/b'])
      ToolValidator.candidates( executable, extension: extension, windows: windows, search_paths: search_paths )
    end

    it 'joins a bare name with each search path, each followed by its extension variants' do
      expect( candidates('gcc') ).to eq(['/a/gcc', '/a/gcc.sh', '/b/gcc', '/b/gcc.sh'])
    end

    it 'yields only an explicit path and its variants' do
      expect( candidates('tools/gcc') ).to eq(['tools/gcc', 'tools/gcc.sh'])
    end

    it 'treats a backslash as marking an explicit path' do
      expect( candidates('C:\\tools\\gcc', extension: FilenameExtension.new('')) ).to eq(['C:\\tools\\gcc'])
    end

    it 'adds .exe variants only on Windows' do
      expect( candidates('gcc', extension: FilenameExtension.new(''), windows: true, search_paths: ['/a']) ).to eq(['/a/gcc', '/a/gcc.exe'])
      expect( candidates('gcc', extension: FilenameExtension.new(''), windows: false, search_paths: ['/a']) ).to eq(['/a/gcc'])
    end

    it 'treats a drive-relative name as bare' do
      expect( candidates('C:gcc.exe', extension: FilenameExtension.new(''), search_paths: ['/a']) ).to eq(['/a/C:gcc.exe', '/a/C:gcc'])
    end
  end

  describe 'combining both checks' do
    it 'returns false when only the executable check fails' do
      expect( validate( tool('missing') ) ).to be(false)
    end

    it 'returns false when only the redirect check fails' do
      exists( '/usr/bin/gcc' )
      expect( validate( tool('gcc', :stderr_redirect => :bogus) ) ).to be(false)
    end

    it 'returns true when both pass' do
      exists( '/usr/bin/gcc' )
      expect( validate( tool('gcc') ) ).to be(true)
    end
  end
end
