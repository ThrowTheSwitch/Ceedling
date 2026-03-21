# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/partials/partializer_config'

describe PartializerConfig do

  it "defines MACRO_NAMES with the expected 8 macro name strings" do
    expect( PartializerConfig::MACRO_NAMES ).to include(
      'TEST_PARTIAL_PUBLIC_MODULE',
      'TEST_PARTIAL_PRIVATE_MODULE',
      'MOCK_PARTIAL_PUBLIC_MODULE',
      'MOCK_PARTIAL_PRIVATE_MODULE',
      'TEST_PARTIAL_MODULE',
      'MOCK_PARTIAL_MODULE',
      'TEST_PARTIAL_CONFIG',
      'MOCK_PARTIAL_CONFIG'
    )
    expect( PartializerConfig::MACRO_NAMES.size ).to eq 8
  end

end
