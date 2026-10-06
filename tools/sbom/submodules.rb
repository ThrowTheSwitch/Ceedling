# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-26 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Parses `git submodule status --recursive` into paths and commits.
#
# That command is the one that works. `git ls-tree -r HEAD` does not recurse into
# submodules, so it reports the three top-level gitlinks and nothing for the nested
# pair inside CMock, silently dropping two components from every document.
#
# A commit is the authoritative identity for these components. Unity ships twice in a
# Ceedling gem at two different commits, and both report header version 2.7.2, so a
# version string alone cannot tell the two apart.
#
# Each line carries a status character before the commit: a space when the checkout
# matches what the superproject records, `+` when it sits at a different commit, `-`
# when the submodule is not checked out at all, and `U` on merge conflicts. The
# recorded commit is present either way, but nothing can be read out of an
# uninitialized working tree -- including the header versions this tool wants -- so
# callers need to tell the states apart.
module Sbom
  module Submodules

    Entry = Struct.new( :path, :commit, :describe, :status, keyword_init: true ) do
      def initialized?
        status != '-'
      end
    end

    LINE = /\A(?<status>[ +\-U]?)(?<commit>[0-9a-f]{7,40})\s+(?<path>\S+)(?:\s+\((?<describe>[^)]*)\))?\s*\z/

    def self.parse(text)
      text.to_s.lines.filter_map { |line| entry( line.chomp ) }
    end

    # Nil for anything that is not a gitlink line, blank lines included.
    def self.entry(line)
      match = LINE.match( line )
      return nil if match.nil?

      Entry.new(
        path: match[:path],
        commit: match[:commit],
        describe: match[:describe],
        # An in-sync submodule's status column is a space, which the pattern captures as
        # empty when the line has no leading character at all.
        status: match[:status].to_s.strip.empty? ? ' ' : match[:status]
      )
    end
    private_class_method :entry

  end
end
