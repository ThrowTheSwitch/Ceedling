# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'

# bin/versionator.rb (pulled in transitively by cli_handler.rb) uses bare `require`
# statements that only resolve when lib/ceedling/ and lib/ are directly on the load
# path -- true in the real bin/ceedling bootstrap but not in this spec harness's
# load path setup. Add the same directories here so `require 'cli_handler'` succeeds.
here = File.dirname(__FILE__)
$: << File.join(here, '../../../lib/ceedling')
$: << File.join(here, '../../../lib')

# cli_handler.rb requires 'mixins' before 'ceedling/constants', but bin/mixins.rb
# references UNITY_ROOT_PATH, a constant only defined by ceedling/constants. The
# real bin/ceedling bootstrap always loads ceedling/constants first, so this load
# order only ever bites a spec harness requiring cli_handler.rb directly.
require 'ceedling/constants'
require 'cli_handler'

# Scoped narrowly to #inspect for now. CliHandler's other public methods are
# still only exercised end-to-end through system tests; broader unit coverage
# is added separately.
describe CliHandler do
  before(:each) do
    @cli_handler = described_class.new({
      :composinator       => double('composinator').as_null_object,
      :projectinator      => double('projectinator').as_null_object,
      :cli_helper         => double('cli_helper').as_null_object,
      :path_validator     => double('path_validator').as_null_object,
      :rake_task_registry => double('rake_task_registry').as_null_object,
      :actions_wrapper    => double('actions_wrapper').as_null_object,
      :loginator          => double('loginator').as_null_object,
    })
  end

  describe '#inspect' do
    it 'returns the class name instead of dumping instance variables' do
      expect(@cli_handler.inspect).to eq('CliHandler')
    end
  end
end
