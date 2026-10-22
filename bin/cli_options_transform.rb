# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Transforms Thor command options into the parameters CliHandler/CliHelper
# expect. Kept free of any Thor dependency -- it only ever touches plain
# Hashes -- so this logic is testable without configuring or invoking Thor.
module CliOptionsTransform

  # Every application command hides a --debug convenience flag that forces
  # Verbosity::DEBUG. When --debug isn't set, :verbosity is left exactly as
  # the caller already has it -- an explicit fallback set beforehand, an
  # already-parsed --verbosity flag, or simply absent.
  def self.apply_debug_flag(options)
    options[:verbosity] = Verbosity::DEBUG if options[:debug]
    return options
  end

end
