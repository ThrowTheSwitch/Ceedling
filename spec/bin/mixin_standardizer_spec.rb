# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'mixin_standardizer'
require 'ceedling/reportinator'

describe MixinStandardizer do
  before(:each) do
    @standardizer = described_class.new(
      {
        # Use real Reportinator for `generate_config_walk()`
        :reportinator => Reportinator.new()
      }
    )
  end

  context "#smart_standardize" do
    it "should leave sections other than :defines and :flags alone" do
      notices = []

      config = {
        :project => {
          :build_root => 'build',
          :test_file_prefix => 'Test'
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
        :plugins => {
          :enabled => [
            'module_generator',
            'command_hooks'
          ]
        }
      }

      # Unchanged after standardizing
      expected_config = config.clone()
      expected_mixin = mixin.clone()

      # No modifications
      expect( @standardizer.smart_standardize( config:config, mixin:mixin, notices:notices ) ).to eq false

      # Expected unchanged config and mixing
      expect( config ).to eq expected_config
      expect( mixin ).to eq expected_mixin

      # No notices
      expect( notices ).to eq []
    end
  end

  context "#smart_standardize" do
    it "should leave merge-compatible :defines and :flags alone" do
      notices = []

      config = {
        :defines => {
          :test => {
            :* => [
              'SIMULATE',
              'TEST'
            ]
          }
        },
        :flags => {
          :test => {
            :compile => ['-std=c99']
          }
        }
      }

      mixin = {
        :defines => {
          :test => {
            :* => ['PROJECT_FEATURE_X']
          }
        },
        :flags => {
          :test => {
            :compile => ['-pedantic']
          }
        }
      }

      # Unchanged after standardizing
      expected_config = config.clone()
      expected_mixin = mixin.clone()

      # No modifications
      expect( @standardizer.smart_standardize( config:config, mixin:mixin, notices:notices ) ).to eq false

      # Expected unchanged config and mixing
      expect( config ).to eq expected_config
      expect( mixin ).to eq expected_mixin

      # No notices
      expect( notices ).to eq []
    end
  end

  context "#smart_standardize" do
    it "should standardize :defines and :flags matchers" do
      notices = []

      config = {
        :defines => {
          :test => {
            :* => [
              'SIMULATE',
              'TEST'
            ]
          }
        },
        :flags => {
          :test => {
            :compile => ['-std=c99']
          }
        }
      }

      mixin = {
        :defines => {
          :test => ['PROJECT_FEATURE_X']
        },
        :flags => {
          :test => {
            :compile => {
              :* => ['-pedantic']
            }
          }
        }
      }

      expected_config = {
        :defines => {
          :test => {
            :* => [
              'SIMULATE',
              'TEST'
            ]
          }
        },
        :flags => {
          :test => {
            :compile => {
              :* => ['-std=c99']
            }
          }
        }
      }

      expected_mixin = {
        :defines => {
          :test => {
            :* => ['PROJECT_FEATURE_X']
          }
        },
        :flags => {
          :test => {
            :compile => {
              :* => ['-pedantic']
            }
          }
        }
      }

      # Modifications
      expect( @standardizer.smart_standardize( config:config, mixin:mixin, notices:notices ) ).to eq true

      # Expected changed config and mixing
      expect( config ).to eq expected_config
      expect( mixin ).to eq expected_mixin

      # Notices
      expect( notices[0] ).to match( /Converted mixin list to matcher hash/i )
      expect( notices[1] ).to match( /Converted configuration list to matcher hash/i )
    end
  end

end
