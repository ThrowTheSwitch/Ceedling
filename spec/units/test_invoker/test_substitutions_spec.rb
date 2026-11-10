# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/constants'
require 'ceedling/test_invoker/test_invoker_types'
require 'ceedling/test_invoker/test_substitutions'

# Defined from project configuration at runtime
PROJECT_BUILD_VENDOR_UNITY_PATH      = 'build/vendor/unity'      unless defined?( PROJECT_BUILD_VENDOR_UNITY_PATH )
PROJECT_BUILD_VENDOR_CMOCK_PATH      = 'build/vendor/cmock'      unless defined?( PROJECT_BUILD_VENDOR_CMOCK_PATH )
PROJECT_BUILD_VENDOR_CEXCEPTION_PATH = 'build/vendor/cexception' unless defined?( PROJECT_BUILD_VENDOR_CEXCEPTION_PATH )

describe TestSubstitutions do
  before(:each) do
    @configurator = double( 'configurator', project_build_vendor_ceedling_path: 'build/vendor/ceedling' )
    @substitutions = described_class.new( configurator: @configurator )
    @testable = TestInvokerTypes::Testable.new( name: 'a_test', paths: { mocks: 'build/test/mocks/a_test', partials: 'build/test/partials/a_test' } )
  end

  def mock(source, partial: false)
    TestInvokerTypes::MockDetails.new( name: File.basename( source, '.h' ), source: source, partial: partial )
  end

  def partial_config(header_filepath)
    double( 'PartialConfig', header: double( 'HeaderFile', filepath: header_filepath ) )
  end

  describe '#real_headers' do
    it 'maps each mocked header\'s basename to its real path' do
      @testable.mocks = { gpio: mock( '/project/library/gpio.h' ), uart: mock( '/project/drivers/uart.h' ) }

      expect( @substitutions.real_headers( @testable ) ).to eq(
        'gpio.h' => '/project/library/gpio.h', 'uart.h' => '/project/drivers/uart.h'
      )
    end

    it 'maps each Partialized module\'s real header' do
      @testable.partials.configs = { moduleA: partial_config( '/project/src/moduleA.h' ) }

      expect( @substitutions.real_headers( @testable ) ).to eq( 'moduleA.h' => '/project/src/moduleA.h' )
    end

    it 'leaves out a mock Partial, whose source is a generated interface header' do
      @testable.mocks = { partial_mock: mock( 'build/test/partials/a_test/moduleA_interface.h', partial: true ) }

      expect( @substitutions.real_headers( @testable ) ).to eq( {} )
    end

    it 'leaves out a mock without a resolved source, and a Partial without a header' do
      @testable.mocks = { unresolved: TestInvokerTypes::MockDetails.new( name: 'x', partial: false ) }
      @testable.partials.configs = { moduleB: partial_config( nil ) }

      expect( @substitutions.real_headers( @testable ) ).to eq( {} )
    end

    it 'is empty for a testable with no mocks or Partials' do
      expect( @substitutions.real_headers( @testable ) ).to eq( {} )
    end
  end

  describe '#partialized?' do
    it 'tells a Partialized header from a mocked one' do
      @testable.mocks = { gpio: mock( '/project/library/gpio.h' ) }
      @testable.partials.configs = { moduleA: partial_config( '/project/src/moduleA.h' ) }

      expect( @substitutions.partialized?( @testable, '/project/src/moduleA.h' ) ).to be true
      expect( @substitutions.partialized?( @testable, '/project/library/gpio.h' ) ).to be false
    end
  end

  describe '#generated_dirs' do
    it 'lists the test\'s mocks and Partials directories and the vendor framework directories' do
      expect( @substitutions.generated_dirs( @testable ) ).to eq( [
        'build/test/mocks/a_test', 'build/test/partials/a_test',
        PROJECT_BUILD_VENDOR_UNITY_PATH, PROJECT_BUILD_VENDOR_CMOCK_PATH, PROJECT_BUILD_VENDOR_CEXCEPTION_PATH,
        'build/vendor/ceedling'
      ] )
    end

    it 'leaves out a directory the project does not have' do
      @testable.paths = {}

      expect( @substitutions.generated_dirs( @testable ) ).not_to include( nil )
    end
  end
end
