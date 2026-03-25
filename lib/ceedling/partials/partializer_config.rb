# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'stringio'
require 'strscan'
require 'ceedling/partials/partials'
require 'ceedling/exceptions'

class PartializerConfig

  include Partials

  constructor :c_extractor_macros

  # Macro names for all partial configuration macros
  MACRO_NAMES = [
    'TEST_PARTIAL_PUBLIC_MODULE',
    'TEST_PARTIAL_PRIVATE_MODULE',
    'MOCK_PARTIAL_PUBLIC_MODULE',
    'MOCK_PARTIAL_PRIVATE_MODULE',
    'TEST_PARTIAL_MODULE',
    'MOCK_PARTIAL_MODULE',
    'TEST_PARTIAL_CONFIG',
    'MOCK_PARTIAL_CONFIG',
  ].freeze

  # Holds function-level extraction config for tests or mocks within a Partial.
  # types        -- visibility types (:public / :private) to include; empty means all
  # additions    -- function names to explicitly include
  # subtractions -- function names to explicitly exclude
  PartialFunctions = Struct.new(:types, :additions, :subtractions, keyword_init: true) do
    def initialize(types: [], additions: [], subtractions: [])
      super
    end

    def present?
      !types.empty? || !additions.empty? || !subtractions.empty?
    end
  end

  # Top-level Partial configuration for a single C module.
  Config = Struct.new(:module, :tests, :mocks, :header, :source, keyword_init: true) do
    def initialize(module:,
                   tests:  PartializerConfig::PartialFunctions.new,
                   mocks:  PartializerConfig::PartialFunctions.new,
                   header: Partials::ConfigFileInfo.new,
                   source: Partials::ConfigFileInfo.new)
      super
    end
  end

  # Extract partial configuration macros from a string.
  # Returns a hash of module_name => Config.
  def extract_configs_from_string(string)
    extract_configs( StringIO.new(string) )
  end

  # Extract partial configuration macros from a file.
  # Returns a hash of module_name => Config.
  def extract_configs_from_file(filepath)
    File.open(filepath) { |f| extract_configs(f) }
  end

  # Core three-pass extraction:
  #   Pass 1 — MODULE macros: build Config entries, set types
  #   Pass 2 — CONFIG macros: populate additions/subtractions
  #   Pass 3 — Validation: raise if any Config has no meaningful content
  def extract_configs(io)
    content = io.read
    scanner = StringScanner.new(content)
    calls   = @c_extractor_macros.try_extract_calls(scanner, MACRO_NAMES)

    configs      = {}  # module_name => Config
    config_calls = []  # deferred: [macro_name, params] for CONFIG macros

    # --- Pass 1: MODULE macros ---
    calls.each do |call_str|
      macro_name, params = @c_extractor_macros.parse_call(call_str)
      next if macro_name.nil?

      if macro_name.end_with?('_CONFIG')
        config_calls << [macro_name, params]
        next
      end

      mod = _strip_quotes(params[0])
      configs[mod] ||= Config.new(module: mod)

      case macro_name
      when 'TEST_PARTIAL_PUBLIC_MODULE'
        configs[mod].tests.types |= [PUBLIC]
      when 'TEST_PARTIAL_PRIVATE_MODULE'
        configs[mod].tests.types |= [PRIVATE]
      when 'MOCK_PARTIAL_PUBLIC_MODULE'
        configs[mod].mocks.types |= [PUBLIC]
      when 'MOCK_PARTIAL_PRIVATE_MODULE'
        configs[mod].mocks.types |= [PRIVATE]
      when 'TEST_PARTIAL_MODULE', 'MOCK_PARTIAL_MODULE'
        # types intentionally left empty — signals "all types"
        # Config entry is still created (handled by configs[mod] ||= above)
      end
    end
    puts(configs)
    # --- Pass 2: CONFIG macros ---
    config_calls.each do |macro_name, params|
      mod = _strip_quotes(params[0])
      unless configs.key?(mod)
        raise CeedlingException.new(
          "#{macro_name} references unknown module '#{mod}' -— no corresponding MODULE Partial macro directive found"
        )
      end

      target = macro_name.start_with?('TEST_') ? configs[mod].tests : configs[mod].mocks

      params[1..].each do |raw|
        name = _strip_quotes(raw)
        if name.start_with?('-')
          target.subtractions << name[1..]
        else
          target.additions << name.delete_prefix('+')
        end
      end
    end

    # --- Pass 3: Validation ---
    configs.each do |mod, config|
      unless config.tests.present? || config.mocks.present?
        raise CeedlingException.new(
          "Module '#{mod}' has partial macro(s) but no meaningful configuration (no types, additions, or subtractions)"
        )
      end
    end

    return configs
  end

  ### Private ###

  private

  # Strip a matched pair of double-quotes from str.
  # Returns str unchanged if it is not double-quoted.
  def _strip_quotes(str)
    return str unless str.length >= 2 && str.start_with?('"') && str.end_with?('"')
    str[1..-2]
  end

end
