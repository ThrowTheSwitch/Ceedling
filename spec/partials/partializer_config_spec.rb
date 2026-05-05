# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'spec_helper'
require 'ceedling/c_extractor/c_extractor_code_text'
require 'ceedling/c_extractor/c_extractor_preprocessing'
require 'ceedling/partials/partials'
require 'ceedling/partials/partializer_config'

describe PartializerConfig do

  it "defines MACRO_NAMES with the expected 10 macro name strings" do
    expect( PartializerConfig::MACRO_NAMES ).to include(
      'TEST_PARTIAL_PUBLIC_MODULE',
      'TEST_PARTIAL_PRIVATE_MODULE',
      'MOCK_PARTIAL_PUBLIC_MODULE',
      'MOCK_PARTIAL_PRIVATE_MODULE',
      'TEST_PARTIAL_MODULE',
      'MOCK_PARTIAL_MODULE',
      'TEST_PARTIAL_ALL_MODULE',
      'MOCK_PARTIAL_ALL_MODULE',
      'TEST_PARTIAL_CONFIG',
      'MOCK_PARTIAL_CONFIG'
    )
    expect( PartializerConfig::MACRO_NAMES.size ).to eq 10
  end

  context "#extract_configs" do
    before(:each) do
      code_text               = CExtractorCodeText.new
      c_extractor_preprocessing = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })
      @config = described_class.new({ c_extractor_preprocessing: c_extractor_preprocessing })
    end

    it "extracts configs from a raw IO object" do
      io = StringIO.new('TEST_PARTIAL_PUBLIC_MODULE(widget)')
      result = @config.extract_configs(io)
      expect( result['widget'].tests.type ).to eq Partials::PUBLIC
    end
  end

  context "#extract_configs_from_string" do

    before(:each) do
      code_text               = CExtractorCodeText.new
      c_extractor_preprocessing = CExtractorPreprocessing.new({ c_extractor_code_text: code_text })
      @config = described_class.new({ c_extractor_preprocessing: c_extractor_preprocessing })
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

    # --- MODULE macros: type ---

    it "extracts TEST_PARTIAL_PUBLIC_MODULE and sets tests.type to PUBLIC" do
      result = extract('TEST_PARTIAL_PUBLIC_MODULE(calculator)')
      expect( result.keys ).to eq ['calculator']
      expect( result['calculator'].tests.type ).to eq Partials::PUBLIC
      expect( result['calculator'].mocks.type ).to be_nil
    end

    it "extracts TEST_PARTIAL_PRIVATE_MODULE and sets tests.type to PRIVATE" do
      result = extract('TEST_PARTIAL_PRIVATE_MODULE(calculator)')
      expect( result['calculator'].tests.type ).to eq Partials::PRIVATE
      expect( result['calculator'].mocks.type ).to be_nil
    end

    it "extracts MOCK_PARTIAL_PUBLIC_MODULE and sets mocks.type to PUBLIC" do
      result = extract('MOCK_PARTIAL_PUBLIC_MODULE(calculator)')
      expect( result['calculator'].mocks.type ).to eq Partials::PUBLIC
      expect( result['calculator'].tests.type ).to be_nil
    end

    it "extracts MOCK_PARTIAL_PRIVATE_MODULE and sets mocks.type to PRIVATE" do
      result = extract('MOCK_PARTIAL_PRIVATE_MODULE(calculator)')
      expect( result['calculator'].mocks.type ).to eq Partials::PRIVATE
      expect( result['calculator'].tests.type ).to be_nil
    end

    # --- TEST/MOCK_PARTIAL_MODULE: ACCUMULATE ---

    it "extracts TEST_PARTIAL_MODULE and sets tests.type to ACCUMULATE" do
      input = <<~C
        TEST_PARTIAL_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, add, subtract)
      C
      result = extract(input)
      expect( result['calculator'].tests.type ).to eq Partials::ACCUMULATE
      expect( result['calculator'].tests.additions ).to eq ['add', 'subtract']
    end

    it "extracts MOCK_PARTIAL_MODULE and sets mocks.type to ACCUMULATE" do
      input = <<~C
        MOCK_PARTIAL_MODULE(calculator)
        MOCK_PARTIAL_CONFIG(calculator, +multiply)
      C
      result = extract(input)
      expect( result['calculator'].mocks.type ).to eq Partials::ACCUMULATE
      expect( result['calculator'].mocks.additions ).to eq ['multiply']
    end

    it "raises when TEST_PARTIAL_MODULE is used alone without any CONFIG additions" do
      expect {
        extract('TEST_PARTIAL_MODULE(calculator)')
      }.to raise_error(CeedlingException, /TEST_PARTIAL_MODULE/)
    end

    # --- TEST/MOCK_PARTIAL_ALL_MODULE: DEDUCT ---

    it "extracts TEST_PARTIAL_ALL_MODULE and sets tests.type to DEDUCT" do
      result = extract('TEST_PARTIAL_ALL_MODULE(calculator)')
      expect( result['calculator'].tests.type ).to eq Partials::DEDUCT
      expect( result['calculator'].mocks.type ).to be_nil
    end

    it "extracts MOCK_PARTIAL_ALL_MODULE and sets mocks.type to DEDUCT" do
      result = extract('MOCK_PARTIAL_ALL_MODULE(calculator)')
      expect( result['calculator'].mocks.type ).to eq Partials::DEDUCT
      expect( result['calculator'].tests.type ).to be_nil
    end

    it "does not raise when TEST_PARTIAL_ALL_MODULE is used alone without CONFIG (means all functions)" do
      expect { extract('TEST_PARTIAL_ALL_MODULE(calculator)') }.not_to raise_error
    end

    it "does not raise when MOCK_PARTIAL_ALL_MODULE is used alone without CONFIG (means all functions)" do
      expect { extract('MOCK_PARTIAL_ALL_MODULE(calculator)') }.not_to raise_error
    end

    it "extracts TEST_PARTIAL_ALL_MODULE with CONFIG subtractions" do
      input = <<~C
        TEST_PARTIAL_ALL_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, -internal_helper, -debug_only)
      C
      result = extract(input)
      expect( result['calculator'].tests.type        ).to eq Partials::DEDUCT
      expect( result['calculator'].tests.subtractions ).to contain_exactly('internal_helper', 'debug_only')
      expect( result['calculator'].tests.additions    ).to eq []
    end

    it "extracts MOCK_PARTIAL_ALL_MODULE with CONFIG subtractions" do
      input = <<~C
        MOCK_PARTIAL_ALL_MODULE(driver)
        MOCK_PARTIAL_CONFIG(driver, -write)
      C
      result = extract(input)
      expect( result['driver'].mocks.type        ).to eq Partials::DEDUCT
      expect( result['driver'].mocks.subtractions ).to eq ['write']
      expect( result['driver'].mocks.additions    ).to eq []
    end

    it "raises when additions are used with TEST DEDUCT" do
      input = <<~C
        TEST_PARTIAL_ALL_MODULE("foo")
        TEST_PARTIAL_CONFIG("foo", "+bar")
      C
      expect { extract(input) }.to raise_error(CeedlingException, /foo/)
    end

    it "raises when additions are used with MOCK DEDUCT" do
      input = <<~C
        MOCK_PARTIAL_ALL_MODULE("foo")
        MOCK_PARTIAL_CONFIG("foo", "baz", "-bar")
      C
      expect { extract(input) }.to raise_error(CeedlingException, /foo/)
    end

    it "does not raise when only subtractions are used with DEDUCT" do
      input = <<~C
        TEST_PARTIAL_ALL_MODULE("foo")
        TEST_PARTIAL_CONFIG("foo", "-a", "-b")
      C
      expect { extract(input) }.not_to raise_error
    end

    it "does not raise when CONFIG is present but has no function names (empty subtractions)" do
      # A CONFIG macro with only the module name and no function args is a degenerate but valid case
      input = <<~C
        TEST_PARTIAL_ALL_MODULE("foo")
        TEST_PARTIAL_CONFIG("foo")
      C
      expect { extract(input) }.not_to raise_error
    end

    it "allows TEST_PARTIAL_ALL_MODULE and MOCK_PARTIAL_PUBLIC_MODULE together for the same module" do
      input = <<~C
        TEST_PARTIAL_ALL_MODULE(widget)
        MOCK_PARTIAL_PUBLIC_MODULE(widget)
      C
      result = extract(input)
      expect( result['widget'].tests.type ).to eq Partials::DEDUCT
      expect( result['widget'].mocks.type ).to eq Partials::PUBLIC
    end

    # --- MODULE macro overwrite raises (extended to ALL_MODULE variants) ---

    it "raises when TEST_PARTIAL_ALL_MODULE and TEST_PARTIAL_MODULE both target the same module" do
      input = "TEST_PARTIAL_ALL_MODULE(calc) TEST_PARTIAL_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    it "raises when TEST_PARTIAL_ALL_MODULE and TEST_PARTIAL_PUBLIC_MODULE both target the same module" do
      input = "TEST_PARTIAL_ALL_MODULE(calc) TEST_PARTIAL_PUBLIC_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    it "raises when TEST_PARTIAL_ALL_MODULE and TEST_PARTIAL_PRIVATE_MODULE both target the same module" do
      input = "TEST_PARTIAL_ALL_MODULE(calc) TEST_PARTIAL_PRIVATE_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    it "raises when MOCK_PARTIAL_ALL_MODULE and MOCK_PARTIAL_MODULE both target the same module" do
      input = "MOCK_PARTIAL_ALL_MODULE(calc) MOCK_PARTIAL_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    it "raises when MOCK_PARTIAL_ALL_MODULE and MOCK_PARTIAL_PUBLIC_MODULE both target the same module" do
      input = "MOCK_PARTIAL_ALL_MODULE(calc) MOCK_PARTIAL_PUBLIC_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    it "raises when MOCK_PARTIAL_ALL_MODULE and MOCK_PARTIAL_PRIVATE_MODULE both target the same module" do
      input = "MOCK_PARTIAL_ALL_MODULE(calc) MOCK_PARTIAL_PRIVATE_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    # --- MODULE macro overwrite raises ---

    it "raises when the same MODULE macro is used twice for the same module" do
      input = "TEST_PARTIAL_PUBLIC_MODULE(calc) TEST_PARTIAL_PUBLIC_MODULE(calc)"
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    it "raises when multiple MODULE macros target the same tests entry for a module" do
      input = <<~C
        TEST_PARTIAL_PUBLIC_MODULE(calc)
        TEST_PARTIAL_PRIVATE_MODULE(calc)
      C
      expect { extract(input) }.to raise_error(CeedlingException, /calc/)
    end

    # --- Multiple modules ---

    it "creates separate Config entries for different modules" do
      input = <<~C
        TEST_PARTIAL_PUBLIC_MODULE(module_a)
        MOCK_PARTIAL_PUBLIC_MODULE(module_b)
      C
      result = extract(input)
      expect( result.keys ).to contain_exactly('module_a', 'module_b')
      expect( result['module_a'].tests.type ).to eq Partials::PUBLIC
      expect( result['module_b'].mocks.type ).to eq Partials::PUBLIC
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

    it "raises when tests are ACCUMULATE without CONFIG additions (even when mocks are PUBLIC)" do
      input = 'TEST_PARTIAL_MODULE("foo") MOCK_PARTIAL_PUBLIC_MODULE("foo")'
      expect { extract(input) }.to raise_error(CeedlingException, /TEST_PARTIAL_MODULE/)
    end

    it "does not raise when tests are PUBLIC and mocks are PRIVATE" do
      input = 'TEST_PARTIAL_PUBLIC_MODULE("foo") MOCK_PARTIAL_PRIVATE_MODULE("foo")'
      expect { extract(input) }.not_to raise_error
    end

    # --- Validation: subtractions illegal with ACCUMULATE ---

    it "raises when subtractions are used with TEST ACCUMULATE" do
      input = <<~C
        TEST_PARTIAL_MODULE("foo")
        TEST_PARTIAL_CONFIG("foo", "-bar")
      C
      expect { extract(input) }.to raise_error(CeedlingException, /foo/)
    end

    it "raises when subtractions are used with MOCK ACCUMULATE" do
      input = <<~C
        MOCK_PARTIAL_MODULE("foo")
        MOCK_PARTIAL_CONFIG("foo", "+baz", "-bar")
      C
      expect { extract(input) }.to raise_error(CeedlingException, /foo/)
    end

    it "does not raise when only additions are used with ACCUMULATE" do
      input = <<~C
        TEST_PARTIAL_MODULE("foo")
        TEST_PARTIAL_CONFIG("foo", "a", "+b")
      C
      expect { extract(input) }.not_to raise_error
    end

    # --- Complete round-trip ---

    it "handles a complete source snippet with MODULE and CONFIG macros together" do
      input = <<~C
        #include "calculator.h"

        TEST_PARTIAL_PUBLIC_MODULE(calculator)
        TEST_PARTIAL_CONFIG(calculator, +add, -internal_helper)

        MOCK_PARTIAL_PRIVATE_MODULE(driver)
        MOCK_PARTIAL_CONFIG(driver, write)

        void some_function(void) {}
      C
      result = extract(input)

      expect( result.keys ).to contain_exactly('calculator', 'driver')

      expect( result['calculator'].module ).to eq 'calculator'
      expect( result['calculator'].tests.type        ).to eq Partials::PUBLIC
      expect( result['calculator'].tests.additions    ).to eq ['add']
      expect( result['calculator'].tests.subtractions ).to eq ['internal_helper']
      expect( result['calculator'].mocks.type         ).to be_nil
      expect( result['calculator'].mocks.additions    ).to eq []
      expect( result['calculator'].mocks.subtractions ).to eq []

      expect( result['driver'].module ).to eq 'driver'
      expect( result['driver'].mocks.type         ).to eq Partials::PRIVATE
      expect( result['driver'].mocks.additions    ).to eq ['write']
      expect( result['driver'].mocks.subtractions ).to eq []
      expect( result['driver'].tests.type         ).to be_nil
    end

  end

end
