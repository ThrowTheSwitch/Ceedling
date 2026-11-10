# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/loginator'

describe Loginator do
  before(:each) do
    @loginator = described_class.new( verbosinator: double( 'verbosinator' ), system_wrapper: nil )
  end

  describe '#sanitize' do
    # Guidance such as the build step doctor's prescriptions writes bullets and
    # configuration paths with these characters, relying on this swap
    it 'swaps bullets and sub-entry arrows for plain characters when decorators are off' do
      text = "NOTE:\n• One\n• :project ↳ :defines\n"

      expect( @loginator.sanitize( text.dup, false ) ).to eq( "NOTE:\n* One\n* :project >> :defines\n" )
    end

    it 'leaves them in place when decorators are on' do
      text = "• :project ↳ :defines\n"

      expect( @loginator.sanitize( text.dup, true ) ).to eq( text )
    end
  end
end
