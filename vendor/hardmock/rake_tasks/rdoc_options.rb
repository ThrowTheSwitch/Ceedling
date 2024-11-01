# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================



def add_rdoc_options(options)
  options << '--line-numbers' << '--inline-source' << '--main' << 'README' << '--title' << 'Hardmock'
end
