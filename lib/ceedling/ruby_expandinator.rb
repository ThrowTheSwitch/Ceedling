# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'

# Centralized, security-gated handling of Ceedling's inline Ruby string expansion
# feature (`#{...}` embedded in project configuration values). This executes arbitrary
# Ruby sourced from YAML content, so it is disabled by default and can only be enabled
# via the `--ruby-replacement` command line flag (never from YAML itself).
class RubyExpandinator

  def initialize
    @enabled = false
  end

  # One-directional: once enabled (via the --ruby-replacement CLI flag), nothing should
  # be able to turn this back off mid-process.
  def enable!
    @enabled = true
  end

  def enabled?
    @enabled
  end

  # Pure pattern predicate -- no gating, no evaluation.
  def replacement?(string)
    !!(string =~ PATTERNS::RUBY_STRING_REPLACEMENT)
  end

  # Raises if `string` contains the Ruby-replacement pattern and the feature is not
  # enabled. No-op (and no evaluation) otherwise. `source` is a short descriptive label
  # for what was being processed -- Ceedling's config pipeline merges project.yml,
  # mixins, and plugin config into one in-memory hash well before most call sites run,
  # so there's no literal source-file/line available; the label is the best available
  # context (e.g. "tool 'test_compiler' :executable", ":environment", ":mixins ↳ :load_paths").
  def check!(string, source:)
    return unless replacement?(string)
    return if @enabled

    raise CeedlingException.new(
      "Inline Ruby string expansion is disabled ⏩️ #{source} contains `\#{...}` Ruby code " +
      "but this feature is not enabled. Re-run with `--ruby-replacement` to allow it " +
      "(security-sensitive: only enable this for configuration you trust)."
    )
  end

  # Gated expansion: validates via check! (raises if disabled), then evaluates and
  # returns the result if the pattern is present; returns `string` unchanged otherwise.
  def expand(string, source:)
    return string unless replacement?(string)
    check!(string, source: source)
    Object.module_eval("\"" + string + "\"")
  end

end
