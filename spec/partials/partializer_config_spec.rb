# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_macros'
require 'ceedling/partials/partials'
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

  context "#extract_configs" do
    before(:each) do
      code_text          = CExtractorCodeText.new
      c_extractor_macros = CExtractorMacros.new({ c_extractor_code_text: code_text })
      @config = described_class.new({ c_extractor_macros: c_extractor_macros })
    end

    it "extracts configs from a raw IO object" do
      io = StringIO.new('TEST_PARTIAL_PUBLIC_MODULE(widget)')
      result = @config.extract_configs(io)
      expect( result['widget'].tests.types ).to eq [Partials::PUBLIC]
    end
  end

  context "#extract_configs_from_string" do

    before(:each) do
      code_text          = CExtractorCodeText.new
      c_extractor_macros = CExtractorMacros.new({ c_extractor_code_text: code_text })
      @config = described_class.new({ c_extractor_macros: c_extractor_macros })
    end

    def extract(str)
      @config.extract_configs_from_string(str)
    end

    # --- Empty / no-match ---

    it "returns empty hash for empty input" do
      expect( extract('') ).to eq({})
    end

    it "returns empty hash when no matching macros are present" do
      expect( extract('int x = UNRELATED(42);') ).to eq({})
    end

    # --- MODULE macros: types ---

    it "extracts TEST_PARTIAL_PUBLIC_MODULE and sets tests.types to PUBLIC" do
      result = extract('TEST_PARTIAL_PUBLIC_MODULE(calculator)')
      expect( result.keys ).to eq ['calculator']
      expect( result['calculator'].tests.types ).to eq [Partials::PUBLIC]
      expect( result['calculator'].mocks.types ).to eq []
    end

    it "extracts TEST_PARTIAL_PRIVATE_MODULE and sets tests.types to PRIVATE" do
      result = extract('TEST_PARTIAL_PRIVATE_MODULE(calculator)')
      expect( result['calculator'].tests.types ).to eq [Partials::PRIVATE]
      expect( result['calculator'].mocks.types ).to eq []
    end

    it "extracts MOCK_PARTIAL_PUBLIC_MODULE and sets mocks.types to PUBLIC" do
      result = extract('MOCK_PARTIAL_PUBLIC_MODULE(calculator)')
      expect( result['calculator'].mocks.types ).to eq [Partials::PUBLIC]
      expect( result['calculator'].tests.types ).to eq []
    end

    it "extracts MOCK_PARTIAL_PRIVATE_MODULE and sets mocks.types to PRIVATE" do
      result = extract('MOCK_PARTIAL_PRIVATE_MODULE(calculator)')
      expect( result['calculator'].mocks.types ).to eq [Partials::PRIVATE]
      expect( result['calculator'].tests.types ).to eq []
    end

    # --- TEST/MOCK_PARTIAL_MODULE: types empty, additions required ---

    it "accepts TEST_PARTIAL_MODULE when accompanied by TEST_PARTIAL_CONFIG additions" do
      input = <<~C
        TEST_PARTIAL_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, add, subtract)
      C
      result = extract(input)
      expect( result['calculator'].tests.types ).to eq []
      expect( result['calculator'].tests.additions ).to eq ['add', 'subtract']
    end

    it "accepts MOCK_PARTIAL_MODULE when accompanied by MOCK_PARTIAL_CONFIG subtractions" do
      input = <<~C
        MOCK_PARTIAL_MODULE(calculator)
        MOCK_PARTIAL_CONFIG(calculator, -multiply)
      C
      result = extract(input)
      expect( result['calculator'].mocks.types ).to eq []
      expect( result['calculator'].mocks.subtractions ).to eq ['multiply']
    end

    it "raises an exception for TEST_PARTIAL_MODULE with no accompanying CONFIG" do
      expect {
        extract('TEST_PARTIAL_MODULE(calculator)')
      }.to raise_error(CeedlingException, /calculator/)
    end

    # --- Type accumulation ---

    it "accumulates types without duplicates when same MODULE macro appears twice" do
      input = "TEST_PARTIAL_PUBLIC_MODULE(calc) TEST_PARTIAL_PUBLIC_MODULE(calc)"
      result = extract(input)
      expect( result['calc'].tests.types ).to eq [Partials::PUBLIC]
    end

    it "accumulates PUBLIC and PRIVATE types for the same module from different MODULE macros" do
      input = <<~C
        TEST_PARTIAL_PUBLIC_MODULE(calc)
        TEST_PARTIAL_PRIVATE_MODULE(calc)
      C
      result = extract(input)
      expect( result['calc'].tests.types ).to include(Partials::PUBLIC, Partials::PRIVATE)
    end

    # --- Multiple modules ---

    it "creates separate Config entries for different modules" do
      input = <<~C
        TEST_PARTIAL_PUBLIC_MODULE(module_a)
        MOCK_PARTIAL_PUBLIC_MODULE(module_b)
      C
      result = extract(input)
      expect( result.keys ).to contain_exactly('module_a', 'module_b')
      expect( result['module_a'].tests.types ).to eq [Partials::PUBLIC]
      expect( result['module_b'].mocks.types ).to eq [Partials::PUBLIC]
    end

    # --- CONFIG: additions and subtractions ---

    it "splits bare, +, and - function names into additions and subtractions" do
      input = <<~C
        TEST_PARTIAL_PUBLIC_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, add, +subtract, -multiply)
      C
      result = extract(input)
      expect( result['calculator'].tests.additions    ).to contain_exactly('add', 'subtract')
      expect( result['calculator'].tests.subtractions ).to eq ['multiply']
    end

    it "populates mocks.additions and mocks.subtractions from MOCK_PARTIAL_CONFIG" do
      input = <<~C
        MOCK_PARTIAL_PUBLIC_MODULE(driver)
        MOCK_PARTIAL_CONFIG(driver, +read, -write)
      C
      result = extract(input)
      expect( result['driver'].mocks.additions    ).to eq ['read']
      expect( result['driver'].mocks.subtractions ).to eq ['write']
    end

    # --- Quoted function names ---

    it "strips double-quotes from quoted function names and applies prefix logic" do
      input = <<~C
        TEST_PARTIAL_PUBLIC_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, "add", "+subtract", "-multiply")
      C
      result = extract(input)
      expect( result['calculator'].tests.additions    ).to contain_exactly('add', 'subtract')
      expect( result['calculator'].tests.subtractions ).to eq ['multiply']
    end

    # --- CONFIG referencing unknown module ---

    it "raises an exception when CONFIG macro references a module not declared by a MODULE macro" do
      expect {
        extract('TEST_PARTIAL_CONFIG(unknown_module, add)')
      }.to raise_error(CeedlingException, /TEST_PARTIAL_CONFIG.*unknown_module/)
    end

    it "includes the CONFIG macro name in the exception message" do
      expect {
        extract('MOCK_PARTIAL_CONFIG(ghost, +func)')
      }.to raise_error(CeedlingException, /MOCK_PARTIAL_CONFIG/)
    end

    # --- Complete round-trip ---

    it "handles a complete source snippet with MODULE and CONFIG macros together" do
      input = <<~C
        #include "calculator.h"

        TEST_PARTIAL_PUBLIC_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, +add, -internal_helper)

        MOCK_PARTIAL_PRIVATE_MODULE(driver)
        MOCK_PARTIAL_CONFIG(driver, write, -debug_write)

        void some_function(void) {}
      C
      result = extract(input)

      expect( result.keys ).to contain_exactly('calculator', 'driver')

      expect( result['calculator'].module ).to eq 'calculator'
      expect( result['calculator'].tests.types        ).to eq [Partials::PUBLIC]
      expect( result['calculator'].tests.additions    ).to eq ['add']
      expect( result['calculator'].tests.subtractions ).to eq ['internal_helper']
      expect( result['calculator'].mocks.types        ).to eq []
      expect( result['calculator'].mocks.additions    ).to eq []
      expect( result['calculator'].mocks.subtractions ).to eq []

      expect( result['driver'].module ).to eq 'driver'
      expect( result['driver'].mocks.types        ).to eq [Partials::PRIVATE]
      expect( result['driver'].mocks.additions    ).to eq ['write']
      expect( result['driver'].mocks.subtractions ).to eq ['debug_write']
      expect( result['driver'].tests.types        ).to eq []
    end

  end

end
