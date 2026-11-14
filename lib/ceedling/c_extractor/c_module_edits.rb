# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'

module CExtractorTypes

  # The list of a CModule that holds each kind of item. A statement's list follows its kind.
  ITEM_LISTS = {
    CVariableDeclaration => :variable_declarations,
    CFunctionDefinition  => :function_definitions,
    CFunctionDeclaration => :function_declarations
  }.freeze unless const_defined?(:ITEM_LISTS, false)

  # Edits that keep a CModule's lists and its element_sequence in step. Each item sits in one
  # list and in element_sequence, so an edit to one must reach the other.
  class CModule
    # Removes `items` from their lists and from element_sequence. Items are matched by identity,
    # since two equal statements can sit in different places.
    def remove!(items)
      gone = Set.new.compare_by_identity.merge( items )
      members.each { |list| self[list].reject! { |item| gone.include?( item ) } }
      return self
    end

    # Adds `items` to their lists and places them in element_sequence just ahead of `anchor`, or
    # at the end when `anchor` isn't there
    def insert_before!(anchor, items)
      items.each { |item| self[_list_for( item )] << item }

      at = element_sequence.index { |item| item.equal?( anchor ) } || element_sequence.size
      element_sequence.insert( at, *items )
      return self
    end

    private

    def _list_for(item)
      list = item.is_a?( CStatement ) ? STATEMENT_KINDS.key( item.kind ) : ITEM_LISTS[item.class]
      return list || raise( ArgumentError, "No CModule list holds a #{item.class} of kind #{item.respond_to?( :kind ) ? item.kind.inspect : 'none'}" )
    end
  end

end
