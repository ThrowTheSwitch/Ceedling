# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'erb'

class ErbWrapper

  constructor :file_wrapper

  def generate_file(template, data, output_file)
    @file_wrapper.open(output_file, "w") do |f|
      f << ERB.new(template, trim_mode: "<>").result(binding)
    end
  end
end