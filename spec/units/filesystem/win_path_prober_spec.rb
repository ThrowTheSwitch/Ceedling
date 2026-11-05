# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'rbconfig'
require 'ceedling/constants'
require 'ceedling/filesystem/win_path_prober'

# Touches no filesystem and runs no process: the probe is stubbed, and ToolExecutor is a
# double. The real probe and the real `reg query` run in spec/integration/.
describe WinPathProber do
  let(:tool) { { name: 'default_windows_registry_query', executable: 'reg.exe', arguments: [] } }

  before(:each) do
    @configurator  = double( 'configurator', project_build_root: 'build', tools_windows_registry_query: tool )
    @tool_executor = double( 'tool_executor' )
    @loginator     = double( 'loginator' )
    @logged        = []
    allow(@loginator).to receive(:log) { |message, verbosity = nil, label = nil| @logged << [message, verbosity, label] }

    @prober = described_class.new( { configurator: @configurator, tool_executor: @tool_executor, loginator: @loginator } )
  end

  def probe_returning(support, cause: nil)
    result = cause ? { support: support, cause: cause, error: 'reg missing' } : { support: support }
    allow(WinLongPaths).to receive(:probe).and_return( result )
  end

  # Messages a user sees at normal verbosity
  def shown
    return @logged.reject { |_message, verbosity, _label| verbosity == Verbosity::DEBUG }
  end

  describe '#long_paths?' do
    it 'probes below the build root with its own registry query' do
      probe_returning( :full )
      @prober.long_paths?( :auto )

      expect(WinLongPaths).to have_received(:probe).with( 'build', query: @prober.method( :registry_query ) )
    end

    context 'with :long_paths' do
      it 'answers yes with full support, noting it at DEBUG' do
        probe_returning( :full )

        expect(@prober.long_paths?( :long_paths )).to be true
        expect(shown).to be_empty
        expect(@logged.map(&:first)).to include( match( /Windows long paths: full support \(Ruby #{Regexp.escape( RUBY_VERSION )}\)/ ) )
      end

      it 'answers yes when only files work, warning that directory listing fails' do
        probe_returning( :files_only )

        expect(@prober.long_paths?( :long_paths )).to be true
        expect(shown.length).to eq( 1 )
        message, verbosity = shown.first
        expect(verbosity).to eq( Verbosity::COMPLAIN )
        expect(message).to include( ':project ↳ :win_path_limit is :long_paths' )
        expect(message).to include( "Ruby #{RUBY_VERSION} cannot list directories past 260 characters" )
        expect(message).to match( /`clean`, and `clobber`/ )
      end

      it 'answers no when long paths are disabled, warning with the registry value' do
        probe_returning( :none, cause: :registry_disabled )

        expect(@prober.long_paths?( :long_paths )).to be false
        expect(shown.map { |_m, verbosity, _l| verbosity }).to eq( [Verbosity::COMPLAIN] )
        expect(shown.first.first).to include( 'LongPathsEnabled' )
      end

      it 'names this Ruby when it is not long-path-aware' do
        probe_returning( :none, cause: :process_not_aware )
        @prober.long_paths?( :long_paths )

        expect(shown.first.first).to include( RbConfig.ruby ).and include( 'not long-path-aware' )
      end

      it 'names the registry error when the probe could not read it' do
        probe_returning( :none, cause: :probe_failed )
        @prober.long_paths?( :long_paths )

        expect(shown.first.first).to include( 'reg missing' )
      end
    end

    context 'with :auto' do
      it 'answers yes with full support, saying nothing at normal verbosity' do
        probe_returning( :full )

        expect(@prober.long_paths?( :auto )).to be true
        expect(shown).to be_empty
      end

      it 'answers no when only files work, with one notice' do
        probe_returning( :files_only )

        expect(@prober.long_paths?( :auto )).to be false
        expect(shown.map { |_m, verbosity, label| [verbosity, label] }).to eq( [[Verbosity::NORMAL, LogLabels::NOTICE]] )
        expect(shown.first.first).to include( "Ruby #{RUBY_VERSION} cannot list directories past 260 characters" )
      end

      it 'answers no when long paths are disabled, with one notice' do
        probe_returning( :none, cause: :registry_disabled )

        expect(@prober.long_paths?( :auto )).to be false
        expect(shown.map { |_m, verbosity, label| [verbosity, label] }).to eq( [[Verbosity::NORMAL, LogLabels::NOTICE]] )
        expect(shown.first.first).to include( 'LongPathsEnabled' )
      end
    end

    it 'probes and logs once, then keeps its answer' do
      probe_returning( :files_only )
      @prober.long_paths?( :auto )
      @prober.long_paths?( :auto )

      expect(WinLongPaths).to have_received(:probe).once
      expect(@logged.length).to eq( 1 )
    end

    it 'probes once, however many threads ask at once' do
      probe_returning( :files_only )
      threads = (0...8).map { Thread.new { @prober.long_paths?( :auto ) } }

      expect(threads.map(&:value)).to all( be false )
      expect(WinLongPaths).to have_received(:probe).once
      expect(@logged.length).to eq( 1 )
    end
  end

  describe '#registry_query' do
    def expect_command(result, failed:)
      command = { options: {} }
      expect(@tool_executor).to receive(:build_command_line)
        .with( tool, [], WinLongPaths::REGISTRY_KEY, WinLongPaths::REGISTRY_VALUE ).and_return( command )
      expect(@tool_executor).to receive(:exec).with( command ) do |executed|
        expect(executed[:options][:boom]).to be false
        result
      end
      allow(@tool_executor).to receive(:failed?).with( result ).and_return( failed )
    end

    it 'runs the configured tool for the long paths value, without raising on a failed exit' do
      expect_command( { output: 'LongPathsEnabled    REG_DWORD    0x1' }, failed: false )

      expect(@prober.registry_query).to eq( ['LongPathsEnabled    REG_DWORD    0x1', true] )
    end

    it 'reports a failed exit as an unsuccessful query, with its output' do
      expect_command( { output: 'ERROR: The system was unable to find the specified registry key or value.' }, failed: true )

      expect(@prober.registry_query).to eq( ['ERROR: The system was unable to find the specified registry key or value.', false] )
    end
  end
end
