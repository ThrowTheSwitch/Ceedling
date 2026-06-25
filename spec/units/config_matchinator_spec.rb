# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/exceptions'
require 'ceedling/constants'
require 'ceedling/config/config_matchinator'

describe ConfigMatchinator do

  # ---------------------------------------------------------------------------
  # Shared setup for instance method tests
  # ---------------------------------------------------------------------------
  # @loginator and @reportinator absorb all logging/reporting side-effects.
  # @configurator is set up per-test via stubs on the shared double.

  before(:each) do
    @configurator = double('configurator')
    @loginator    = double('loginator').as_null_object
    @reportinator = double('reportinator').as_null_object

    @cm = described_class.new(
      {
        :configurator => @configurator,
        :loginator    => @loginator,
        :reportinator => @reportinator
      }
    )
  end


  # ---------------------------------------------------------------------------
  # .append_matcher_entries — class method, no instance needed
  # ---------------------------------------------------------------------------

  describe '.append_matcher_entries' do

    # --- Default matcher :* — Array shortcut in scope ---

    context 'default :* matcher with top-level Array' do
      it 'appends a single string entry to the array' do
        entry = ['FOO']
        ConfigMatchinator.append_matcher_entries(entry, 'BAR')
        expect(entry).to eq(['FOO', 'BAR'])
      end

      it 'appends a list of entries to the array' do
        entry = ['FOO']
        ConfigMatchinator.append_matcher_entries(entry, ['BAR', 'BAZ'])
        expect(entry).to eq(['FOO', 'BAR', 'BAZ'])
      end
    end

    context 'default :* matcher with Hash that has a :* key mapping to an Array' do
      it 'appends a single string to the :* list' do
        entry = { :* => ['FOO'] }
        ConfigMatchinator.append_matcher_entries(entry, 'BAR')
        expect(entry).to eq({ :* => ['FOO', 'BAR'] })
      end

      it 'appends a list of entries to the :* list' do
        entry = { :* => ['FOO'] }
        ConfigMatchinator.append_matcher_entries(entry, ['BAR', 'BAZ'])
        expect(entry).to eq({ :* => ['FOO', 'BAR', 'BAZ'] })
      end
    end

    context 'default :* matcher with Hash that has a :* key mapping to a single String' do
      it 'replaces the string with an array containing it and the new string' do
        entry = { :* => 'FOO' }
        ConfigMatchinator.append_matcher_entries(entry, 'BAR')
        expect(entry).to eq({ :* => ['FOO', 'BAR'] })
      end

      it 'replaces the string with an array containing it and all new entries' do
        entry = { :* => 'FOO' }
        ConfigMatchinator.append_matcher_entries(entry, ['BAR', 'BAZ'])
        expect(entry).to eq({ :* => ['FOO', 'BAR', 'BAZ'] })
      end
    end

    context 'default :* matcher with Hash that has no :* key' do
      it 'creates a :* key with the single string wrapped in a list' do
        entry = { :Model => ['X'] }
        ConfigMatchinator.append_matcher_entries(entry, 'BAR')
        expect(entry).to eq({ :Model => ['X'], :* => ['BAR'] })
      end

      it 'creates a :* key with the list of entries' do
        entry = { :Model => ['X'] }
        ConfigMatchinator.append_matcher_entries(entry, ['BAR', 'BAZ'])
        expect(entry).to eq({ :Model => ['X'], :* => ['BAR', 'BAZ'] })
      end
    end

    context 'default :* matcher with nil — no-op' do
      it 'leaves nil unchanged' do
        entry = nil
        ConfigMatchinator.append_matcher_entries(entry, 'BAR')
        expect(entry).to be_nil
      end
    end

    # --- Non-default matcher — Hash-only processing, no Array shortcut ---

    context 'non-default matcher with Hash whose key maps to an Array' do
      it 'appends a single string to the named key list' do
        entry = { :Model => ['FOO'] }
        ConfigMatchinator.append_matcher_entries(entry, 'BAR', matcher: :Model)
        expect(entry).to eq({ :Model => ['FOO', 'BAR'] })
      end

      it 'appends a list of entries to the named key list' do
        entry = { :Model => ['FOO'] }
        ConfigMatchinator.append_matcher_entries(entry, ['BAR', 'BAZ'], matcher: :Model)
        expect(entry).to eq({ :Model => ['FOO', 'BAR', 'BAZ'] })
      end
    end

    context 'non-default matcher with Hash whose key maps to a single String' do
      it 'replaces the string with an array containing it and the new entry' do
        entry = { :Model => 'FOO' }
        ConfigMatchinator.append_matcher_entries(entry, 'BAR', matcher: :Model)
        expect(entry).to eq({ :Model => ['FOO', 'BAR'] })
      end
    end

    context 'non-default matcher with Hash that does not have the named key' do
      it 'adds the named key with the new entry in a list' do
        entry = { :Other => ['X'] }
        ConfigMatchinator.append_matcher_entries(entry, 'BAR', matcher: :Model)
        expect(entry).to eq({ :Other => ['X'], :Model => ['BAR'] })
      end
    end

    context 'non-default matcher with a top-level Array — no-op (no Array shortcut)' do
      it 'leaves the array unchanged' do
        entry = ['FOO']
        ConfigMatchinator.append_matcher_entries(entry, 'BAR', matcher: :Model)
        expect(entry).to eq(['FOO'])
      end
    end

    context 'non-default matcher with nil — no-op' do
      it 'leaves nil unchanged' do
        entry = nil
        ConfigMatchinator.append_matcher_entries(entry, 'BAR', matcher: :Model)
        expect(entry).to be_nil
      end
    end

  end # .append_matcher_entries


  # ---------------------------------------------------------------------------
  # #config_include? — instance method
  # ---------------------------------------------------------------------------

  describe '#config_include?' do
    it 'returns false when the configurator does not respond to the accessor' do
      allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(false)
      expect(@cm.config_include?(primary: :defines, secondary: :test)).to be false
    end

    it 'returns true when the accessor exists and no tertiary is requested' do
      allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(true)
      expect(@cm.config_include?(primary: :defines, secondary: :test)).to be true
    end

    context 'when the config value is an Array' do
      before do
        allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(true)
        allow(@configurator).to receive(:defines_test).and_return(['FOO', 'BAR'])
      end

      it 'returns false when a tertiary key is requested (arrays cannot contain matcher keys)' do
        expect(@cm.config_include?(primary: :defines, secondary: :test, tertiary: :*)).to be false
      end
    end

    context 'when the config value is a Hash' do
      before do
        allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(true)
        allow(@configurator).to receive(:defines_test).and_return({ :* => ['A'], :Model => ['B'] })
      end

      it 'returns true when the tertiary key is present' do
        expect(@cm.config_include?(primary: :defines, secondary: :test, tertiary: :*)).to be true
        expect(@cm.config_include?(primary: :defines, secondary: :test, tertiary: :Model)).to be true
      end

      it 'returns false when the tertiary key is absent' do
        expect(@cm.config_include?(primary: :defines, secondary: :test, tertiary: :Other)).to be false
      end
    end
  end # #config_include?


  # ---------------------------------------------------------------------------
  # #get_config — instance method
  # ---------------------------------------------------------------------------

  describe '#get_config' do
    it 'returns nil when the configurator does not respond to the accessor' do
      allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(false)
      expect(@cm.get_config(primary: :defines, secondary: :test)).to be_nil
    end

    context 'when the config value is an Array' do
      before do
        allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(true)
        allow(@configurator).to receive(:defines_test).and_return(['FOO', 'BAR'])
      end

      it 'returns the full array when no tertiary is specified' do
        expect(@cm.get_config(primary: :defines, secondary: :test)).to eq(['FOO', 'BAR'])
      end

      it 'raises CeedlingException when a tertiary key is specified' do
        expect {
          @cm.get_config(primary: :defines, secondary: :test, tertiary: :*)
        }.to raise_error(CeedlingException)
      end
    end

    context 'when the config value is a Hash' do
      before do
        allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(true)
        allow(@configurator).to receive(:defines_test).and_return({ :* => ['A'], :Model => ['B'] })
      end

      it 'returns nil when the tertiary key is absent' do
        expect(@cm.get_config(primary: :defines, secondary: :test, tertiary: :Other)).to be_nil
      end

      it 'returns the sub-value when the tertiary key is present' do
        expect(@cm.get_config(primary: :defines, secondary: :test, tertiary: :Model)).to eq(['B'])
      end

      it 'returns the entire hash when no tertiary is specified' do
        expect(@cm.get_config(primary: :defines, secondary: :test)).to eq({ :* => ['A'], :Model => ['B'] })
      end
    end

    context 'when the config value is an unexpected type' do
      before do
        allow(@configurator).to receive(:respond_to?).with(:defines_test).and_return(true)
        allow(@configurator).to receive(:defines_test).and_return('unexpected_string')
      end

      it 'raises CeedlingException' do
        expect {
          @cm.get_config(primary: :defines, secondary: :test)
        }.to raise_error(CeedlingException)
      end
    end
  end # #get_config


  # ---------------------------------------------------------------------------
  # #matches? — instance method, exercised against documentation examples
  # ---------------------------------------------------------------------------
  # Docs define the following matcher types and their behavior:
  #   :*          — Wildcard: matches all test executables
  #   /regex/     — Regex:    matches test executable names against a regexp
  #   Comms*Model — Wildcard: matches filenames with * expansion
  #   Model       — Substring: matches test executables with the string in the name
  #
  # From the documentation, these are the expected cumulative results:
  #   test_Something      → symbols from :* only               → ["A"]
  #   test_Main           → symbols from :*, /M(ain|odel)/     → ["A", "BLESS_YOU"]
  #   test_Model          → symbols from :*, :Model, /M(ain|odel)/ → ["A", "CHOO", "BLESS_YOU"]
  #   test_CommsSerialModel → all matchers                     → ["A", "CHOO", "BLESS_YOU", "THANKS"]
  # ---------------------------------------------------------------------------

  describe '#matches?' do
    # The documentation example hash (keys are Ruby symbols as YAML would produce)
    let(:doc_hash) do
      {
        :*                 => ['A'],
        :Model             => ['CHOO'],
        :"/M(ain|odel)/"   => ['BLESS_YOU'],
        :"Comms*Model"     => ['THANKS']
      }
    end

    it 'raises CeedlingException when filepath is nil' do
      expect {
        @cm.matches?(hash: doc_hash, filepath: nil, section: :defines, context: :test)
      }.to raise_error(CeedlingException)
    end

    context 'documentation examples' do
      it 'test_Something matches only :* wildcard → ["A"]' do
        result = @cm.matches?(hash: doc_hash, filepath: 'test_Something', section: :defines, context: :test)
        expect(result).to eq(['A'])
      end

      it 'test_Main matches :* and /M(ain|odel)/ → ["A", "BLESS_YOU"]' do
        result = @cm.matches?(hash: doc_hash, filepath: 'test_Main', section: :defines, context: :test)
        expect(result).to eq(['A', 'BLESS_YOU'])
      end

      it 'test_Model matches :*, :Model, and /M(ain|odel)/ → ["A", "CHOO", "BLESS_YOU"]' do
        result = @cm.matches?(hash: doc_hash, filepath: 'test_Model', section: :defines, context: :test)
        expect(result).to eq(['A', 'CHOO', 'BLESS_YOU'])
      end

      it 'test_CommsSerialModel matches all matchers → ["A", "CHOO", "BLESS_YOU", "THANKS"]' do
        result = @cm.matches?(hash: doc_hash, filepath: 'test_CommsSerialModel', section: :defines, context: :test)
        expect(result).to eq(['A', 'CHOO', 'BLESS_YOU', 'THANKS'])
      end
    end

    context 'wildcard :* matcher in isolation' do
      it 'matches every filepath' do
        hash = { :* => ['ALWAYS'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_Anything',  section: :defines, context: :test)).to eq(['ALWAYS'])
        expect(@cm.matches?(hash: hash, filepath: 'test_SomethingElse', section: :defines, context: :test)).to eq(['ALWAYS'])
      end
    end

    context 'regex matcher' do
      it 'matches filepaths whose name satisfies the regex' do
        hash = { :"/M(ain|odel)/" => ['HIT'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_Main',  section: :defines, context: :test)).to eq(['HIT'])
        expect(@cm.matches?(hash: hash, filepath: 'test_Model', section: :defines, context: :test)).to eq(['HIT'])
      end

      it 'does not match filepaths that do not satisfy the regex' do
        hash = { :"/M(ain|odel)/" => ['HIT'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_Something', section: :defines, context: :test)).to eq([])
      end
    end

    context 'wildcard-in-string matcher' do
      it 'matches filepaths that satisfy the wildcard expansion' do
        hash = { :"Comms*Model" => ['HIT'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_CommsXYZModel',    section: :defines, context: :test)).to eq(['HIT'])
        expect(@cm.matches?(hash: hash, filepath: 'test_CommsSerialModel', section: :defines, context: :test)).to eq(['HIT'])
      end

      it 'does not match filepaths that do not satisfy the wildcard expansion' do
        hash = { :"Comms*Model" => ['HIT'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_Something', section: :defines, context: :test)).to eq([])
      end
    end

    context 'substring matcher' do
      it 'matches filepaths that contain the substring' do
        hash = { :Model => ['HIT'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_Model',     section: :defines, context: :test)).to eq(['HIT'])
        expect(@cm.matches?(hash: hash, filepath: 'test_Model_ext', section: :defines, context: :test)).to eq(['HIT'])
      end

      it 'does not match filepaths that do not contain the substring' do
        hash = { :Model => ['HIT'] }
        expect(@cm.matches?(hash: hash, filepath: 'test_Unrelated', section: :defines, context: :test)).to eq([])
      end
    end

    context 'multiple matchers are cumulative' do
      it 'collects symbols from all matchers that match' do
        hash = { :* => ['ALWAYS'], :Foo => ['WHEN_FOO'] }
        result = @cm.matches?(hash: hash, filepath: 'test_Foo', section: :defines, context: :test)
        expect(result).to eq(['ALWAYS', 'WHEN_FOO'])
      end

      it 'returns only matching symbols when some matchers do not match' do
        hash = { :* => ['ALWAYS'], :Bar => ['WHEN_BAR'] }
        result = @cm.matches?(hash: hash, filepath: 'test_Foo', section: :defines, context: :test)
        expect(result).to eq(['ALWAYS'])
      end
    end

    context 'empty hash' do
      it 'returns an empty list' do
        expect(@cm.matches?(hash: {}, filepath: 'test_Anything', section: :defines, context: :test)).to eq([])
      end
    end

  end # #matches?

end
