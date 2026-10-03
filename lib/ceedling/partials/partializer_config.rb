# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'stringio'
require 'strscan'
require 'ceedling/partials/partials'
require 'ceedling/exceptions'
require 'ceedling/c_extractor/c_extractor_preprocessing'
require 'ceedling/encodinator'

class PartializerConfig

  include Partials

  constructor :c_extractor_preprocessing

  # Macro names for all partial configuration macros
  #
  # Each macro has a directory-qualified `_AT` counterpart taking a leading directory
  # parameter. Recognition requires an exact name match followed by an open parenthesis,
  # so a name and its own `_AT` extension stay distinct however they are ordered here.
  MACRO_NAMES = [
    'TEST_PARTIAL_PUBLIC_MODULE',
    'TEST_PARTIAL_PRIVATE_MODULE',
    'MOCK_PARTIAL_PUBLIC_MODULE',
    'MOCK_PARTIAL_PRIVATE_MODULE',
    'TEST_PARTIAL_MODULE',
    'MOCK_PARTIAL_MODULE',
    'TEST_PARTIAL_ALL_MODULE',
    'MOCK_PARTIAL_ALL_MODULE',
    'TEST_PARTIAL_CONFIG',
    'MOCK_PARTIAL_CONFIG',
    'TEST_PARTIAL_PUBLIC_MODULE_AT',
    'TEST_PARTIAL_PRIVATE_MODULE_AT',
    'MOCK_PARTIAL_PUBLIC_MODULE_AT',
    'MOCK_PARTIAL_PRIVATE_MODULE_AT',
    'TEST_PARTIAL_MODULE_AT',
    'MOCK_PARTIAL_MODULE_AT',
    'TEST_PARTIAL_ALL_MODULE_AT',
    'MOCK_PARTIAL_ALL_MODULE_AT',
    'TEST_PARTIAL_CONFIG_AT',
    'MOCK_PARTIAL_CONFIG_AT',
  ].freeze unless const_defined?(:MACRO_NAMES, false)

  # Suffix marking a macro that takes a leading directory parameter.
  QUALIFIED_SUFFIX = '_AT' unless const_defined?(:QUALIFIED_SUFFIX, false)

  # Holds function-level extraction config for tests or mocks within a Partial.
  # type         -- :public, :private, or :accumulate (additions-driven); nil if unset
  # additions    -- function names to explicitly include
  # subtractions -- function names to explicitly exclude (illegal with ACCUMULATE)
  PartialFunctions = Struct.new(:type, :additions, :subtractions, keyword_init: true) do
    def initialize(type: nil, additions: [], subtractions: [])
      super
    end

    # Returns true if this PartialFunctions entry has enough configuration to be processed.
    # Used to gate downstream work: a nil type means the feature is disabled; an ACCUMULATE
    # type with no additions has no functions to include; all other cases are meaningful.
    def present?
      # Feature is disabled for this test/mock side of the module
      return false if type.nil?
      # ACCUMULATE starts empty and relies entirely on explicit additions; without any,
      # there is nothing to include, so the config has no effect
      return false if type == ACCUMULATE && additions.empty?
      # PUBLIC, PRIVATE: always have a base set of functions to filter
      # DEDUCT: starts with all functions; zero subtractions is valid ("include everything")
      return true
    end
  end unless const_defined?(:PartialFunctions, false)

  # Top-level Partial configuration for a single C module.
  Config = Struct.new(:module, :tests, :mocks, :header, :source, keyword_init: true) do
    def initialize(module:,
                   tests:  PartializerConfig::PartialFunctions.new,
                   mocks:  PartializerConfig::PartialFunctions.new,
                   header: Partials::ConfigFileInfo.new,
                   source: Partials::ConfigFileInfo.new)
      super
    end
  end unless const_defined?(:Config, false)

  # Extract partial configuration macros from a string.
  # Returns a hash of module_name => Config.
  def extract_configs_from_string(string)
    extract_configs( string.clean_encoding )
  end

  # Extract partial configuration macros from a file.
  # Returns a hash of module_name => Config.
  def extract_configs_from_file(filepath)
    extract_configs( File.read(filepath).clean_encoding )
  end

  # Core three-pass extraction:
  #   Pass 1 — MODULE macros: build Config entries, set types
  #   Pass 2 — CONFIG macros: populate additions/subtractions
  #   Pass 3 — Validation: raise if any Config has no meaningful content
  def extract_configs(content)
    scanner = StringScanner.new(content)
    calls   = @c_extractor_preprocessing.try_extract_macro_calls(scanner, MACRO_NAMES)

    configs      = {}  # module_name => Config
    config_calls = []  # deferred: [macro_name, params] for CONFIG macros

    # --- Pass 1: MODULE macros ---
    calls.each do |call_str|
      macro_name, params = @c_extractor_preprocessing.parse_macro_call(call_str)
      next if macro_name.nil?

      # A directory-qualified macro behaves exactly as its unqualified counterpart
      # once its leading directory parameter is folded into the module key, so
      # dispatch and validation below work from the unqualified name.
      base_macro = _unqualified_name(macro_name)

      if base_macro.end_with?('_CONFIG')
        config_calls << [macro_name, params]
        next
      end

      mod = _module_key(macro_name, params)
      configs[mod] ||= Config.new(module: mod)

      case base_macro
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
      when 'TEST_PARTIAL_ALL_MODULE'
        _check_type_unset!(configs[mod].tests, mod, macro_name)
        configs[mod].tests.type = DEDUCT
      when 'MOCK_PARTIAL_ALL_MODULE'
        _check_type_unset!(configs[mod].mocks, mod, macro_name)
        configs[mod].mocks.type = DEDUCT
      end
    end

    # --- Pass 2: CONFIG macros ---
    config_calls.each do |macro_name, params|
      mod = _module_key(macro_name, params)
      unless configs.key?(mod)
        raise CeedlingException.new(
          "#{macro_name} references module '#{mod}' but no corresponding MODULE Partial macro directive for that module was found"
        )
      end

      target = macro_name.start_with?('TEST_') ? configs[mod].tests : configs[mod].mocks

      _function_params(macro_name, params).each do |raw|
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

      # Rule 2: additions are illegal with DEDUCT
      [[:tests, 'TEST'], [:mocks, 'MOCK']].each do |field, label|
        pf = config.send(field)
        if pf.type == DEDUCT && !pf.additions.empty?
          raise CeedlingException.new(
            "#{label} configuration for '#{mod}' Partial cannot contain additions because only subtractions are available with #{label}_PARTIAL_ALL_MODULE()"
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

  # True for a directory-qualified macro, which carries a leading directory parameter.
  def _qualified?(macro_name)
    macro_name.end_with?( QUALIFIED_SUFFIX )
  end

  def _unqualified_name(macro_name)
    macro_name.delete_suffix( QUALIFIED_SUFFIX )
  end

  # One module identity, however the module was named. A qualified macro's directory
  # and module parameters join here, so a module declared by one macro family pairs
  # with a config macro from either, and two modules sharing a basename stay distinct.
  def _module_key(macro_name, params)
    unless _qualified?( macro_name )
      _validate_module!( params[0], macro_name )
      return params[0]
    end

    dir = params[0].nil? ? nil : params[0].strip

    _validate_qualifier!( dir, macro_name )
    _validate_module!( params[1], macro_name, dir: dir )

    File.join( dir, params[1] )
  end

  # The module argument names one file's stem and nothing more. The preprocessor emits it
  # verbatim into the generated filename, so anything Ceedling cannot reproduce in the
  # filename it actually writes names a file that is never written -- surfacing much later
  # as a missing include for a filename the author never typed.
  def _validate_module!(mod, macro_name, dir: nil)
    if mod.nil? || mod.empty?
      requires = dir.nil? ? 'a module name' : 'a directory and a module name'
      example  = dir.nil? ? 'module' : 'path/to/module, module'

      raise CeedlingException.new(
        "#{macro_name}() requires #{requires}, as in #{macro_name}(#{example})."
      )
    end

    if mod.include?('"')
      raise CeedlingException.new(
        "#{macro_name}() module '#{mod}' must not be quoted. " \
        "Write the module name as bare text, as in #{macro_name}(#{dir.nil? ? '' : dir + ', '}module)."
      )
    end

    return unless mod.match?( %r{[\\/]} )

    raise CeedlingException.new(
      "#{macro_name}() module '#{mod}' must not contain a path. " \
      "A module's directory belongs in its own argument, as in #{_qualified_example( macro_name, mod, dir )}. " \
      "A path in the module argument lands the Partials prefix on the first directory " \
      "instead of the filename, naming a file Ceedling never writes."
    )
  end

  # The call that replaces one carrying a path in its module argument. Whatever directory
  # the author wrote folds into the directory argument, leaving the module's own stem.
  def _qualified_example(macro_name, mod, dir)
    normalized = mod.tr( '\\', '/' )
    qualifier  = File.dirname( normalized )
    qualifier  = dir.nil? ? qualifier : File.join( dir, qualifier )

    return "#{_qualified?( macro_name ) ? macro_name : macro_name + QUALIFIED_SUFFIX}" \
           "(#{qualifier}, #{File.basename( normalized )})"
  end

  # Function names follow every leading parameter the macro declares.
  def _function_params(macro_name, params)
    _qualified?( macro_name ) ? params[2..] : params[1..]
  end

  # The preprocessor emits the directory verbatim into the generated #include, so a
  # spelling Ceedling cannot reproduce as a real relative path names a file that is
  # never written. Both rejections below are that mismatch, caught where the author
  # can act on it rather than as a missing include much later.
  def _validate_qualifier!(dir, macro_name)
    if dir.nil? || dir.empty?
      raise CeedlingException.new(
        "#{macro_name}() requires a directory as its first argument, " \
        "as in #{macro_name}(path/to/module, module)."
      )
    end

    # A Partial is written below its test's own generated directory, while the emitted
    # #include resolves against the including file. A climbing segment makes those two
    # different places.
    if dir.split( %r{[\\/]} ).include?( '..' )
      raise CeedlingException.new(
        "#{macro_name}() directory '#{dir}' must not contain '..'. " \
        "A Partial is generated relative to the project root, so its directory cannot " \
        "climb above it."
      )
    end

    if dir.start_with?('"') || dir.end_with?('"')
      raise CeedlingException.new(
        "#{macro_name}() directory '#{dir}' must not be quoted. " \
        "Write the path as bare text, as in #{macro_name}(path/to/module, module)."
      )
    end

    if dir.start_with?('/', '\\') || dir.match?(/\A[A-Za-z]:[\/\\]/)
      raise CeedlingException.new(
        "#{macro_name}() directory '#{dir}' must be a relative path, not an absolute path. " \
        "A Partial is generated relative to the project root."
      )
    end
  end

end
