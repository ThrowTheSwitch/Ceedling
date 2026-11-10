# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Wording the specialists share when a remedy relies on a Ceedling feature.
#
# A remedy that mocks or Partializes a header is worth offering even when the project
# has that feature off, as long as the prescription says which setting turns it on.
module GuidancePhrases
  MOCKS_SETTING    = ':project ↳ :use_mocks'
  PARTIALS_SETTING = ':project ↳ :use_partials'

  # "Mock or Partialize", followed by `rest`, then a sentence naming any setting the
  # remedy needs that the project has off
  def self.substitute(rest, mocks:, partials:)
    return "Mock or Partialize #{rest}#{requirements( mocks: mocks, partials: partials )}"
  end

  # Sentences naming the settings that turn on whichever feature is off, or ''
  def self.requirements(mocks:, partials: true)
    needs  = []
    needs << "Mocking requires #{MOCKS_SETTING}." unless mocks
    needs << "Partializing requires #{PARTIALS_SETTING}." unless partials

    return needs.empty? ? '' : " #{needs.join( ' ' )}"
  end
end
