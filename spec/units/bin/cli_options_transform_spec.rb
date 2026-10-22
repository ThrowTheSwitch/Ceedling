# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'cli_options_transform'

# Plain hashes stand in for Thor's options -- this module has no Thor
# dependency, matching the posture that CLI logic worth testing in isolation
# should be extractable from Thor configuration itself.
describe CliOptionsTransform do
  describe '.apply_debug_flag' do
    it 'forces Verbosity::DEBUG when the hidden --debug flag is set' do
      options = { debug: true, verbosity: Verbosity::NORMAL }

      result = described_class.apply_debug_flag( options )

      expect(result[:verbosity]).to eq( Verbosity::DEBUG )
    end

    it 'leaves an already-set :verbosity untouched when --debug is not set' do
      options = { debug: false, verbosity: Verbosity::OBNOXIOUS }

      result = described_class.apply_debug_flag( options )

      expect(result[:verbosity]).to eq( Verbosity::OBNOXIOUS )
    end

    it 'leaves a missing :verbosity as nil when --debug is not set' do
      options = { debug: false }

      result = described_class.apply_debug_flag( options )

      expect(result[:verbosity]).to be_nil
    end

    it 'returns the same Hash it was given' do
      options = { debug: false }

      result = described_class.apply_debug_flag( options )

      expect(result).to equal( options )
    end
  end
end
