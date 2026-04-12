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
require 'ceedling/c_extractor/c_extractor_preprocessing'

class PartializerConfig

  include Partials

  constructor :c_extractor_preprocessing

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
  # type         -- :public, :private, or :accumulate (additions-driven); nil if unset
  # additions    -- function names to explicitly include
  # subtractions -- function names to explicitly exclude (illegal with ACCUMULATE)
  PartialFunctions = Struct.new(:type, :additions, :subtractions, keyword_init: true) do
    def initialize(type: nil, additions: [], subtractions: [])
      super
    end

    def present?
      return false if type.nil?
      return false if type == ACCUMULATE && additions.empty?
      return true
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
    calls   = @c_extractor_preprocessing.try_extract_macro_calls(scanner, MACRO_NAMES)

    configs      = {}  # module_name => Config
    config_calls = []  # deferred: [macro_name, params] for CONFIG macros

    # --- Pass 1: MODULE macros ---
    calls.each do |call_str|
      macro_name, params = @c_extractor_preprocessing.parse_macro_call(call_str)
      next if macro_name.nil?

      if macro_name.end_with?('_CONFIG')
        config_calls << [macro_name, params]
        next
      end

      mod = _strip_quotes(params[0])
      configs[mod] ||= Config.new(module: mod)

      case macro_name
      when 'TEST_PARTIAL_PUBLIC_MODULE'
        _check_type_unset!(configs[mod].tests, mod, macro_name)
        configs[mod].tests.type = PUBLIC
      when 'TEST_PARTIAL_PRIVATE_MODULE'
        _check_type_unset!(configs[mod].tests, mod, macro_name)
        configs[mod].tests.type = PRIVATE
      when 'MOCK_PARTIAL_PUBLIC_MODULE'
        _check_type_unset!(configs[mod].mocks, mod, macro_name)
        configs[mod].mocks.type = PUBLIC
      when 'MOCK_PARTIAL_PRIVATE_MODULE'
        _check_type_unset!(configs[mod].mocks, mod, macro_name)
        configs[mod].mocks.type = PRIVATE
      when 'TEST_PARTIAL_MODULE'
        _check_type_unset!(configs[mod].tests, mod, macro_name)
        configs[mod].tests.type = ACCUMULATE
      when 'MOCK_PARTIAL_MODULE'
        _check_type_unset!(configs[mod].mocks, mod, macro_name)
        configs[mod].mocks.type = ACCUMULATE
      end
    end

    # --- Pass 2: CONFIG macros ---
    config_calls.each do |macro_name, params|
      mod = _strip_quotes(params[0])
      unless configs.key?(mod)
        raise CeedlingException.new(
          "#{macro_name} references module '#{mod}' but no corresponding MODULE Partial macro directive for that module was found"
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

      target.subtractions.uniq!
      target.additions.uniq!
    end

    # --- Pass 3: Validation ---
    configs.each do |mod, config|
      if config.tests.type == ACCUMULATE && config.tests.additions.empty?
        raise CeedlingException.new(
          "TEST Partial for module '#{mod}' uses TEST_PARTIAL_MODULE() but no function additions were specified — " \
          "add at least one function name via TEST_PARTIAL_CONFIG()"
        )
      end

      if config.mocks.type == ACCUMULATE && config.mocks.additions.empty?
        raise CeedlingException.new(
          "MOCK Partial for module '#{mod}' uses MOCK_PARTIAL_MODULE() but no function additions were specified — " \
          "add at least one function name via MOCK_PARTIAL_CONFIG()"
        )
      end

      # Rule 1: subtractions are illegal with ACCUMULATE
      [[:tests, 'TEST'], [:mocks, 'MOCK']].each do |field, label|
        pf = config.send(field)
        if pf.type == ACCUMULATE && !pf.subtractions.empty?
          raise CeedlingException.new(
            "#{label} configuration for '#{mod}' Partial cannot contain subtractions because only additions are available with PARTIAL_#{label}_MODULE()"
          )
        end
      end
    end

    return configs
  end

  ### Private ###

  private

  # Raise if partial_functions.type is already set -— indicates duplicate MODULE macro.
  def _check_type_unset!(partial_functions, mod, macro_name)
    return if partial_functions.type.nil?
    raise CeedlingException.new(
      "Partial for module '#{mod}' was declared with '#{macro_name}', but it was already declared and can only be declared once."
    )
  end

  # Strip a matched pair of double-quotes from str.
  # Returns str unchanged if it is not double-quoted.
  def _strip_quotes(str)
    return str unless str.length >= 2 && str.start_with?('"') && str.end_with?('"')
    str[1..-2]
  end

end
