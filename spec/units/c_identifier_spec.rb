# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_identifier'

describe CIdentifier do
  describe '.fold' do
    it 'leaves a name that is already an identifier unchanged' do
      expect( CIdentifier.fold( 'sensor_2' ) ).to eq( 'sensor_2' )
    end

    it 'replaces each character an identifier cannot hold with an underscore' do
      expect( CIdentifier.fold( 'my-sensor.v2' ) ).to eq( 'my_sensor_v2' )
    end

    # One for one, so a test author can predict the folded name without knowing a rule
    # for runs
    it 'keeps a run of replaced characters as a run of underscores' do
      expect( CIdentifier.fold( 'a--b' ) ).to eq( 'a__b' )
    end

    it 'folds a path separator like any other character' do
      expect( CIdentifier.fold( 'drivers/uart\\config' ) ).to eq( 'drivers_uart_config' )
    end

    it 'folds a character outside ASCII to a single underscore' do
      expect( CIdentifier.fold( 'café' ) ).to eq( 'caf_' )
    end
  end
end
