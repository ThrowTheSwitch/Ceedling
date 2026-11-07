# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module Partials
  # Constants
  PUBLIC     = :public     unless const_defined?(:PUBLIC)
  PRIVATE    = :private    unless const_defined?(:PRIVATE)
  ACCUMULATE = :accumulate unless const_defined?(:ACCUMULATE)
  DEDUCT     = :deduct     unless const_defined?(:DEDUCT)

  TEST_PUBLIC  = :test_public   unless const_defined?(:TEST_PUBLIC)
  TEST_PRIVATE = :test_private  unless const_defined?(:TEST_PRIVATE)
  MOCK_PUBLIC  = :mock_public   unless const_defined?(:MOCK_PUBLIC)
  MOCK_PRIVATE = :mock_private  unless const_defined?(:MOCK_PRIVATE)

  # Data class representing a source or header file to be partialized
  ConfigFileInfo = Struct.new(:filepath, :directives_only_filepath, :full_expansion_filepath, :includes, keyword_init: true) do
    def initialize(filepath: nil, directives_only_filepath: nil, full_expansion_filepath: nil, includes: [])
      super
    end
  end unless const_defined?(:ConfigFileInfo, false)

  # Data class representing a C function signature
  FunctionDeclaration = Struct.new(
    :name,            # Function name (e.g., "foo")
    :return_type,     # Return type (e.g., "int")
    :signature,       # FunctionDefinition signature (e.g., "int foo(void)")
    :source_filepath, # Path to source file
    :line_num,        # Line number in source file
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, source_filepath: nil, line_num: nil)
      super
    end
  end unless const_defined?(:FunctionDeclaration, false)

  # Data class representing a C function with intentionally duplicated fields
  FunctionDefinition = Struct.new(
    :name,            # Function name (e.g., "foo")
    :signature,       # FunctionDefinition signature (e.g., "int foo(void)")
    :code_block,      # Complete function text (signature + body)
    :source_filepath, # Path to source file
    :line_num,        # Line number in source file
    keyword_init: true
  ) do
    # Constructor to set unassigned fields to nil for convenience
    def initialize(name: nil, signature: nil, code_block: nil, source_filepath: nil, line_num: nil)
      super
    end
  end unless const_defined?(:FunctionDefinition, false)

  # A function a Partial carries forward, or skips, and the reason why.
  # The reason feeds debug logging so a user can trace what a Partial contains.
  CarriedItem = Struct.new(
    :item,   # CFunctionDeclaration or Partials::FunctionDefinition, or a bare name when skipped
    :reason, # Short explanation such as "external: no body in module"
    :kind,   # For a skipped name, why it was skipped (:unguarded_helper, :helper_conflict, :prototype_conflict)
    keyword_init: true
  ) unless const_defined?(:CarriedItem, false)

  # Everything a Partial's implementation source holds beyond its selected functions.
  # PartializerHelper#plan_carry decides it. GeneratorPartials#generate_source writes it.
  # Prototypes are matched by object identity. The generator walks element_sequence,
  # which holds the very declarations the plan chose.
  CarryPlan = Struct.new(
    :prototypes, # Array of CarriedItem wrapping a CFunctionDeclaration written word for word
    :helpers,    # Hash of function name => CarriedItem wrapping a Partials::FunctionDefinition
    :skipped,    # Array of CarriedItem naming functions left out that a selected function needs
    keyword_init: true
  ) do
    def initialize(prototypes: [], helpers: {}, skipped: [])
      super
    end

    def add_prototype(decl, reason)
      return if prototype?( decl )

      prototypes << CarriedItem.new( item: decl, reason: reason )
      _identities[decl] = true
    end

    # The generator asks once per declaration, so lookup is by identity in a hash, not a scan
    def prototype?(decl)
      return _identities.key?( decl )
    end

    def _identities
      @identities ||= prototypes.each_with_object( {}.compare_by_identity ) { |carried, index| index[carried.item] = true }
    end

    def add_helper(func, reason)
      helpers[func.name] ||= CarriedItem.new( item: func, reason: reason )
    end

    def helper?(name)
      return helpers.key?( name )
    end

    # The helper's definition ready to write, or nil when the name is not carried
    def helper(name)
      return helpers[name]&.item
    end

    def skip(name, reason, kind)
      return if skipped.any? { |s| s.item == name and s.kind == kind }

      skipped << CarriedItem.new( item: name, reason: reason, kind: kind )
    end

    def empty?
      return prototypes.empty? && helpers.empty? && skipped.empty?
    end
  end unless const_defined?(:CarryPlan, false)

  def self.manufacture_function_declaration(line_num: nil, source_filepath: nil, name:, signature:)
    return FunctionDeclaration.new(
      name: name,
      signature: signature,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end

  def self.manufacture_function_definition(line_num: nil, source_filepath: nil, name:, signature:, code_block:)
    return FunctionDefinition.new(
      name: name,
      signature: signature,
      code_block: code_block,
      source_filepath: source_filepath,
      line_num: line_num
    )
  end
end