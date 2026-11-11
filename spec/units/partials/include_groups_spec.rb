# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/includes/includes'
require 'ceedling/partials/include_groups'

describe Partials::IncludeGroups do
  let(:boundary) { UserInclude.new( 'boundary' ) }
  let(:config)   { UserInclude.new( 'config.h' ) }
  let(:log)      { UserInclude.new( 'log.h' ) }

  context ".split" do
    it "puts what precedes the boundary first and what follows it after" do
      groups = described_class.split( [config, boundary, log], boundary )

      expect( [groups.leading, groups.following] ).to eq( [[config], [log]] )
    end

    # An equal include is not the boundary, so only the very object splits the list
    it "matches the boundary by identity" do
      groups = described_class.split( [UserInclude.new( 'boundary' ), boundary, log], boundary )

      expect( groups.leading.size ).to eq( 1 )
      expect( groups.following ).to eq( [log] )
    end
  end

  it "lists every include in order" do
    expect( described_class.new( leading: [config], following: [log] ).to_a ).to eq( [config, log] )
  end

  it "records each group as include directives" do
    expect( described_class.new( leading: [config], following: [log] ).to_record ).to eq(
      { leading: ['#include "config.h"'], following: ['#include "log.h"'] }
    )
  end
end
