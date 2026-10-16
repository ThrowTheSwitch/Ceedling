# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/test_invoker/test_search_paths'
require 'ceedling/test_invoker/test_invoker_types'

describe TestSearchPaths do
  before(:each) do
    @configurator           = double( "Configurator" )
    @include_pathinator     = double( "IncludePathinator" )
    @test_context_extractor = double( "TestContextExtractor" )

    allow(@include_pathinator).to receive(:lookup_test_directive_include_paths).and_return( [] )
    allow(@include_pathinator).to receive(:collect_test_include_paths).and_return( [] )
    allow(@test_context_extractor).to receive(:lookup_partials_config).and_return( {} )
    %i[support include libraries vendor test_toolchain_include].each do |kind|
      allow(@configurator).to receive(:"collection_paths_#{kind}").and_return( [] )
    end

    @search_paths = described_class.new(
      configurator: @configurator, include_pathinator: @include_pathinator, test_context_extractor: @test_context_extractor
    )
  end

  describe "#compose" do
    it "includes a mocked header's own mirrored directory alongside the flat mock root" do
      result = @search_paths.compose( 'test/TestFoo.c', { mocks: 'build/test/mocks/a_test' }, ['build/test/mocks/a_test/drivers'] )

      expect(result).to eq( ['build/test/mocks/a_test', 'build/test/mocks/a_test/drivers'] )
    end

    it "carries only the flat mock root when no mock needs a mirrored directory of its own" do
      expect(@search_paths.compose( 'test/TestFoo.c', { mocks: 'build/test/mocks/a_test' } )).to eq( ['build/test/mocks/a_test'] )
    end

    # The compiler searches in this order, so a generated mock or Partial shadows the real
    # header it stands in for
    it "orders generated directories, then TEST_INCLUDE_PATH(), then configured paths" do
      allow(@include_pathinator).to receive(:lookup_test_directive_include_paths).with( 'test/TestFoo.c' ).and_return( ['directive'] )
      allow(@include_pathinator).to receive(:collect_test_include_paths).and_return( ['test_include'] )
      allow(@test_context_extractor).to receive(:lookup_partials_config).with( 'test/TestFoo.c' ).and_return( { 'drivers/uart' => {} } )
      %i[support include libraries vendor test_toolchain_include].each do |kind|
        allow(@configurator).to receive(:"collection_paths_#{kind}").and_return( [kind.to_s] )
      end
      paths = { mocks: 'mocks', partials: 'partials' }

      expect(@search_paths.compose( 'test/TestFoo.c', paths, ['mocks/drivers'] )).to eq( %w[
        mocks mocks/drivers partials partials/drivers directive test_include
        support include libraries vendor test_toolchain_include
      ] )
    end

    it "adds no Partial directory for a module named without one" do
      allow(@test_context_extractor).to receive(:lookup_partials_config).and_return( { 'uart' => {} } )

      expect(@search_paths.compose( 'test/TestFoo.c', { partials: 'partials' } )).to eq( ['partials'] )
    end

    it "lists each path once" do
      allow(@configurator).to receive(:collection_paths_include).and_return( ['src', 'src'] )
      allow(@configurator).to receive(:collection_paths_support).and_return( ['src'] )

      expect(@search_paths.compose( 'test/TestFoo.c', {} )).to eq( ['src'] )
    end
  end

  describe "#assign_mock_search_paths" do
    it "sets a test's mock search paths and composes its search paths around them" do
      testable = TestInvokerTypes::Testable.new(
        filepath: 'test/TestFoo.c', paths: { mocks: 'mocks' }, mock_search_paths: ['mocks/old'], search_paths: ['mocks', 'mocks/old']
      )

      @search_paths.assign_mock_search_paths( testable, ['mocks/drivers'], Mutex.new )

      expect(testable.mock_search_paths).to eq( ['mocks/drivers'] )
      expect(testable.search_paths).to eq( ['mocks', 'mocks/drivers'] )
    end
  end
end
