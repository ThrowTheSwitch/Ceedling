# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Builds human-readable explanations of *why* a hash comparison failed --
# the content half for `DependencyTracker#diagnose`. Pure: works entirely on
# strings and Hashes handed to it, no filesystem access of its own.
#
# `diff-lcs` is a soft dependency, declared in the Gemfile for development
# but deliberately not in ceedling.gemspec (see the Gemfile comment) -- so
# it is not a hard requirement for an installed release gem. When it is not
# available, content diffing degrades to a plain before/after dump rather
# than raising or silently producing nothing.
class DependencyDiffer

  begin
    require 'diff/lcs'
    DIFF_LCS_AVAILABLE = true
  rescue LoadError
    DIFF_LCS_AVAILABLE = false
  end

  # First N bytes sniffed for a null byte to decide whether content is text
  # or binary -- a line-oriented diff on binary content is not "readable."
  BINARY_SNIFF_BYTES = 8_000

  # Explains why a piece of content changed, given `old_snapshot` (the Hash
  # loaded from a previously-written DependencyDebugTree snapshot, or nil if
  # none exists) and `new_content` (the live content read from disk right
  # now, or nil if the file no longer exists). Returns a Hash with one of:
  # - `{ 'reason' => ... }` when no diff can be produced (no snapshot ever
  #   captured, snapshot was truncated, snapshot didn't include content
  #   because the debug tier at capture time was only :meta, or the file is
  #   now missing).
  # - `{ 'summary' => ... }` for binary content -- byte sizes, not a diff.
  # - `{ 'diff' => ... }` for text content -- a readable line-level diff.
  def diff_content(old_snapshot, new_content)
    return { 'reason' => 'no prior snapshot was captured for this path (enable CEEDLING_DEP_DEBUG=full and rebuild once to establish a baseline)' } if old_snapshot.nil?
    return { 'reason' => "prior snapshot's content was truncated (file exceeded the capture size cap; see 'size' in its snapshot.yml)" } if old_snapshot['truncated']
    return { 'reason' => "prior snapshot did not include content (captured at debug tier :meta, not :full)" } if old_snapshot['content'].nil?
    return { 'reason' => 'file no longer exists' } if new_content.nil?

    old_content = old_snapshot['content']

    if binary?( old_content ) || binary?( new_content )
      return { 'summary' => "binary content differs (previously #{old_content.bytesize} bytes, now #{new_content.bytesize} bytes)" }
    end

    { 'diff' => text_diff( old_content, new_content ) }
  end

  # Explains why canonicalized meta changed, given `old_meta` (Hash loaded
  # from a snapshot, or nil) and `new_meta` (the live, currently-registered,
  # canonicalized meta). Returns added/removed/changed_keys breakdowns, or a
  # `'reason'` Hash if no prior meta snapshot exists to compare against.
  #
  # Note the result key is `changed_keys`, not `changed` -- callers (see
  # DependencyTracker#diagnose_meta) wrap this in their own `'changed'`
  # boolean flag, and a flat merge of the two would otherwise silently
  # clobber that boolean with this Hash.
  def diff_meta(old_meta, new_meta)
    return { 'reason' => 'no prior meta snapshot was captured for this target (enable CEEDLING_DEP_DEBUG=meta or :full and rebuild once to establish a baseline)' } if old_meta.nil?

    old_meta ||= {}
    new_meta ||= {}

    added   = new_meta.keys - old_meta.keys
    removed = old_meta.keys - new_meta.keys
    changed = (old_meta.keys & new_meta.keys).select { |key| old_meta[key] != new_meta[key] }

    {
      'added'        => added.each_with_object( {} )   { |key, h| h[key] = new_meta[key] },
      'removed'      => removed.each_with_object( {} ) { |key, h| h[key] = old_meta[key] },
      'changed_keys' => changed.each_with_object( {} ) { |key, h| h[key] = { 'old' => old_meta[key], 'new' => new_meta[key] } }
    }
  end

  ### Private ###
  private

  def binary?(content)
    return false if content.nil?
    content.byteslice( 0, BINARY_SNIFF_BYTES ).include?( "\0" )
  end

  def text_diff(old_content, new_content)
    old_lines = old_content.lines
    new_lines = new_content.lines

    return diff_lcs_text( old_lines, new_lines ) if DIFF_LCS_AVAILABLE
    fallback_text( old_lines, new_lines )
  end

  # Readable, line-numbered diff via diff-lcs. Not a byte-for-byte unified
  # diff -- a terser, more directly readable "what actually changed" list,
  # which is what this is for (troubleshooting, not patch generation).
  def diff_lcs_text(old_lines, new_lines)
    lines = []

    Diff::LCS.sdiff( old_lines, new_lines ).each do |change|
      case change.action
      when '-'
        lines << "- [#{change.old_position + 1}] #{change.old_element.chomp}"
      when '+'
        lines << "+ [#{change.new_position + 1}] #{change.new_element.chomp}"
      when '!'
        lines << "- [#{change.old_position + 1}] #{change.old_element.chomp}"
        lines << "+ [#{change.new_position + 1}] #{change.new_element.chomp}"
      end
      # '=' (unchanged) lines are omitted -- only what actually changed matters here.
    end

    lines.empty? ? '(content hash differs, but no line-level difference found -- likely a line-ending or encoding change)' : lines.join( "\n" )
  end

  def fallback_text(old_lines, new_lines)
    "diff-lcs is not installed -- showing full before/after content instead of a line diff\n" \
    "--- before ---\n#{old_lines.join}\n" \
    "--- after ---\n#{new_lines.join}"
  end

end
