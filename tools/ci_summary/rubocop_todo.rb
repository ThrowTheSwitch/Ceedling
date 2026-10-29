# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# The size of RuboCop's offense backlog, read from the .rubocop_todo.yml that
# `rake lint:todo` generates. RuboCop heads each cop's entry with a comment counting its
# offenses, so the counts come from those comments and the cop names below them.
module CiSummary
  module RubocopTodo

    OFFENSE_COUNT = /^# Offense count: (\d+)$/
    COP           = %r{^[A-Z]\w*/\w+:\s*$}

    module_function

    def counts(text)
      return {
        'offenses' => text.scan( OFFENSE_COUNT ).sum { |(count)| count.to_i },
        'cops'     => text.scan( COP ).size
      }
    end

  end
end
