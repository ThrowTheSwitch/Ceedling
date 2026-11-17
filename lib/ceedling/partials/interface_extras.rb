# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

module Partials
  # What a mock-only Partial's extras header holds of the module's real header beyond the
  # mocked functions. PartializerHelper#plan_interface_extras decides it.
  # GeneratorPartials#generate_extras writes it.
  InterfaceExtras = Struct.new(
    :items,    # The module's items the extras header writes, in the module's order
    :withheld, # Helpers and static variables a header without an include guard keeps back
    keyword_init: true
  ) do
    def initialize(items: [], withheld: [])
      super
    end

    def empty?
      return items.empty?
    end
  end unless const_defined?(:InterfaceExtras, false)
end
