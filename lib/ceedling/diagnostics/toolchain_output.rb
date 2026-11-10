# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Reads the file paths a toolchain's output mentions.
#
# Toolchains place a path in many ways: `a.h:12:3` (GCC, Clang), `"a.h",12` (IAR),
# `"a.h", line 12` (Arm armcc, TI, Green Hills), `a.h(12)` (MSVC), and inside prose such
# as `declared at line 5 of "a.h"`. Rather than parse each format, a path is any token
# that ends in a wanted extension. A double-quoted path may hold spaces. An unquoted one
# ends at whitespace or punctuation no path holds, apart from a Windows drive letter's
# colon. Reading too much is safe here: a caller compares each path against files it
# knows, so a stray match finds nothing.
module ToolchainOutput
  HEADER_EXTENSIONS = %w[h hh hpp hxx].freeze

  # Characters that end an unquoted path
  PATH_STOP = %q{\s"'`(),:;<>\[\]}

  # Headers the output names, each once, in order of first mention
  def self.headers(output)
    return paths( output, "(?:#{HEADER_EXTENSIONS.join( '|' )})" )
  end

  # Object files the output names, each once, in order of first mention
  def self.objects(output, extension:)
    return paths( output, Regexp.escape( extension.delete_prefix( '.' ) ) )
  end

  def self.paths(output, extension)
    return [] if output.nil?

    ending  = "\\.#{extension}(?![\\w.])"
    pattern = /"([^"\n]+?#{ending})"|((?:[A-Za-z]:)?[^#{PATH_STOP}]+?#{ending})/i

    return output.scan( pattern ).map { |quoted, bare| quoted || bare }.uniq
  end
  private_class_method :paths
end
