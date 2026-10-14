# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'
require 'ceedling/exceptions'
require 'strscan'

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
  #
  # Only each #{...} segment is evaluated as Ruby. Text around the segments is kept as
  # written, so backslashes in Windows paths and stray quotes or `#` characters in a
  # value are never read as Ruby source. An escaped `\#{` is kept as a literal `#{`.
  def expand(string, source:)
    return string unless replacement?(string)
    check!(string, source: source)

    scanner, expanded = StringScanner.new( string ), +''

    until scanner.eos?
      expanded << scanner.scan_until( /(?=\\?#\{)|\z/ )
      next expanded << '#{' if scanner.skip( /\\#\{/ )
      break unless scanner.skip( /#\{/ )

      expanded << Object.module_eval( segment_expression( scanner, source ) ).to_s
    end

    return expanded
  end

  ### Private ###

  private

  # Consumes one segment's Ruby through its closing brace and returns the Ruby alone.
  # Braces nest for blocks and hashes. A quoted string is consumed whole, so a brace
  # inside one does not count.
  SEGMENT_TOKEN = /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[{}]|[^"'{}]+/m

  def segment_expression(scanner, source)
    start = scanner.pos
    depth = 1

    until depth.zero?
      token = scanner.scan( SEGMENT_TOKEN )
      raise CeedlingException.new( "Inline Ruby string expansion ⏩️ #{source} has a `\#{` with no closing `}`." ) if token.nil?

      depth += { '{' => 1, '}' => -1 }.fetch( token, 0 )
    end

    return scanner.string.byteslice( start, scanner.pos - start - 1 )
  end

end
