# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/exceptions'

# Two inputs a build maps to one output, such as two tests to one build name or two sources
# to one object, would leave one of them out of the build, so a build stops on either
module DestinationCollision

  # Each output more than one of `inputs` maps to, with the inputs mapping to it
  def self.find(inputs, &output)
    return inputs.uniq.group_by( &output ).select { |_output, sharing| sharing.size > 1 }
  end

  # Stops the build, naming `inputs` and the `output` they share by `relation`
  def self.raise_for(output, inputs, relation)
    names = inputs.map { |input| "`#{input}`" }.join( ' and ' )
    raise CeedlingException.new( "#{names} #{relation} `#{output}`. Rename one, or move it to its own directory." )
  end

end
