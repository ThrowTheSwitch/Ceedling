# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_pipeline_helpers'

# A bare includer, exactly as any real pipeline stage class would mix this
# module in -- `dependency_meta` reads `@configurator` from whatever host
# object includes it, so this stand-in only needs that one ivar.
class TestPipelineHelpersIncluder
  include TestPipelineHelpers

  attr_accessor :configurator

  def initialize(configurator)
    @configurator = configurator
  end
end

describe TestPipelineHelpers do
  before(:each) do
    @configurator = double( "Configurator" )
    allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( false )

    @host = TestPipelineHelpersIncluder.new( @configurator )
  end

  describe "#dependency_meta" do
    it "returns flags, defines, and search paths given no other keyword" do
      meta = @host.dependency_meta( flags: ['-Wall'], defines: ['TEST'], search_paths: ['src'] )

      expect( meta[:flags] ).to eq( ['-Wall'] )
      expect( meta[:defines] ).to eq( ['TEST'] )
      expect( meta[:search_paths] ).to eq( ['src'] )
    end

    it "defaults tools to an empty list when not given" do
      meta = @host.dependency_meta( flags: [], defines: [], search_paths: [] )

      expect( meta[:tools] ).to eq( [] )
    end

    it "carries whatever tools list is given" do
      tool = { name: 'fake compiler' }
      meta = @host.dependency_meta( flags: [], defines: [], search_paths: [], tools: [tool] )

      expect( meta[:tools] ).to eq( [tool] )
    end

    it "defaults preprocess_force_fallback to the configurator's current setting when not given" do
      allow(@configurator).to receive(:test_build_preprocess_force_fallback).and_return( true )

      meta = @host.dependency_meta( flags: [], defines: [], search_paths: [] )

      expect( meta[:preprocess_force_fallback] ).to be(true)
    end

    it "carries an explicitly given preprocess_force_fallback instead of asking the configurator" do
      meta = @host.dependency_meta( flags: [], defines: [], search_paths: [], preprocess_force_fallback: true )

      expect( meta[:preprocess_force_fallback] ).to be(true)
    end

    it "omits :partials entirely when not given, rather than carrying a meaningless nil" do
      meta = @host.dependency_meta( flags: [], defines: [], search_paths: [] )

      expect( meta ).to_not have_key( :partials )
    end

    it "carries whatever :partials config is given" do
      partials_config = { max_extraction_length: 5000 }
      meta = @host.dependency_meta( flags: [], defines: [], search_paths: [], partials: partials_config )

      expect( meta[:partials] ).to eq( partials_config )
    end
  end
end
