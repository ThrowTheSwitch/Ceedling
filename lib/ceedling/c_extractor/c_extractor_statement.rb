# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The statement record CExtractorTypes holds alongside its other records
module CExtractorTypes

  # Pairs a raw C statement string with its 1-based source line number.
  # Used for macro_definitions, type_definitions, aggregate_definitions and macro_invocations in
  # CModule. `kind` says which, as :macro, :typedef, :aggregate or :invocation.
  CStatement = Struct.new(
    :text,      # String  — raw extracted statement text (comments replaced with spaces)
    :line_num,  # Integer — 1-based line number where the statement begins in the source file
    :origin,    # :header or :source when the caller knows the file's role, otherwise nil
    :kind,      # Symbol  — the statement's category, as listed above
    :tag,       # The struct, union or enum tag a typedef or aggregate names, or nil
    :type_name, # The name a typedef gives its type. A declaration's own type definition has none
                # until Partials names it (see CVariableDeclaration#defined_type).
    keyword_init: true
  ) do
    def initialize(text: nil, line_num: nil, origin: nil, kind: nil, tag: nil, type_name: nil)
      super
    end
  end unless const_defined?(:CStatement, false)

end
