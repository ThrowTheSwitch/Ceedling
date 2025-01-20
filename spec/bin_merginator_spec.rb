# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'merginator'
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
        :foo => :bar
      }

      expected = {
        :foo => :bar,
        :foo => :bar        
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
        :foo => ['bar', 'baz'],
        :bar => {
          :baz => 'baz',
          :foo => 'foo'
        }
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
    it "should merge mixin value into config array because of :extend_existing_arrays" do
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
        :foo => ['bar', 'baz', 'bad'],
        :empty => [:not],
        :eclectic => ['a', :b, {:d => 'd'}]
      }

      # Successful merge
      expect( @merginator.merge( config:config, mixin:mixin, warnings:warnings ) ).to eq true

      # Expected `deep_merge!()` result
      expect( config ).to eq expected

      # No warnings because merging a different type of a Mixin into a Config array is allowed
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

      # `deep_merge!()` replaces primitive with array
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

      # Expected `deep_merge!()` result
      expect( config ).to eq expected

      # Warnings
      expect( warnings[0] ).to match( /configuration has String.+Mixin has Array/i )
      expect( warnings[1] ).to match( /configuration has String.+Mixin has Symbol/i )
      expect( warnings[2] ).to match( /configuration has Symbol.+Mixin has String/i )
      expect( warnings[3] ).to match( /configuration has Hash.+Mixin has Array/i )
    end
  end

end
