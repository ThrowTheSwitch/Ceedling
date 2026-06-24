# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'tmpdir'
require 'mixinator'
require 'path_validator'
require 'ceedling/constants'

describe Mixinator do
  before(:each) do
    @loginator = double('loginator')
    allow(@loginator).to receive(:lazy)
    allow(@loginator).to receive(:log)

    @file_wrapper = double('file_wrapper')
    allow(@file_wrapper).to receive(:exist?).and_return(true)
    allow(@file_wrapper).to receive(:directory?).and_return(true)

    @path_validator = PathValidator.new({
      :file_wrapper => @file_wrapper,
      :loginator    => @loginator
    })

    @yaml_wrapper = double('yaml_wrapper')

    @mixin_standardizer = double('mixin_standardizer')
    allow(@mixin_standardizer).to receive(:smart_standardize).and_return(false)

    @merginator = double('merginator')
    allow(@merginator).to receive(:merge).and_return(true)

    @mixinator = described_class.new({
      :mixin_standardizer => @mixin_standardizer,
      :merginator         => @merginator,
      :path_validator     => @path_validator,
      :yaml_wrapper       => @yaml_wrapper,
      :loginator          => @loginator
    })
  end

  # =========================================================================
  describe '#fetch_env_filepaths' do
    it 'returns empty array for empty env' do
      expect(@mixinator.fetch_env_filepaths({})).to eq([])
    end

    it 'ignores non-mixin environment variables' do
      env = {
        'PATH'                  => '/usr/bin:/usr/local/bin',
        'HOME'                  => '/home/user',
        'CEEDLING_PROJECT_FILE' => 'project.yml'
      }
      expect(@mixinator.fetch_env_filepaths(env)).to eq([])
    end

    it 'ignores CEEDLING_MIXIN_0' do
      env = {'CEEDLING_MIXIN_0' => 'some/mixin.yml'}
      expect(@mixinator.fetch_env_filepaths(env)).to eq([])
    end

    it 'returns single mixin env var as one-element array' do
      env = {'CEEDLING_MIXIN_1' => 'path/to/mixin.yml'}
      result = @mixinator.fetch_env_filepaths(env)
      expect(result).to eq([{'CEEDLING_MIXIN_1' => 'path/to/mixin.yml'}])
    end

    it 'returns multiple mixin env vars sorted in ascending numeric order' do
      env = {
        'CEEDLING_MIXIN_10' => 'path/mixin10.yml',
        'CEEDLING_MIXIN_2'  => 'path/mixin2.yml',
        'CEEDLING_MIXIN_1'  => 'path/mixin1.yml',
      }
      result = @mixinator.fetch_env_filepaths(env)
      expect(result.map { |e| e.keys.first }).to eq([
        'CEEDLING_MIXIN_1',
        'CEEDLING_MIXIN_2',
        'CEEDLING_MIXIN_10'
      ])
    end

    it 'removes duplicate filepaths keeping the lower-numbered variable' do
      Dir.mktmpdir do |dir|
        shared_path = File.join(dir, 'shared.yml')
        FileUtils.touch(shared_path)

        env = {
          'CEEDLING_MIXIN_1' => shared_path,
          'CEEDLING_MIXIN_5' => shared_path,
        }
        result = @mixinator.fetch_env_filepaths(env)
        expect(result.length).to eq(1)
        expect(result.first.keys.first).to eq('CEEDLING_MIXIN_1')
      end
    end
  end

  # =========================================================================
  describe '#validate_cmdline_yaml_strings' do
    it 'does not raise for a valid Hash-producing YAML string' do
      allow(@yaml_wrapper).to receive(:load_string)
        .and_return({defines: {release: ['MY_SYM']}})
      expect {
        @mixinator.validate_cmdline_yaml_strings([':defines: :release: [MY_SYM]'])
      }.not_to raise_error
    end

    it 'raises and logs an error for an empty string (bare = sigil with no content)' do
      # load_string is not called — the method short-circuits on the empty check
      expect(@loginator).to receive(:log).with(
        /Inline YAML mixin #1 is empty/i,
        anything
      )
      expect {
        @mixinator.validate_cmdline_yaml_strings([''])
      }.to raise_error(/inline YAML failed validation/i)
    end

    it 'raises and logs an error for a whitespace-only string' do
      # load_string is not called — the method short-circuits on the empty check
      expect(@loginator).to receive(:log).with(
        /Inline YAML mixin #1 is empty/i,
        anything
      )
      expect {
        @mixinator.validate_cmdline_yaml_strings(['   '])
      }.to raise_error(/inline YAML failed validation/i)
    end

    it 'raises and logs an error when YAML parses to an Array (not a Hash)' do
      allow(@yaml_wrapper).to receive(:load_string).and_return(['just_a_list_item'])
      expect(@loginator).to receive(:log).with(
        /did not produce a configuration Hash/i,
        anything
      )
      expect {
        @mixinator.validate_cmdline_yaml_strings(['- just_a_list_item'])
      }.to raise_error(/inline YAML failed validation/i)
    end

    it 'raises and logs an error when YAML parses to a scalar' do
      allow(@yaml_wrapper).to receive(:load_string).and_return('just_a_string')
      expect(@loginator).to receive(:log).with(
        /did not produce a configuration Hash/i,
        anything
      )
      expect {
        @mixinator.validate_cmdline_yaml_strings(['just_a_string'])
      }.to raise_error(/inline YAML failed validation/i)
    end

    it 'raises and logs a parse error for invalid YAML' do
      allow(@yaml_wrapper).to receive(:load_string)
        .and_raise(StandardError, 'did not find expected key')
      expect(@loginator).to receive(:log).with(
        /parse error/i,
        anything
      )
      expect {
        @mixinator.validate_cmdline_yaml_strings(['{{{ bad yaml'])
      }.to raise_error(/inline YAML failed validation/i)
    end

    it 'accumulates all errors across multiple strings before raising' do
      # Both invalid strings must be reported; error count == 2 log calls
      allow(@yaml_wrapper).to receive(:load_string).with('- array_not_hash')
        .and_return(['array_not_hash'])
      allow(@yaml_wrapper).to receive(:load_string).with('{{{ broken')
        .and_raise(StandardError, 'did not find expected key')
      expect(@loginator).to receive(:log).with(anything, anything).twice
      expect {
        @mixinator.validate_cmdline_yaml_strings(['- array_not_hash', '{{{ broken'])
      }.to raise_error(/inline YAML failed validation/i)
    end

    it 'does not raise for an empty input array (no inline YAML provided)' do
      expect { @mixinator.validate_cmdline_yaml_strings([]) }.not_to raise_error
    end
  end

  # =========================================================================
  describe '#assemble_mixins' do
    it 'returns empty array when all sources are empty' do
      result = @mixinator.assemble_mixins(config: [], env: [], cmdline: [])
      expect(result).to eq([])
    end

    it 'returns config entry unchanged when only config is provided' do
      entry = {'project configuration' => 'my_mixin', :_input => 'my_mixin'}
      result = @mixinator.assemble_mixins(config: [entry], env: [], cmdline: [])
      expect(result).to eq([entry])
    end

    it 'returns wrapped env entry when only env is provided' do
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [{'CEEDLING_MIXIN_1' => 'env_mixin'}],
        cmdline: []
      )
      expect(result).to eq([{'CEEDLING_MIXIN_1' => 'env_mixin'}])
    end

    it 'returns pre-tagged cmdline entry when only cmdline is provided' do
      # cmdline entries arrive as pre-tagged hashes from configinator
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [],
        cmdline: [{'command line' => 'cli_mixin'}]
      )
      expect(result).to eq([{'command line' => 'cli_mixin'}])
    end

    it 'orders assembled list as [config, env, cmdline] per documentation' do
      cfg_entry = {'project configuration' => 'cfg_mixin', :_input => 'cfg_mixin'}
      result = @mixinator.assemble_mixins(
        config:  [cfg_entry],
        env:     [{'CEEDLING_MIXIN_1' => 'env_mixin'}],
        cmdline: [{'command line' => 'cli_mixin'}]
      )
      expect(result).to eq([
        cfg_entry,
        {'CEEDLING_MIXIN_1' => 'env_mixin'},
        {'command line'     => 'cli_mixin'}
      ])
    end

    it 'deduplicates cmdline and config sharing the same mixin name, keeping cmdline entry' do
      result = @mixinator.assemble_mixins(
        config:  [{'project configuration' => 'shared_mixin', :_input => 'shared_mixin'}],
        env:     [],
        cmdline: [{'command line' => 'shared_mixin'}]
      )
      expect(result.length).to eq(1)
      expect(result.first.keys.first).to eq('command line')
    end

    it 'deduplicates cmdline and env sharing the same mixin name, keeping cmdline entry' do
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [{'CEEDLING_MIXIN_1' => 'shared_mixin'}],
        cmdline: [{'command line' => 'shared_mixin'}]
      )
      expect(result.length).to eq(1)
      expect(result.first.keys.first).to eq('command line')
    end

    it 'deduplicates env and config sharing the same mixin name, keeping env entry' do
      result = @mixinator.assemble_mixins(
        config:  [{'project configuration' => 'shared_mixin', :_input => 'shared_mixin'}],
        env:     [{'CEEDLING_MIXIN_1' => 'shared_mixin'}],
        cmdline: []
      )
      expect(result.length).to eq(1)
      expect(result.first.keys.first).to eq('CEEDLING_MIXIN_1')
    end

    it 'deduplicates cmdline and config sharing the same absolute filepath, keeping cmdline entry' do
      Dir.mktmpdir do |dir|
        shared = File.join(dir, 'shared.yml')
        FileUtils.touch(shared)

        result = @mixinator.assemble_mixins(
          config:  [{'project configuration' => shared, :_input => File.basename(shared, '.yml')}],
          env:     [],
          cmdline: [{'command line' => shared}]
        )
        expect(result.length).to eq(1)
        expect(result.first.keys.first).to eq('command line')
      end
    end

    it 'orders env vars so higher-numbered variable is merged last (wins) per documentation' do
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [
          {'CEEDLING_MIXIN_1' => 'mixin_low'},
          {'CEEDLING_MIXIN_5' => 'mixin_high'}
        ],
        cmdline: []
      )
      expect(result).to eq([
        {'CEEDLING_MIXIN_1' => 'mixin_low'},
        {'CEEDLING_MIXIN_5' => 'mixin_high'}
      ])
    end

    it 'orders multiple cmdline file entries so the rightmost is merged last (wins) per documentation' do
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [],
        cmdline: [
          {'command line' => 'first_mixin'},
          {'command line' => 'second_mixin'},
          {'command line' => 'third_mixin'}
        ]
      )
      expect(result.map { |e| e.values.first }).to eq([
        'first_mixin', 'second_mixin', 'third_mixin'
      ])
    end

    it 'orders multiple config :enabled entries so the last-listed is merged last (wins) per documentation' do
      result = @mixinator.assemble_mixins(
        config:  [
          {'project configuration' => 'first_mixin',  :_input => 'first_mixin'},
          {'project configuration' => 'second_mixin', :_input => 'second_mixin'}
        ],
        env:     [],
        cmdline: []
      )
      expect(result.map { |e| e.values.first }).to eq(['first_mixin', 'second_mixin'])
    end

    it 'includes command line (inline) entries in cmdline tier alongside file entries' do
      # Both 'command line' and 'command line (inline)' belong to the cmdline tier (merged last)
      cfg_entry = {'project configuration' => 'cfg_mixin', :_input => 'cfg_mixin'}
      result = @mixinator.assemble_mixins(
        config:  [cfg_entry],
        env:     [],
        cmdline: [
          {'command line'          => 'file_mixin'},
          {'command line (inline)' => ':defines: :release: [CIPHER_ROT13]'}
        ]
      )
      expect(result).to eq([
        cfg_entry,
        {'command line'          => 'file_mixin'},
        {'command line (inline)' => ':defines: :release: [CIPHER_ROT13]'}
      ])
    end

    it 'preserves left-to-right positional order of mixed file and inline YAML cmdline entries' do
      # The interleaved order from the command line must be maintained through assembly
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [],
        cmdline: [
          {'command line'          => 'first_file'},
          {'command line (inline)' => ':project: :build_root: ci_build'},
          {'command line'          => 'last_file'}
        ]
      )
      sources = result.map { |e| e.keys.first }
      values  = result.map { |e| e.values.first }
      expect(sources).to eq(['command line', 'command line (inline)', 'command line'])
      expect(values).to  eq(['first_file', ':project: :build_root: ci_build', 'last_file'])
    end

    it 'deduplicates identical inline YAML strings in cmdline' do
      # Exact-string dedup: two identical inline YAML entries → only one survives
      result = @mixinator.assemble_mixins(
        config:  [],
        env:     [],
        cmdline: [
          {'command line (inline)' => ':defines: :release: [MY_SYM]'},
          {'command line (inline)' => ':defines: :release: [MY_SYM]'}
        ]
      )
      expect(result.length).to eq(1)
      expect(result.first.keys.first).to eq('command line (inline)')
    end
  end

  # =========================================================================
  describe '#mixin' do
    let(:base_config) { {:project => {:build_root => 'build'}} }
    let(:builtins)    { {:my_builtin => {:foo => :bar}} }

    it 'loads a filepath mixin via yaml_wrapper and merges it into config' do
      mixin_filepath = 'path/to/mixin.yml'
      mixin_content  = {:defines => {:test => {:* => ['MY_DEFINE']}}}

      allow(@yaml_wrapper).to receive(:load).with(mixin_filepath).and_return(mixin_content)

      expect(@merginator).to receive(:merge).with(
        hash_including(mixin: mixin_content)
      ).and_return(true)

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line' => mixin_filepath}]
      )
    end

    it 'looks up a builtin mixin by name and merges its content into config' do
      expect(@merginator).to receive(:merge).with(
        hash_including(mixin: {:foo => :bar})
      ).and_return(true)

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line' => 'my_builtin'}]
      )
    end

    it 'logs a WARNING when a loaded mixin contains a :mixins section' do
      mixin_filepath    = 'path/to/mixin_with_nested.yml'
      mixin_with_nested = {
        :defines => {:test => {:* => ['SYMBOL']}},
        :mixins  => {:enabled => ['nested_mixin']}
      }
      allow(@yaml_wrapper).to receive(:load).with(mixin_filepath).and_return(mixin_with_nested)

      expect(@loginator).to receive(:log).with(
        /nested mixins are not supported/i,
        anything
      )

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line' => mixin_filepath}]
      )
    end

    it 'strips :mixins section from a loaded mixin before merging' do
      mixin_filepath    = 'path/to/mixin.yml'
      mixin_with_section = {
        :defines => {:test => {:* => ['SYMBOL']}},
        :mixins  => {:enabled => ['nested_mixin']}
      }
      allow(@yaml_wrapper).to receive(:load).with(mixin_filepath).and_return(mixin_with_section)

      captured_mixin = nil
      allow(@merginator).to receive(:merge) do |args|
        captured_mixin = args[:mixin]
        true
      end

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line' => mixin_filepath}]
      )

      expect(captured_mixin).not_to have_key(:mixins)
      expect(captured_mixin).to have_key(:defines)
    end

    it 'treats a nil mixin (empty YAML file) as an empty hash without raising' do
      mixin_filepath = 'path/to/empty_mixin.yml'
      allow(@yaml_wrapper).to receive(:load).with(mixin_filepath).and_return(nil)

      expect(@merginator).to receive(:merge).with(
        hash_including(mixin: {})
      ).and_return(true)

      expect {
        @mixinator.mixin(
          builtins: builtins,
          config:   base_config,
          mixins:   [{'command line' => mixin_filepath}]
        )
      }.not_to raise_error
    end

    it 'raises when final config is empty after all merges' do
      allow(@yaml_wrapper).to receive(:load).and_return({})

      expect {
        @mixinator.mixin(
          builtins: builtins,
          config:   {},
          mixins:   [{'command line' => 'path/to/mixin.yml'}]
        )
      }.to raise_error(/Final configuration is empty/i)
    end

    it 'logs a COMPLAIN notice when merge returns false for incompatible types' do
      mixin_filepath = 'path/to/mixin.yml'
      allow(@yaml_wrapper).to receive(:load).with(mixin_filepath).and_return({:foo => 'bar'})
      allow(@merginator).to receive(:merge) do |args|
        args[:warnings] << 'Incompatible merge at :foo ==> Config has String, Mixin has Array'
        false
      end

      expect(@loginator).to receive(:log).at_least(:twice)

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line' => mixin_filepath}]
      )
    end

    it 'logs COMPLAIN notices emitted by smart_standardize' do
      mixin_filepath = 'path/to/mixin.yml'
      allow(@yaml_wrapper).to receive(:load).with(mixin_filepath).and_return({:defines => {}})
      allow(@mixin_standardizer).to receive(:smart_standardize) do |args|
        args[:notices] << 'At :defines: Converted mixin list to matcher hash'
        true
      end

      expect(@loginator).to receive(:log).with(
        'At :defines: Converted mixin list to matcher hash',
        anything,
        anything
      )

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line' => mixin_filepath}]
      )
    end

    it 'parses an inline YAML string via load_string when source is command line (inline)' do
      yaml_string  = ':defines: :release: [MY_SYM]'
      mixin_content = {:defines => {:release => ['MY_SYM']}}

      # Must call load_string (not load) for the inline YAML case
      expect(@yaml_wrapper).to receive(:load_string).with(yaml_string).and_return(mixin_content)
      expect(@yaml_wrapper).not_to receive(:load)

      expect(@merginator).to receive(:merge).with(
        hash_including(mixin: mixin_content)
      ).and_return(true)

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line (inline)' => yaml_string}]
      )
    end

    it 'records inline YAML in config history as a structured hash' do
      yaml_string = ':defines: :release: [MY_SYM]'
      allow(@yaml_wrapper).to receive(:load_string).and_return({:defines => {:release => ['MY_SYM']}})

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line (inline)' => yaml_string, :_input => yaml_string}]
      )

      expect(base_config[:history][:config]).to include(
        hash_including(type: :inline, mechanism: :cmdline, source: '--mixin', value: yaml_string)
      )
    end

    it 'strips :mixins section from inline YAML content before merging' do
      yaml_string = ':defines: :release: [MY_SYM]'
      mixin_with_nested = {
        :defines => {:release => ['MY_SYM']},
        :mixins  => {:enabled => ['nested']}
      }
      allow(@yaml_wrapper).to receive(:load_string).and_return(mixin_with_nested)

      captured_mixin = nil
      allow(@merginator).to receive(:merge) do |args|
        captured_mixin = args[:mixin]
        true
      end

      expect(@loginator).to receive(:log).with(
        /nested mixins are not supported/i,
        anything
      )

      @mixinator.mixin(
        builtins: builtins,
        config:   base_config,
        mixins:   [{'command line (inline)' => yaml_string}]
      )

      expect(captured_mixin).not_to have_key(:mixins)
      expect(captured_mixin).to have_key(:defines)
    end
  end
end
