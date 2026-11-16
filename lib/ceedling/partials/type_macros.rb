# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'set'

module Partials

  # A type attribute a macro writes after a type's closing brace, as `PACKED` in
  # `struct pk { … } PACKED;`. The written text reads the macro as a variable the type defines,
  # or as the start of its variables' type. The expansion shows the macro belongs to the type,
  # so the type is given it back and keeps its layout. A macro for a storage class or a
  # qualifier stays with its variable.
  module TypeMacros
    # Gives a type back the macro the written text read as its one variable. The expansion holds
    # no variable of that name, and it defines the tag on its own. A type with no tag, or with
    # more than one variable, is left alone, since its expansion can't be matched. Returns a log
    # entry for each type given its macro.
    def self.rejoin_trailing(c_module, expanded_module)
      misread = _misread( c_module, expanded_module )

      misread.each { |var| var.defined_type.text = "#{var.defined_type.text.chomp( ';' )} #{var.text}" }
      c_module.remove!( misread )
      return misread.map { |var| _entry( var.text.chomp( ';' ).strip, var ) }
    end

    # Gives a type back the macro its variable's type starts with, as in
    # `struct pk { … } PACKED inst;`. The twin's type lacks the macro, since its expansion joined
    # the twin's defined type after the closing brace. `ended` holds the types already given
    # their macro, since variables share a type. Returns a log entry when the type takes the
    # macro, or nil.
    def self.rejoin_leading(var, twin, ended)
      macro = _leading_macro( var, twin )
      return nil if macro.nil?

      var.type = var.type.strip.delete_prefix( macro ).strip
      var.text = var.text.delete_prefix( macro ).lstrip
      return nil unless _end_type( var.defined_type, macro, ended )

      return _entry( macro, var )
    end

    # A rejoin's log entry, naming the type by its tag, or else by the variable it defines
    def self._entry(macro, var)
      tag = var.defined_type.tag
      return "`#{macro}` (type attribute of #{tag ? "`#{tag}`" : "the type of `#{var.name}`"})"
    end

    # The written variables that are macros ending their types
    def self._misread(c_module, expanded_module)
      names   = Set.new( expanded_module.variable_declarations.filter_map( &:name ) )
      tags    = _standalone_tags( expanded_module )
      sharing = _variables_by_type( c_module )

      return c_module.variable_declarations.select { |var| _misread?( var, names, tags, sharing ) }
    end

    # Whether a written variable is a macro that ends its type. It must be the type's only variable.
    def self._misread?(var, names, tags, sharing)
      tag = var.defined_type&.tag
      return false if tag.nil? or names.include?( var.name ) or !tags.include?( tag )

      return sharing[var.defined_type] == 1
    end

    # How many variables each type defines, by the type's identity
    def self._variables_by_type(c_module)
      sharing = Hash.new( 0 ).compare_by_identity
      c_module.variable_declarations.each { |var| sharing[var.defined_type] += 1 if var.defined_type }
      return sharing
    end

    # The tags of the types a module defines with a body, apart from any named variable. A
    # forward declaration defines nothing. A declaration with no variable name, as
    # `static struct pk { … } __attribute__((packed));` expands, still defines its type alone.
    def self._standalone_tags(c_module)
      named   = c_module.variable_declarations.select( &:name ).filter_map( &:defined_type )
      defined = Set.new.compare_by_identity.merge( named )
      bodied  = c_module.aggregate_definitions.select { |type| type.text.include?( '{' ) and !defined.include?( type ) }
      return Set.new( bodied.filter_map( &:tag ) )
    end

    # The start of a written variable's type that its twin's type lacks, or nil
    def self._leading_macro(var, twin)
      return nil unless _expanded_into_type?( var, twin )

      written = var.type.to_s.strip
      rest    = twin.type.to_s.strip
      return nil unless written.end_with?( rest )

      macro = written.delete_suffix( rest ).strip
      return macro.empty? ? nil : macro
    end

    # Whether a macro ahead of the variable expanded into its twin's type. Both must define their
    # type, since only then does the macro follow a closing brace. The twin's type must hold more
    # after its brace than the written one. A macro that adds a decorator, such as `static` or
    # `const`, belongs to the variable.
    def self._expanded_into_type?(var, twin)
      return false if var.defined_type.nil? or twin.defined_type.nil?
      return false unless (twin.decorators - var.decorators).empty?

      return _extension( twin.defined_type ).length > _extension( var.defined_type ).length
    end

    # What a type's text holds after its closing brace, less any ending ';'
    def self._extension(type)
      return type.text[/\}([^}]*)\z/, 1].to_s.strip.chomp( ';' ).strip
    end

    # Writes `macro` after a type's closing brace, ahead of any ';' that ends the statement.
    # Once per type, as `ended` records. Returns whether it wrote.
    def self._end_type(type, macro, ended)
      return false if ended.include?( type )

      ended << type
      text      = type.text.rstrip
      type.text = text.end_with?( ';' ) ? "#{text.chomp( ';' ).rstrip} #{macro};" : "#{text} #{macro}"
      return true
    end
  end

end
