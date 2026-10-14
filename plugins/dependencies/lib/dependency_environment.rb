# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# A dependency's :environment entries, in effect only while its own commands run.
#
# Each entry sets a variable (`NAME=value`), appends to it (`NAME+=value`), or removes
# text from it (`NAME-=value`), in order. Appended and removed text is used exactly as
# written, leading spaces included. Afterward every variable returns to its earlier
# value, and one that was unset is removed again, so one dependency's environment never
# reaches the next dependency or Ceedling itself.
class DependencyEnvironment

  # Text after += or -= is kept exactly, so it can carry its own delimiter (a space
  # between compiler flags). A value after = loses its leading spaces.
  ENTRY = /\A(\w+)\s*(?:(\+=|-=)(.*)|(=)\s*(.*))\z/

  def initialize(entries, dependency:)
    @assignments = entries.map do |entry|
      match = ENTRY.match( entry.to_s ) or
        raise CeedlingException.new( "Environment entry `#{entry}` for dependency `#{dependency}` is not NAME=value, NAME+=value, or NAME-=value." )
      name, operator, text, equals, value = match.captures
      [name, operator || equals, operator ? text : value]
    end
  end

  # Runs the block with the entries applied to `env`, then restores `env`
  def apply(env = ENV)
    saved = @assignments.map( &:first ).uniq.to_h { |name| [name, env[name]] }
    @assignments.each { |name, operator, value| env[name] = assigned( env[name].to_s, operator, value ) }

    return yield
  ensure
    restore( env, saved )
  end

  private

  # Each variable back to its earlier value, or removed when it had none
  def restore(env, saved)
    saved&.each { |name, value| value.nil? ? env.delete( name ) : env[name] = value }
  end

  def assigned(current, operator, value)
    case operator
    when '+=' then current + value
    when '-=' then current.gsub( value, '' )
    else value
    end
  end

end
