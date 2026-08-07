# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/config/configurator_setup'
require 'ceedling/reportinator'

# Only #validate_partials is covered here. The rest of ConfiguratorSetup has no unit spec
# at all today (its closest sibling, #validate_threads, is untested too) -- this file scopes
# itself to the new method rather than backfilling that existing gap.
describe ConfiguratorSetup do
  before(:each) do
    @configurator_builder   = double('ConfiguratorBuilder')
    @configurator_validator = double('ConfiguratorValidator')
    @configurator_plugins   = double('ConfiguratorPlugins')
    @loginator              = double('Loginator')
    @reportinator           = Reportinator.new
    @file_wrapper           = double('FileWrapper')

    @setup = described_class.new(
      {
        configurator_builder:   @configurator_builder,
        configurator_validator: @configurator_validator,
        configurator_plugins:   @configurator_plugins,
        loginator:              @loginator,
        reportinator:           @reportinator,
        file_wrapper:           @file_wrapper
      }
    )
  end

  context "#validate_partials" do
    it "accepts an integer at the minimum" do
      config = { partials: { max_extraction_length: 10 } }
      expect(@setup.validate_partials(config)).to be true
    end

    it "accepts an integer above the minimum" do
      config = { partials: { max_extraction_length: 5000 } }
      expect(@setup.validate_partials(config)).to be true
    end

    it "rejects a non-integer value" do
      config = { partials: { max_extraction_length: '5000' } }
      expect(@loginator).to receive(:log)
        .with(/:partials ↳ :max_extraction_length is not an integer/, Verbosity::ERRORS)
      expect(@setup.validate_partials(config)).to be false
    end

    it "rejects an integer below the minimum" do
      config = { partials: { max_extraction_length: 9 } }
      expect(@loginator).to receive(:log)
        .with(/:partials ↳ :max_extraction_length must be at least 10/, Verbosity::ERRORS)
      expect(@setup.validate_partials(config)).to be false
    end
  end
end
