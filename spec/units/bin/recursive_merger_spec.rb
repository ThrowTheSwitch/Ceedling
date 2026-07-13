# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'recursive_merger'

describe RecursiveMerger do
  # Helper: merge mixin into a fresh copy of config and return result
  def merge(config, mixin)
    RecursiveMerger.merge!(config, mixin)
    config
  end

  # =========================================================================
  describe '.merge! — non-overlapping keys' do
    it 'adds mixin key to config when config does not have that key' do
      config = {a: 1}
      mixin  = {b: 2}
      expect(merge(config, mixin)).to eq({a: 1, b: 2})
    end

    it 'adds mixin list key to config when config does not have that key' do
      config = {}
      mixin  = {paths: ['mixin/include']}
      expect(merge(config, mixin)).to eq({paths: ['mixin/include']})
    end

    it 'adds mixin single-value key to config when config does not have that key' do
      config = {}
      mixin  = {name: 'value'}
      expect(merge(config, mixin)).to eq({name: 'value'})
    end
  end

  # =========================================================================
  describe '.merge! — single value replaces single value' do
    it 'replaces a string config value with the mixin string value' do
      config = {build_root: 'old'}
      mixin  = {build_root: 'new'}
      expect(merge(config, mixin)).to eq({build_root: 'new'})
    end

    it 'replaces a symbol config value with the mixin symbol value' do
      config = {flag: :off}
      mixin  = {flag: :on}
      expect(merge(config, mixin)).to eq({flag: :on})
    end

    it 'replaces a numeric config value with the mixin numeric value' do
      config = {threads: 1}
      mixin  = {threads: 4}
      expect(merge(config, mixin)).to eq({threads: 4})
    end
  end

  # =========================================================================
  describe '.merge! — nested hash recursion' do
    it 'merges non-overlapping keys inside a nested hash' do
      config = {project: {build_root: 'build'}}
      mixin  = {project: {threads: 4}}
      expect(merge(config, mixin)).to eq({project: {build_root: 'build', threads: 4}})
    end

    it 'replaces a single value inside a nested hash when both sides have the same key' do
      config = {project: {build_root: 'old', threads: 1}}
      mixin  = {project: {build_root: 'new'}}
      expect(merge(config, mixin)).to eq({project: {build_root: 'new', threads: 1}})
    end

    it 'recurses into multiply-nested hashes' do
      config = {a: {b: {c: 'old'}}}
      mixin  = {a: {b: {c: 'new', d: 'added'}}}
      expect(merge(config, mixin)).to eq({a: {b: {c: 'new', d: 'added'}}})
    end
  end

  # =========================================================================
  describe '.merge! — list + list (general rule: mixin entries prepended)' do
    it 'prepends single mixin list entry before config list entry' do
      config = {paths: ['base']}
      mixin  = {paths: ['override']}
      expect(merge(config, mixin)).to eq({paths: ['override', 'base']})
    end

    it 'prepends multiple mixin list entries before config list entries' do
      config = {paths: ['c']}
      mixin  = {paths: ['a', 'b']}
      expect(merge(config, mixin)).to eq({paths: ['a', 'b', 'c']})
    end

    it 'prepends mixin list into an empty config list' do
      config = {paths: []}
      mixin  = {paths: ['a', 'b']}
      expect(merge(config, mixin)).to eq({paths: ['a', 'b']})
    end

    it 'produces only config entries when mixin list is empty' do
      config = {paths: ['a', 'b']}
      mixin  = {paths: []}
      expect(merge(config, mixin)).to eq({paths: ['a', 'b']})
    end

    it 'prepends mixin list in a deep non-tools path' do
      config = {defines: {test: {:'*' => ['SIMULATE', 'TEST']}}}
      mixin  = {defines: {test: {:'*' => ['PROJECT_FEATURE_X']}}}
      expect(merge(config, mixin)).to eq(
        {defines: {test: {:'*' => ['PROJECT_FEATURE_X', 'SIMULATE', 'TEST']}}}
      )
    end

    it 'prepends mixin list for a sibling key of :arguments under :tools' do
      # :flags is NOT :arguments so the general (prepend) rule applies
      config = {tools: {test_compiler: {flags: ['-Wall']}}}
      mixin  = {tools: {test_compiler: {flags: ['-Werror']}}}
      expect(merge(config, mixin)).to eq(
        {tools: {test_compiler: {flags: ['-Werror', '-Wall']}}}
      )
    end
  end

  # =========================================================================
  describe '.merge! — list + list (:tools :name :arguments exception: entries appended)' do
    it 'appends mixin :arguments after config :arguments for a single tool' do
      config = {tools: {test_compiler: {arguments: ['-O2']}}}
      mixin  = {tools: {test_compiler: {arguments: ['-O0']}}}
      # -O0 must come AFTER -O2 so the compiler honours -O0
      expect(merge(config, mixin)).to eq(
        {tools: {test_compiler: {arguments: ['-O2', '-O0']}}}
      )
    end

    it 'appends multiple mixin :arguments after config :arguments' do
      config = {tools: {test_linker: {arguments: ['-lm']}}}
      mixin  = {tools: {test_linker: {arguments: ['-lpthread', '-ldl']}}}
      expect(merge(config, mixin)).to eq(
        {tools: {test_linker: {arguments: ['-lm', '-lpthread', '-ldl']}}}
      )
    end

    it 'appends mixin :arguments when config :arguments is empty' do
      config = {tools: {test_compiler: {arguments: []}}}
      mixin  = {tools: {test_compiler: {arguments: ['-O0']}}}
      expect(merge(config, mixin)).to eq(
        {tools: {test_compiler: {arguments: ['-O0']}}}
      )
    end

    it 'does NOT treat a key at [:tools, :name, :other] as the exception' do
      # Only :arguments at path depth 3 triggers the exception
      config = {tools: {test_compiler: {other: ['a']}}}
      mixin  = {tools: {test_compiler: {other: ['b']}}}
      expect(merge(config, mixin)).to eq(
        {tools: {test_compiler: {other: ['b', 'a']}}}
      )
    end
  end

  # =========================================================================
  describe '.merge! — single mixin value merged into config list' do
    it 'prepends mixin single string value into config list' do
      config = {foo: ['bar', 'baz']}
      mixin  = {foo: 'high'}
      expect(merge(config, mixin)).to eq({foo: ['high', 'bar', 'baz']})
    end

    it 'prepends mixin symbol value into config list' do
      config = {foo: [:a, :b]}
      mixin  = {foo: :high}
      expect(merge(config, mixin)).to eq({foo: [:high, :a, :b]})
    end

    it 'prepends mixin hash value into config list' do
      config = {items: ['a', :b]}
      mixin  = {items: {key: 'val'}}
      expect(merge(config, mixin)).to eq({items: [{key: 'val'}, 'a', :b]})
    end

    it 'prepends mixin single value into an empty config list' do
      config = {foo: []}
      mixin  = {foo: 'only'}
      expect(merge(config, mixin)).to eq({foo: ['only']})
    end
  end

  # =========================================================================
  describe '.merge! — config single value replaced by mixin list' do
    it 'replaces config single value with mixin list' do
      config = {foo: 'scalar'}
      mixin  = {foo: ['a', 'b']}
      # Type mismatch flagged by validate_merge(); mixin wins per RecursiveMerger
      expect(merge(config, mixin)).to eq({foo: ['a', 'b']})
    end
  end

  # =========================================================================
  describe '.merge! — mixin hash replaces config non-hash (non-list)' do
    it 'replaces a config string value with a mixin hash' do
      config = {a: 'scalar'}
      mixin  = {a: {b: 1}}
      expect(merge(config, mixin)).to eq({a: {b: 1}})
    end
  end

  # =========================================================================
  describe '.merge! — realistic project configuration scenarios' do
    it 'merges a project config with a mixin adding new keys and prepending include paths' do
      config = {
        project: {build_root: 'build', test_file_prefix: 'test_'},
        paths:   {include: ['src/include']}
      }
      mixin = {
        project: {test_threads: 4},
        paths:   {include: ['vendor/include']}
      }
      result = merge(config, mixin)
      expect(result[:project]).to eq({build_root: 'build', test_file_prefix: 'test_', test_threads: 4})
      # Mixin include path appears first — searched before project include path
      expect(result[:paths][:include]).to eq(['vendor/include', 'src/include'])
    end

    it 'correctly orders two sequential merges simulating config then cmdline mixin' do
      # Simulate: base → config_mixin → cmdline_mixin (cmdline has highest priority)
      config = {project: {build_root: 'base'}, paths: {include: ['base/include']}}

      config_mixin  = {project: {build_root: 'config_root'}, paths: {include: ['config/include']}}
      cmdline_mixin = {project: {build_root: 'cmdline_root'}, paths: {include: ['cmdline/include']}}

      RecursiveMerger.merge!(config, config_mixin)
      RecursiveMerger.merge!(config, cmdline_mixin)

      # cmdline_mixin is merged last, so its single value wins
      expect(config[:project][:build_root]).to eq('cmdline_root')
      # cmdline paths are prepended last, so they appear first in the combined list
      expect(config[:paths][:include]).to eq(['cmdline/include', 'config/include', 'base/include'])
    end
  end
end
