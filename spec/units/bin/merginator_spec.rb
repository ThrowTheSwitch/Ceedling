# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'merginator'
require 'recursive_merger'
require 'ceedling/reportinator'

describe Merginator do
  before(:each) do
    @merginator = described_class.new(
      {
        # Use real Reportinator for `generate_config_walk()`
        :reportinator => Reportinator.new()
      }
    )
  end

  context "#merge" do
    it "should merge non-overlapping configuration sections" do
      warnings = []

      config = {
        :foo => :bar
      }

      mixin = {
        :bar => :baz
      }

      expected = {
        :foo => :bar,
        :bar => :baz
      }

      # Successful merge
      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      # Expected `deep_merge!()` result
      expect( config ).to eq expected

      # No warnings
      expect( warnings ).to eq []
    end
  end

  context "#merge" do
    it "should merge overlapping configuration sections" do
      warnings = []

      config = {
        :foo => ['bar'],
        :bar => {
          :baz => 'baz'
        }
      }

      mixin = {
        :foo => ['baz'],
        :bar => {
          :foo => 'foo'
        }
      }

      expected = {
        :foo => ['baz', 'bar'],  # mixin list prepended before config list
        :bar => {
          :baz => 'baz',
          :foo => 'foo'
        }
      }

      # Successful merge
      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      expect( config ).to eq expected

      # No warnings
      expect( warnings ).to eq []
    end
  end

  context "#merge" do
    it "prepends mixin single value into config list" do
      warnings = []

      config = {
        :foo => ['bar', 'baz'],
        :empty => [],
        :eclectic => ['a', :b]
      }

      mixin = {
        :foo => 'bad',
        :empty => :not,
        :eclectic => {:d => 'd'}
      }

      expected = {
        :foo => ['bad', 'bar', 'baz'],        # mixin single value prepended before config list
        :empty => [:not],                      # mixin single value into empty list
        :eclectic => [{:d => 'd'}, 'a', :b]  # mixin hash-as-value prepended before config list
      }

      # Successful merge
      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      expect( config ).to eq expected

      # No warnings because merging any mixin value into a config list is allowed
      expect( warnings ).to eq []
    end
  end

  context "#merge" do
    it "prepends mixin list before config list for general list merges" do
      warnings = []

      config = {paths: {include: ['project/include']}}
      mixin  = {paths: {include: ['mixin/include']}}

      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      # Mixin include path appears first — searched before project include path
      expect( config[:paths][:include] ).to eq(['mixin/include', 'project/include'])
      expect( warnings ).to eq []
    end
  end

  context "#merge" do
    it "appends mixin :tools arguments to preserve compiler flag override order" do
      warnings = []

      config = {tools: {test_compiler: {arguments: ['-O2']}}}
      mixin  = {tools: {test_compiler: {arguments: ['-O0']}}}

      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      # -O0 must appear AFTER -O2 so the compiler honours the override
      expect( config[:tools][:test_compiler][:arguments] ).to eq(['-O2', '-O0'])
      expect( warnings ).to eq []
    end
  end

  context "#merge" do
    it "should complain about incompatible merges" do
      warnings = []

      config = {
        :a => {
          :b => {
            :c => 'c',
            :d => 'd',
            :e => :e,
            :f => {},
          }
        }
      }

      # We cannot merge an array into a primitive (only the other way around)
      mixin = {
        :a => {
          :b => {
            :c => ['c'],
            :d => :d,
            :e => 'e',
            :f => []
          }
        }
      }

      expected = {
        :a => {
          :b => {
            :c => ['c'],
            :d => :d,
            :e => 'e',
            :f => []
          }
        }
      }

      # Merging happens but validating it for lack of conflicts fails
      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq false

      expect( config ).to eq expected

      # Warnings
      expect( warnings[0] ).to match( /configuration has String.+Mixin has Array/i )
      expect( warnings[1] ).to match( /configuration has String.+Mixin has Symbol/i )
      expect( warnings[2] ).to match( /configuration has Symbol.+Mixin has String/i )
      expect( warnings[3] ).to match( /configuration has Hash.+Mixin has Array/i )
    end
  end

  context "#merge" do
    it "should merge representative project configuration and mixin" do
      warnings = []

      config = {
        :project => {
          :build_root => 'build',
          :test_file_prefix => 'Test'
        },
        :defines => {
          :test => {
            :* => [
              'SIMULATE',
              'TEST'
            ]
          }
        },
        :plugins => {
          :enabled => [
            'report_tests_pretty_stdout',
            'report_tests_log_factory'
          ]
        }
      }

      mixin = {
        :project => {
          :test_threads => 4,
          :compile_threads => 4
        },
        :defines => {
          :test => {
            :* => ['PROJECT_FEATURE_X']
          }
        },
        :plugins => {
          :enabled => [
            'module_generator',
            'command_hooks'
          ]
        }
      }

      expected = {
        :project => {
          :build_root => 'build',
          :test_file_prefix => 'Test',
          :test_threads => 4,
          :compile_threads => 4
        },
        :defines => {
          :test => {
            :* => [
              'PROJECT_FEATURE_X',  # mixin define prepended — appears first
              'SIMULATE',
              'TEST'
            ]
          }
        },
        :plugins => {
          :enabled => [
            'module_generator',    # mixin plugins prepended — appear first
            'command_hooks',
            'report_tests_pretty_stdout',
            'report_tests_log_factory'
          ]
        }
      }

      # Successful merge
      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      expect( config ).to eq expected

      # No warnings
      expect( warnings ).to eq []
    end
  end

end
