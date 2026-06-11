# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'projectinator'
require 'ceedling/constants'

describe Projectinator do
  before(:each) do
    @loginator = double('loginator')
    allow(@loginator).to receive(:lazy)
    allow(@loginator).to receive(:log)

    @file_wrapper = double('file_wrapper')
    allow(@file_wrapper).to receive(:exist?).and_return(false)
    allow(@file_wrapper).to receive(:directory?).and_return(false)

    @path_validator = double('path_validator')
    allow(@path_validator).to receive(:standardize_paths)
    allow(@path_validator).to receive(:filepath?).and_return(false)
    allow(@path_validator).to receive(:validate).and_return(true)

    @yaml_wrapper = double('yaml_wrapper')

    @system_wrapper = double('system_wrapper')

    @projectinator = described_class.new({
      :file_wrapper   => @file_wrapper,
      :path_validator => @path_validator,
      :yaml_wrapper   => @yaml_wrapper,
      :loginator      => @loginator,
      :system_wrapper => @system_wrapper
    })
  end

  # =========================================================================
  describe '#extract_mixins' do
    it 'returns empty lists and leaves config unchanged when no :mixins key present' do
      config = {:project => {:build_root => 'build'}}
      enabled, load_paths = @projectinator.extract_mixins(config: config)

      expect(enabled).to eq([])
      expect(load_paths).to eq([])
      expect(config).to have_key(:project)
    end

    it 'returns enabled list and empty load_paths when only :enabled is present' do
      config = {
        :mixins => {
          :enabled => ['mixin_a', 'path/to/mixin_b.yml']
        }
      }
      allow(@system_wrapper).to receive(:module_eval)

      enabled, load_paths = @projectinator.extract_mixins(config: config)

      expect(enabled).to eq(['mixin_a', 'path/to/mixin_b.yml'])
      expect(load_paths).to eq([])
    end

    it 'returns empty enabled and load_paths list when only :load_paths is present' do
      config = {
        :mixins => {
          :load_paths => ['support/mixins', 'vendor/mixins']
        }
      }
      allow(@system_wrapper).to receive(:module_eval)

      enabled, load_paths = @projectinator.extract_mixins(config: config)

      expect(enabled).to eq([])
      expect(load_paths).to eq(['support/mixins', 'vendor/mixins'])
    end

    it 'returns both enabled list and load_paths when both sections are present' do
      config = {
        :mixins => {
          :enabled    => ['mixin_a'],
          :load_paths => ['support/mixins']
        }
      }
      allow(@system_wrapper).to receive(:module_eval)

      enabled, load_paths = @projectinator.extract_mixins(config: config)

      expect(enabled).to eq(['mixin_a'])
      expect(load_paths).to eq(['support/mixins'])
    end

    it 'removes :mixins section from config after extraction' do
      config = {
        :project => {:build_root => 'build'},
        :mixins  => {:enabled => ['mixin_a'], :load_paths => ['support']}
      }
      allow(@system_wrapper).to receive(:module_eval)

      @projectinator.extract_mixins(config: config)

      expect(config).not_to have_key(:mixins)
      expect(config).to have_key(:project)
    end

    it 'expands inline Ruby expressions in :enabled entries' do
      config = {
        :mixins => {
          :enabled    => ['#{ENV["MIXIN_NAME"]}'],
          :load_paths => []
        }
      }
      allow(@system_wrapper).to receive(:module_eval)
        .with('#{ENV["MIXIN_NAME"]}')
        .and_return('resolved_mixin_name')

      enabled, _ = @projectinator.extract_mixins(config: config)

      expect(enabled).to eq(['resolved_mixin_name'])
    end

    it 'expands inline Ruby expressions in :load_paths entries' do
      config = {
        :mixins => {
          :enabled    => [],
          :load_paths => ['#{File.join(Dir.pwd, "mixins")}']
        }
      }
      allow(@system_wrapper).to receive(:module_eval)
        .with('#{File.join(Dir.pwd, "mixins")}')
        .and_return('/project/mixins')

      _, load_paths = @projectinator.extract_mixins(config: config)

      expect(load_paths).to eq(['/project/mixins'])
    end

    it 'does not call module_eval for entries without inline Ruby tokens' do
      config = {
        :mixins => {
          :enabled    => ['plain_mixin'],
          :load_paths => ['plain/path']
        }
      }

      expect(@system_wrapper).not_to receive(:module_eval)

      @projectinator.extract_mixins(config: config)
    end
  end

  # =========================================================================
  describe '#lookup_mixins' do
    let(:builtins)       { {:builtin_mixin => {:foo => :bar}} }
    let(:yaml_extension) { '.yml' }

    it 'returns empty array for an empty mixin list' do
      result = @projectinator.lookup_mixins(
        mixins:         [],
        load_paths:     ['support/mixins'],
        builtins:       builtins,
        yaml_extension: yaml_extension
      )
      expect(result).to eq([])
    end

    it 'returns an explicit filepath as-is without searching load_paths' do
      allow(@path_validator).to receive(:filepath?).with('path/to/mixin.yml').and_return(true)

      result = @projectinator.lookup_mixins(
        mixins:         ['path/to/mixin.yml'],
        load_paths:     ['support/mixins'],
        builtins:       builtins,
        yaml_extension: yaml_extension
      )
      expect(result).to eq(['path/to/mixin.yml'])
    end

    it 'resolves a simple name to a filepath in the first matching load_path' do
      allow(@path_validator).to receive(:filepath?).with('my_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('first/path/my_mixin.yml').and_return(true)

      result = @projectinator.lookup_mixins(
        mixins:         ['my_mixin'],
        load_paths:     ['first/path', 'second/path'],
        builtins:       builtins,
        yaml_extension: yaml_extension
      )
      expect(result).to eq(['first/path/my_mixin.yml'])
    end

    it 'resolves a simple name to a filepath in the second load_path when not found in the first' do
      allow(@path_validator).to receive(:filepath?).with('my_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('first/path/my_mixin.yml').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('second/path/my_mixin.yml').and_return(true)

      result = @projectinator.lookup_mixins(
        mixins:         ['my_mixin'],
        load_paths:     ['first/path', 'second/path'],
        builtins:       builtins,
        yaml_extension: yaml_extension
      )
      expect(result).to eq(['second/path/my_mixin.yml'])
    end

    it 'returns the name unchanged when not found in any load_path (treated as builtin)' do
      allow(@path_validator).to receive(:filepath?).with('builtin_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).and_return(false)

      result = @projectinator.lookup_mixins(
        mixins:         ['builtin_mixin'],
        load_paths:     ['support/mixins'],
        builtins:       builtins,
        yaml_extension: yaml_extension
      )
      expect(result).to eq(['builtin_mixin'])
    end

    it 'preserves input ordering across a mix of filepaths and simple names' do
      allow(@path_validator).to receive(:filepath?).with('explicit.yml').and_return(true)
      allow(@path_validator).to receive(:filepath?).with('named_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('support/named_mixin.yml').and_return(true)

      result = @projectinator.lookup_mixins(
        mixins:         ['explicit.yml', 'named_mixin'],
        load_paths:     ['support'],
        builtins:       builtins,
        yaml_extension: yaml_extension
      )
      expect(result).to eq(['explicit.yml', 'support/named_mixin.yml'])
    end
  end

  # =========================================================================
  describe '#validate_mixins' do
    let(:builtins)       { {:builtin_mixin => {:foo => :bar}} }
    let(:yaml_extension) { '.yml' }

    it 'returns true for a mixin filepath that exists' do
      allow(@path_validator).to receive(:filepath?).with('path/to/mixin.yml').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('path/to/mixin.yml').and_return(true)

      result = @projectinator.validate_mixins(
        mixins:         ['path/to/mixin.yml'],
        load_paths:     [],
        builtins:       builtins,
        source:         'Test',
        yaml_extension: yaml_extension
      )
      expect(result).to be true
    end

    it 'returns false and logs an error for a mixin filepath that does not exist' do
      allow(@path_validator).to receive(:filepath?).with('missing/mixin.yml').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('missing/mixin.yml').and_return(false)

      expect(@loginator).to receive(:log).with(
        /cannot find mixin at missing\/mixin\.yml/i,
        anything
      )

      result = @projectinator.validate_mixins(
        mixins:         ['missing/mixin.yml'],
        load_paths:     [],
        builtins:       builtins,
        source:         'Test',
        yaml_extension: yaml_extension
      )
      expect(result).to be false
    end

    it 'returns true for a simple mixin name found in a load_path' do
      allow(@path_validator).to receive(:filepath?).with('my_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).with('support/my_mixin.yml').and_return(true)

      result = @projectinator.validate_mixins(
        mixins:         ['my_mixin'],
        load_paths:     ['support'],
        builtins:       builtins,
        source:         'Test',
        yaml_extension: yaml_extension
      )
      expect(result).to be true
    end

    it 'returns true for a simple mixin name matching a builtin key' do
      allow(@path_validator).to receive(:filepath?).with('builtin_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).and_return(false)

      result = @projectinator.validate_mixins(
        mixins:         ['builtin_mixin'],
        load_paths:     [],
        builtins:       builtins,
        source:         'Test',
        yaml_extension: yaml_extension
      )
      expect(result).to be true
    end

    it 'returns false and logs an error for a simple name not found anywhere' do
      allow(@path_validator).to receive(:filepath?).with('unknown_mixin').and_return(false)
      allow(@file_wrapper).to receive(:exist?).and_return(false)

      expect(@loginator).to receive(:log).with(
        /cannot be found/i,
        anything
      )

      result = @projectinator.validate_mixins(
        mixins:         ['unknown_mixin'],
        load_paths:     ['support'],
        builtins:       builtins,
        source:         'Test',
        yaml_extension: yaml_extension
      )
      expect(result).to be false
    end

    it 'returns false when any entry in a mixed list fails validation' do
      allow(@path_validator).to receive(:filepath?).with('good/mixin.yml').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('good/mixin.yml').and_return(true)

      allow(@path_validator).to receive(:filepath?).with('bad/mixin.yml').and_return(true)
      allow(@file_wrapper).to receive(:exist?).with('bad/mixin.yml').and_return(false)

      allow(@loginator).to receive(:log)

      result = @projectinator.validate_mixins(
        mixins:         ['good/mixin.yml', 'bad/mixin.yml'],
        load_paths:     [],
        builtins:       builtins,
        source:         'Test',
        yaml_extension: yaml_extension
      )
      expect(result).to be false
    end
  end
end
