# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

# bin/versionator.rb (pulled in transitively by cli_helper.rb) uses bare `require`
# statements (`require 'exceptions'`, `require 'constants'`, `require 'version'`)
# that only resolve when lib/ceedling/ and lib/ are directly on the load path --
# true in the real bin/ceedling bootstrap (which adds lib/ceedling/ via
# CEEDLING_APPCFG[:ceedling_lib_path]) but not in this spec harness's load path
# setup. Add the same directories here so `require 'cli_helper'` succeeds.
here = File.dirname(__FILE__)
$: << File.join(here, '../../../lib/ceedling')
$: << File.join(here, '../../../lib')

require 'cli_helper'
require 'ceedling/ruby_expandinator'

# Scoped narrowly to #set_ruby_replacement, the new --ruby-replacement CLI flag
# wiring. Broader CliHelper coverage is a pre-existing gap outside this feature's
# scope (no spec file existed for this class before this feature).
describe CliHelper do
  before(:each) do
    @ruby_expandinator = RubyExpandinator.new

    @cli_helper = described_class.new({
      :file_wrapper       => double('file_wrapper').as_null_object,
      :actions_wrapper    => double('actions_wrapper').as_null_object,
      :config_walkinator  => double('config_walkinator').as_null_object,
      :path_validator     => double('path_validator').as_null_object,
      :rake_task_registry => double('rake_task_registry').as_null_object,
      :loginator          => double('loginator').as_null_object,
      :reportinator       => double('reportinator').as_null_object,
      :system_wrapper     => double('system_wrapper').as_null_object,
      :ruby_expandinator  => @ruby_expandinator,
    })
  end

  describe '#set_ruby_replacement' do
    it 'enables the feature when passed true' do
      @cli_helper.set_ruby_replacement( true )

      expect(@ruby_expandinator.enabled?).to eq(true)
    end

    it 'leaves the feature disabled when passed false' do
      @cli_helper.set_ruby_replacement( false )

      expect(@ruby_expandinator.enabled?).to eq(false)
    end

    it 'leaves the feature disabled when passed nil' do
      @cli_helper.set_ruby_replacement( nil )

      expect(@ruby_expandinator.enabled?).to eq(false)
    end

    it 'never disables an already-enabled feature' do
      @cli_helper.set_ruby_replacement( true )
      @cli_helper.set_ruby_replacement( false )

      expect(@ruby_expandinator.enabled?).to eq(true)
    end
  end
end
