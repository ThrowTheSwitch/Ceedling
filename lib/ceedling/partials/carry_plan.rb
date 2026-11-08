# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'

module Partials
  # A function a Partial carries forward and the reason why, or a name it skips and the kind of skip.
  # The reason feeds debug logging so a user can trace what a Partial contains. The kind picks a notice.
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
    :skipped,    # Array of CarriedItem naming functions left out that kept code uses
    :incomplete, # Set of names of variables declared extern whose type is never completed
    keyword_init: true
  ) do
    def initialize(prototypes: [], helpers: {}, skipped: [], incomplete: Set.new)
      super
    end

    # No definition of a variable whose type is never completed can compile
    def incomplete?(name)
      return incomplete.include?( name )
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

    # The helper's definition ready to write, or nil when the name is not carried
    def helper(name)
      return helpers[name]&.item
    end

    def skip(name, kind)
      return if skipped.any? { |s| s.item == name and s.kind == kind }

      skipped << CarriedItem.new( item: name, kind: kind )
    end
  end unless const_defined?(:CarryPlan, false)
end
