# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Builds C identifiers from names that may hold characters C does not allow, such as a
# filename or a module name. Generated include guards and the type names Partials invent
# share this rule, so one name folds the same way everywhere.
module CIdentifier

  # Each character a C identifier cannot hold becomes an underscore, one for one:
  # my-sensor.v2 --> my_sensor_v2. A test author can predict the result from the name
  # alone, which a macro naming a generated identifier relies on. Callers needing more,
  # such as an include guard's squeezed underscores, build on this.
  def self.fold(text)
    return text.gsub( /\W/, '_' )
  end

end
