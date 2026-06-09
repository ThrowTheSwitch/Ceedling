#!/usr/bin/env bash
# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-25 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

# Extract a version section from a Keep a Changelog formatted file.
#
# Usage: extract_changelog.sh <version> <changelog_path> <output_path>
#
#   <version>        Semver core string (e.g. 1.1.0 or 1.2.3)
#   <changelog_path> Path to the Changelog.md file
#   <output_path>    Path to write the extracted section into
#
# Exits 0 and writes content to <output_path> if the section is found.
# Exits 1 if the changelog file is missing or the version section is absent.
#
# Version section headers are matched by the pattern "^# [VERSION]".
# Any text following the closing "]" on the header line is ignored
# (dates, labels, "Prerelease", em-dashes, hyphens, etc. are all fine).
# The extracted section does NOT include the version header line itself —
# only the body content beneath it is written to <output_path>.
#
# Local testing examples:
#   bash extract_changelog.sh 1.0.1 ../../docs/Changelog.md /tmp/out.md && cat /tmp/out.md
#   bash extract_changelog.sh 9.9.9 ../../docs/Changelog.md /tmp/out.md; echo "exit: $?"

set -euo pipefail

SEMVER="${1:?version argument required}"
CHANGELOG="${2:?changelog path argument required}"
OUTPUT_FILE="${3:?output file path argument required}"

if [ ! -f "$CHANGELOG" ]; then
  echo "Changelog not found at '${CHANGELOG}'; release notes will use GitHub default."
  exit 1
fi

# Extract from the matching "# [VERSION]" header to just before the next "# [" header.
#
# Dots in the version string are escaped in the awk BEGIN block so that e.g.
# 1.1.0 matches literally rather than treating "." as a regex wildcard.
awk -v ver="${SEMVER}" '
  BEGIN { gsub(/\./, "\\.", ver); pat = "^# \\[" ver "\\]" }
  $0 ~ pat          { found=1; next }
  found && /^# \[/  { exit }
  found             { print }
' "$CHANGELOG" > "$OUTPUT_FILE"

# -s: file exists AND is non-empty
# (handles the edge case where the version header is present but has no content beneath it)
if [ -s "$OUTPUT_FILE" ]; then
  echo "Changelog section found for version '${SEMVER}'."
  exit 0
else
  echo "Changelog section not found for version '${SEMVER}'."
  exit 1
fi
